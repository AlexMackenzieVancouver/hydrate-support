# P4 — Technical RFC: Earshot v1.0

Status: APPROVED · Upstream: `P2-product/PRD.md`

## 1. Targets

- iOS 26.0+ / watchOS 26.0+. iPhone 15 Pro or later for on-device summarisation
  (Apple Intelligence requirement); **graceful, honest degradation below that**
  (§6), not a hard gate — transcription works on any iOS 26 device.
- Swift 6, strict concurrency. SwiftUI. SwiftData.
- One shared package, `EarshotKit`, consumed by both app targets.

## 2. Module map

```
EarshotKit/
  Models/        SwiftData entities + value types. No I/O, no frameworks beyond SwiftData.
  Capture/       AudioRecorder, ChunkWriter, CaptureSession, Moment
  Intelligence/  TranscriptionEngine, Diarizer, Summarizer, Recipe, quality ladder
  Delivery/      DeliveryTarget protocol + Reminders/Markdown/Calendar/Mail/Webhook
  Sync/          WatchLink (WCSession), CaptureInbox, PendingCapture
  Support/       DesignTokens, PrivacyLedger, Entitlements, Log
```

Dependency direction is strictly downward: `Models` ← `Capture`/`Intelligence`/
`Delivery`/`Sync` ← app targets. Nothing in `Models` imports anything else.

## 3. Intelligence: three protocols, several implementations

Everything AI-shaped sits behind a protocol so the quality ladder (F-14) is a
composition decision, not an `if` scattered through views.

```swift
protocol TranscriptionEngine  { func transcribe(_:) -> AsyncThrowingStream<TranscriptSegment, Error> }
protocol Diarizer            { func diarize(_:) async throws -> [SpeakerTurn] }
protocol Summarizer          { func summarize(_:using:) async throws -> MeetingDigest }
```

| Protocol | Primary | Fallback | Cost |
|---|---|---|---|
| `TranscriptionEngine` | `SpeechAnalyzerEngine` — `SpeechAnalyzer` + `SpeechTranscriber`, iOS 26 (E-8) | `FluidAudioEngine` (Parakeet TDT v3 on ANE, MIT) | £0 |
| `Diarizer` | `FluidAudioDiarizer` — pyannote CoreML on ANE (E-10) | `HeuristicDiarizer` — pause/energy segmentation, labels only | £0 |
| `Summarizer` | `FoundationModelsSummarizer` — on-device LLM, `@Generable` guided output (E-9) | `TemplateSummarizer` — deterministic extraction, no LLM | £0 |
| — | `RemoteSummarizer` — BYO key, explicit opt-in per note | — | user's |

**Guided generation is mandatory** for the summarizer. `MeetingDigest` is
`@Generable`; we never parse prose into structure. This is what makes a 3B
on-device model viable for F-12.

**Chunking.** Transcripts exceeding the model's context are summarised
map-reduce: N-minute windows → per-window digests → a reduce pass over the
digests. Moments (F-4) are forced into every window that contains them and are
never dropped in the reduce.

**Voice prints (F-8).** A speaker embedding (256-float vector from the
diarizer) is stored on the `Speaker` entity. Matching is cosine similarity with
a conservative threshold (0.82) — we would rather ask than mislabel, because
E-2 says a wrong name is worse than no name. Embeddings are excluded from all
export and sync payloads.

## 4. Data model

```
Note ─┬─ notes: String                (user's own, never AI-written — F-11)
      ├─ enhanced: EnhancedNote?      (AI layer, strippable — F-11)
      ├─ digest: MeetingDigest?       (summary/decisions/questions — F-12)
      ├─ segments: [TranscriptSegment]
      ├─ moments: [Moment]            (F-4)
      ├─ actionItems: [ActionItem]    (F-12, F-19)
      ├─ shelf: Shelf?                (F-20)
      ├─ recipe: Recipe               (F-13)
      ├─ audioURL: URL?               (local, user-deletable, never uploaded)
      └─ receipts: [DeliveryReceipt]  (F-18, F-27)

Speaker ─ name, voicePrint: [Float]?, source: .manual/.matched/.calendarHint (F-9)
```

`ActionItem.externalID` holds the `EKReminder` calendar-item identifier so
completion round-trips (F-19). Sync back is via `EKEventStore` change
notification, not polling.

## 5. Concurrency

- `NoteRepository` is a `@MainActor` class owning the `ModelContext`. Single
  writer, per the skill's state-ownership gate.
- `TranscriptionEngine` implementations are `actor`s; they emit to an
  `AsyncThrowingStream` that the view consumes inside a `.task {}` bound to
  view lifetime (cancellation handled by construction).
- Audio callbacks are real-time-priority: they append to a lock-free ring buffer
  and do nothing else. No allocation, no logging, no `await` in the tap.
- `WatchLink` is an `actor` wrapping `WCSession`; delegate callbacks hop onto it.

## 6. The honest quality ladder (F-14)

Resolved once at launch and cached, re-checked on `SystemLanguageModel`
availability change:

```
1. Apple Intelligence available          → FoundationModelsSummarizer
2. Device capable, model downloading     → queue; show "notes ready when the model finishes"
3. Device not capable                    → TemplateSummarizer + one-time honest explainer
4. Transcript > context, any tier        → map-reduce chunking (§3)
5. User opted into BYO key for this note → RemoteSummarizer, with an upload confirmation
                                           sheet listing exactly what is sent (F-17, F-24)
```

Rule: the UI **states the tier in effect** on any note not produced by tier 1.
Silent degradation is a defect, not a compromise.

## 7. Privacy implementation (F-24 → F-28)

- No networking code in the free path at all. `RemoteSummarizer` and
  `WebhookDelivery` are the *only* two types in the codebase permitted to import
  `URLSession`; enforced by a CI grep in `pre_commit_guard`.
- `PrivacyLedger` is append-only, written inside the same transaction as any
  outbound call. A network call without a ledger entry is a unit-test failure.
- Audio files live in `Application Support`, excluded from iCloud backup unless
  the user enables sync, and are `.completeFileProtection`.
- No analytics SDK. First-party, on-device counters only; an aggregate opt-in
  report can be *sent by the user*, never collected by us.

## 8. Testing

- `TemplateSummarizer` is deterministic → golden-file tests over a corpus of
  20 hand-annotated transcripts (2/3/6-speaker, cross-talk, accents, 5–90 min).
- Diarization accuracy measured as DER against that corpus; regression gate at
  the current value, no silent drift.
- `WatchLink` tested against a fake `WCSession` covering every failure in
  `WATCH_ARCHITECTURE.md` §7.
- Snapshot tests at AX5 Dynamic Type for every screen (§ PRD 10).

## 9. Third-party dependencies (canon-authorized, exhaustive)

| Package | License | Why | Removable? |
|---|---|---|---|
| `FluidAudio` | MIT/Apache-2.0 | Diarization + fallback ASR on ANE (E-10) | Yes — `HeuristicDiarizer` fallback exists |

Nothing else. No analytics SDK, no crash SDK beyond MetricKit, no networking
library, no RevenueCat in v1 (StoreKit 2 directly — two products, no server
receipts; revisit if the catalogue grows).

> Note: this deviates from the ios-app-os default of RevenueCat. Justification:
> two non-consumable/auto-renewable products, no cross-platform entitlement to
> reconcile (iOS-only in v1 per PRD §9), and a hard privacy requirement (§7)
> that a third-party SDK complicates. Revisit at Mac/Android.
