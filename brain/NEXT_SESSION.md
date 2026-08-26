# NEXT_SESSION.md

This file is the context budget. It should be enough to restart cold.

## Where we are

Canon is complete and approved (P1–P5, P7). The app is written but **has never
been compiled** — it was authored in a Linux container with no Swift toolchain.
Treat every Swift file as reviewed-but-unverified.

## The one objective for the next session

**IMPL-10 · First build.**

```bash
brew install xcodegen
cd app && xcodegen generate && open Earshot.xcodeproj
```

Allowed to touch: anything under `app/`. Not allowed to touch: `canon/`,
`brain/`, or the four Hydrate `.html` files at the repo root.

## What will most likely break, in order

1. **`TranscriptionEngine.swift`** — the `SpeechAnalyzer` / `SpeechTranscriber`
   call sites (`AnalyzerInput`, `.progressiveTranscription`, `result.range`,
   `AssetInventory`). Written to the documented shape; verify against the
   shipping SDK and adjust. The *protocol* is the contract, not these calls.
2. **`Summarizer.swift`** — `@Generable` / `@Guide` macro surface and
   `session.respond(to:generating:)`. Same caveat.
3. **`Tokens.Palette`** references named colour assets that don't exist yet
   (IMPL-11). Either add the asset catalogue or temporarily inline the hex
   values from `DESIGN_SYSTEM.md §2` — but do not leave hex literals in the
   final code.
4. **SwiftData `#Predicate` on `captureState.rawValue`** in
   `NoteRepository.interruptedNotes()` — enum-through-predicate is fussy; a
   stored `String` shadow property may be needed.
5. **Swift 6 strict concurrency** across the `WatchLink` delegate hops.

## Acceptance criteria

Both targets build clean under Swift 6 strict concurrency, app launches, and a
capture can be started and stopped. Notes generating correctly is IMPL-12/13,
not this session.

## Do not, while you're in there

- Do not "improve" `Note.notes` handling. Invariant 1 in `PROJECT.md`.
- Do not add a dependency. `FluidAudio` is the only authorized one (RFC §9).
- Do not add `URLSession` anywhere. Two types may import it, neither exists yet.
- Do not fix unrelated things you notice. Open a backlog item.

## Open risks carried forward

- **Unmeasured:** on-device summary quality on messy 45-minute multi-speaker
  audio. This is the single biggest product risk (STRATEGY_BRIEF, last line).
  IMPL-13's corpus is how we find out. If quality is bad, the answer is the
  honest ladder — not silently shipping cloud inference.
- **Unmeasured:** Watch battery per 60-minute standalone capture. Budget 12%.
- **Unverified:** that `SpeechTranscriber` handles 6-speaker cross-talk well
  enough that diarization has something to attach to.
