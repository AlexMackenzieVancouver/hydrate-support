# PROJECT.md — Earshot

Read this before any Earshot session. Strategic truth lives here; the detail
lives in `/canon`.

## What it is

An iOS + Apple Watch meeting notepad. You take your own notes; when the
conversation ends, on-device AI fills in what you missed and pushes the
commitments somewhere you'll actually see them.

## Why it exists

Granola proved people want a notetaker that doesn't join the call. Then it
raised $125M, pivoted to enterprise, and started metering its users' own
history at 30 days. Meanwhile Apple shipped free on-device transcription
(`SpeechAnalyzer`) and a free on-device LLM (Foundation Models), and the
open-source world shipped free on-device diarization (FluidAudio). The cost
structure that justified the metering is gone. That is the entire opening.

Full evidence, with sources: `canon/P1-research/EVIDENCE.md`.

## Invariants — a session that breaks one of these has failed

1. **The user's own words are never overwritten.** `Note.notes` is written by
   direct user editing and nothing else, ever. This is the thing Granola's
   users actually love (E-6); everything else is negotiable, this isn't.
2. **Free means free.** The capabilities in PRD §8 marked free never move to
   Pro. Not in v2, not in a "restructuring." Enforced in CI.
3. **Nothing leaves the device without an itemised, previewed, per-target user
   action** — and a receipt written in the same transaction.
4. **No silent degradation.** If a note wasn't produced by the on-device model,
   the app says so, in plain words, unprompted.
5. **The phone owns every Note. The Watch owns nothing but in-flight audio.**
   No exceptions, no "just this once" write path from the wrist.
6. **A wrong speaker name is worse than no name.** When confidence is below
   threshold, ask; never guess.
7. **Nothing steals focus mid-capture.** No modal, no toast, no permission
   prompt after recording starts.

## The three things that differentiate it

- **Named speakers** — the thing Granola can't do (E-2).
- **Deliveries** — the thing the whole category admits it can't do (E-7).
- **Unlimited free history** — the thing users are loudest about losing (E-1).

## Where things are

```
canon/P1-research/EVIDENCE.md        every sourced claim, numbered E-n
canon/P2-product/STRATEGY_BRIEF.md   positioning, bets, pricing, metrics
canon/P2-product/PRD.md              requirements, numbered F-n
canon/P3-design/DESIGN_SYSTEM.md     tokens, screens, copy
canon/P4-technical/RFC.md            architecture, quality ladder, deps
canon/P4-technical/WATCH_ARCHITECTURE.md
canon/P5-implementation/BACKLOG.md   what's done, what's next
canon/P7-launch/APP_STORE.md         listing, privacy label, rejection risks
app/                                 the code
```

## Repo note

This repo also serves **Hydrate's** live App Store support and privacy URLs
from its root (`support.html`, `privacy.html`, `terms.html`, `index.html`).
Those are load-bearing for a shipped app. Do not move, rename, or delete them.
Earshot's own pages live under `/earshot/`.
