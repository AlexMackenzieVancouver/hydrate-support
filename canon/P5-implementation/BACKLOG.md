# P5 — Implementation Backlog

Status: ACTIVE · Upstream: `P4-technical/RFC.md`

One coherent objective per session (ios-app-os principle 8). Each item names
the canon it must satisfy and the files it may touch. **Do not widen scope
mid-session** — open a new item instead.

## Legend

`[x]` landed in this repo · `[~]` scaffolded, needs a Mac to finish ·
`[ ]` not started

---

## Done in the initial session

- [x] **IMPL-00 · Canon.** P1 evidence base, strategy brief, PRD, design system,
      technical RFC, watch architecture.
- [x] **IMPL-01 · Data model.** `Note`, `TranscriptSegment`, `Speaker`,
      `ActionItem`, `Moment`, `Shelf`, `DeliveryReceipt`, `Recipe`,
      `NoteRepository` as sole writer. *(RFC §4, §5)*
- [x] **IMPL-02 · Intelligence protocols + on-device implementations.**
      `SpeechAnalyzerEngine`, `FoundationModelsSummarizer` with `@Generable`
      guided output, `ChunkedSummarizer` map-reduce, `TemplateSummarizer`,
      `QualityLadder`. *(RFC §3, §6 / F-12, F-14)*
- [x] **IMPL-03 · Deliveries.** `DeliveryTarget`, `RemindersDelivery` with
      round-trip completion, `MarkdownDelivery`, `DeliveryCoordinator` with the
      first-use-always-previews rule. *(F-16 → F-19)*
- [x] **IMPL-05 · Capture.** `CaptureSession`, `ChunkWriter` with ≤10s durable
      chunks, layered failure degradation. *(F-1 → F-6)*
- [x] **IMPL-06 · Watch link.** `WatchLink` actor, `PendingCapture`, chunk-ack
      protocol, review payload. *(WATCH §2, §5)*
- [x] **IMPL-07 · iOS surface.** Capture, notes list, note detail/review,
      consent sheet, delivery preview. *(DESIGN_SYSTEM §3, §4)*
- [x] **IMPL-08 · Watch surface.** Idle / recording / review, haptic-only
      Moments, extended runtime session. *(WATCH §3, §4 / DESIGN_SYSTEM §5)*
- [x] **IMPL-09 · Monetization.** `Feature` tier table frozen against PRD §8,
      StoreKit 2 entitlements, pricing promise copy.

## Next — needs a Mac with Xcode 26

Nothing below was compiled. The container this was authored in has no Swift
toolchain, so every item here begins with "make it build."

- [ ] **IMPL-10 · First build.** `brew install xcodegen && cd app && xcodegen
      generate`. Resolve API drift against the shipping iOS 26 SDK — the
      `SpeechAnalyzer` and `FoundationModels` call sites in
      `TranscriptionEngine.swift` and `Summarizer.swift` are written to the
      documented shape and are the most likely to need adjusting.
      *Acceptance:* both targets build clean under Swift 6 strict concurrency.
- [ ] **IMPL-11 · Colour assets.** `Tokens.Palette` references named colours
      that need an asset catalogue with light/dark variants per DESIGN_SYSTEM §2.
      *Acceptance:* contrast ratios verified at the values stated in canon.
- [ ] **IMPL-12 · Diarization.** Wire `FluidAudioDiarizer` behind the `Diarizer`
      protocol; implement voice-print enrolment and the ≥0.82 match threshold.
      *Acceptance:* DER measured on the corpus and recorded as the regression
      baseline. *(F-7 → F-10, RFC §8)*
- [ ] **IMPL-13 · Test corpus.** 20 annotated transcripts (2/3/6 speakers,
      cross-talk, accents, 5–90 min) + golden-file tests over
      `TemplateSummarizer`. This is the regression baseline for the whole
      intelligence layer. *(RFC §8)*
- [ ] **IMPL-14 · Watch battery measurement.** 60-minute standalone capture on
      a Series 10. Budget is ≤12%; over budget does not ship. *(WATCH §3)*
- [ ] **IMPL-15 · Watch complications + Control Center control.** *(WATCH §6)*
- [ ] **IMPL-16 · Interrupted-capture recovery.** Reconstruct a note from
      on-disk chunks at launch. *(F-6)*
- [ ] **IMPL-17 · Accessibility pass.** VoiceOver on capture and review,
      AX5 snapshot tests, reduce-motion. Launch-blocking. *(PRD §10)*
- [ ] **IMPL-18 · Privacy Ledger screen.** Model exists; the screen does not.
      *(F-27)*
- [ ] **IMPL-19 · Shelves + Recipe editor UI.** *(F-13, F-20)*

## Pro features — after v1.0 ships free

- [ ] **IMPL-20 · Threads.** On-device embedding + retrieval across the
      archive, answers citing note and timestamp. *(F-21)*
- [ ] **IMPL-21 · Pre-read.** Calendar-triggered brief from prior notes with
      the same attendees. *(F-22)*
- [ ] **IMPL-22 · Encrypted sync.** *(F-24 constraints apply — sync is opt-in,
      never a default.)*
- [ ] **IMPL-23 · Calendar / Mail / Webhook deliveries.** `WebhookDelivery` is
      one of only two types permitted to import `URLSession`; the CI grep in
      `pre_commit_guard` must be updated in the same commit. *(RFC §7)*

## Guard rails for every session

- `monetization-guardian`: `Feature.tier` must match PRD §8 exactly. A free
  capability moving to Pro fails the build.
- `trust-checker`: no new code path may record without the indicator, deliver
  without a receipt, or degrade without disclosure.
- Network grep: only `RemoteSummarizer` and `WebhookDelivery` may import
  `URLSession`.
