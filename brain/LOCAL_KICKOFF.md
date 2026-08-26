# Local kickoff prompt

Paste the block below into Claude Code running locally on a Mac, with this repo
open and the `claude/granola-app-redesign-xsski4` branch checked out.

Prerequisites the local machine needs before starting:

- macOS with **Xcode 26** installed and command-line tools selected
- `brew install xcodegen`
- An Apple Developer account (for the `DEVELOPMENT_TEAM` value and TestFlight)
- Ideally an **iPhone 15 Pro or later** with Apple Intelligence enabled — the
  simulator cannot properly exercise the on-device model path
- An Apple Watch Series 9 or later paired to it, for the watchOS milestones

---

```
You're picking up Earshot — an iOS + Apple Watch meeting notepad where all the
AI runs on-device. The product canon is complete and the Swift source is fully
written, but NOTHING HAS EVER BEEN COMPILED. It was authored in a Linux
container with no Swift toolchain. Treat every Swift file as
reviewed-but-unverified.

Your job is to take it from uncompiled source to submitted on the App Store.

START BY READING, IN THIS ORDER:
  brain/PROJECT.md          — the seven invariants. These outrank everything.
  brain/NEXT_SESSION.md     — what will break first, in order
  brain/STATUS.md           — what exists and what doesn't
  canon/P5-implementation/BACKLOG.md — the ordered work
Read other canon files only when the milestone you're on cites them. Don't load
all of it every session; it's large and most of it isn't relevant to a given task.

Use the ios-app-os skill. Its workflow is what this repo is built around.

HARD RULES — a change that breaks one of these is a regression regardless of
what else it does:
1. Never write to Note.notes from code. The user's own words are input to the
   AI, never material for it. This is the single load-bearing product promise.
2. Never move a capability marked free in PRD §8 behind the paywall.
3. Nothing leaves the device without an itemised preview, an explicit user
   action, and a DeliveryReceipt written in the same transaction.
4. No silent degradation. If the on-device model didn't produce a note, the app
   says so, unprompted, in the words already fixed in DESIGN_SYSTEM.md §6.
5. The phone owns every Note; the Watch owns only in-flight audio. Never add a
   write path from the wrist.
6. Below the confidence threshold, ask who spoke — never guess a name.
7. Nothing steals focus during capture. No modal, toast, or permission prompt
   after recording starts.
8. Do not add a dependency. FluidAudio is the only authorized one (RFC §9).
9. Only RemoteSummarizer and WebhookDelivery may import URLSession. Neither
   exists yet. If you create either, say so loudly.
10. DO NOT TOUCH index.html, support.html, privacy.html, or terms.html at the
    repo root. Those are a different shipped app's live App Store URLs.
    Earshot's pages are under earshot/.

WORK IN MILESTONES. One per session. Each ends with a build that compiles, a
commit, and updates to brain/STATUS.md, brain/SESSION_LOG.md, and
brain/NEXT_SESSION.md. Do not start the next milestone in the same session.

  M1  IMPL-10 — First build. `brew install xcodegen && cd app && xcodegen
      generate`. Fix compile errors only. The SpeechAnalyzer and
      FoundationModels call sites are written to the documented API shape and
      are the most likely to need adjusting against the shipping SDK — the
      protocols are the contract, not those specific calls. Also expect
      trouble with the SwiftData #Predicate over captureState.rawValue.
      DONE WHEN: both targets build clean under Swift 6 strict concurrency and
      the app launches.

  M2  IMPL-11 — Asset catalogue for the colour tokens, light and dark, at the
      exact values in DESIGN_SYSTEM.md §2. Verify the stated contrast ratios.
      DONE WHEN: no hex literals anywhere outside the catalogue.

  M3  First real capture. Record 60 seconds, stop, get a note out of it end to
      end, in Airplane Mode. Fix whatever breaks in the pipeline.
      DONE WHEN: it works offline on a physical device with Apple Intelligence.

  M4  IMPL-13 — Test corpus. 20 annotated transcripts (2/3/6 speakers,
      cross-talk, accents, 5–90 minutes) plus golden-file tests over
      TemplateSummarizer. This is the regression baseline for everything else,
      so do it before diarization, not after.

  M5  IMPL-12 — Diarization via FluidAudio behind the Diarizer protocol. Voice
      print enrolment, 0.82 match threshold, retroactive rename.
      DONE WHEN: DER measured on the corpus and recorded in STATUS.md as the
      baseline future changes are gated against.

  M6  IMPL-16 — Interrupted-capture recovery from on-disk chunks at launch.

  M7  Watch: IMPL-14 (battery — 60-minute standalone capture must cost ≤12% on
      a Series 10; over budget does not ship) and IMPL-15 (complications and
      the Control Center control).

  M8  IMPL-17 — Accessibility. VoiceOver on capture and review, AX5 Dynamic
      Type snapshots with no truncation, reduce-motion. This is
      launch-blocking, not polish.

  M9  IMPL-18 — Privacy Ledger screen. The model exists; the screen doesn't.

  M10 StoreKit. Configure the two products, test purchase and restore in the
      sandbox, verify Feature.tier still matches PRD §8 exactly.

  M11 Submission. Work canon/P7-launch/APP_STORE.md: privacy manifest,
      screenshots, the pre-submission gate. Every box in §7 must actually pass
      — do not check one you haven't verified. Push a TestFlight build and use
      it yourself for a week before submitting.

AS YOU GO:
- Commit per milestone with a message saying what was verified, not just what
  changed. Push to claude/granola-app-redesign-xsski4.
- If a milestone reveals the canon is wrong, fix the canon file first and say
  so in the commit. Don't let code and canon drift apart silently.
- If you find something broken outside the current milestone, open a backlog
  item. Don't fix it inline.

STOP AND ASK ME rather than deciding alone if:
- On-device summary quality turns out to be poor on messy multi-speaker audio.
  The answer is the honest quality ladder or a BYO-key escalation, never
  silently shipping cloud inference. This is the biggest known product risk.
- Watch battery can't hit the 12% budget.
- Any milestone requires adding a dependency, a network call, or weakening one
  of the ten rules above.

Start with M1. Tell me what you find before you start fixing it.
```
