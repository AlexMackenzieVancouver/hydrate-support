# Earshot

An iOS + Apple Watch meeting notepad. You take your own notes; when the
conversation ends, on-device AI fills in what you missed and pushes the
commitments somewhere you'll actually see them.

**Nothing leaves the device.** Transcription runs on Apple's `SpeechAnalyzer`,
summarisation on the Foundation Models on-device LLM, speaker diarization on
CoreML via FluidAudio. All free, all local — which is why the free tier can be
unlimited rather than a countdown.

---

## ⚠️ This repo also serves Hydrate's live App Store URLs

`index.html`, `support.html`, `privacy.html`, and `terms.html` **at the repo
root** are Hydrate's support and privacy pages, referenced from a shipped App
Store listing. **Do not move, rename, or delete them.** Earshot's own pages live
under [`earshot/`](earshot/) for exactly this reason.

---

## Why this exists

Granola proved people want a notetaker that doesn't join the call. Then it
raised $125M, pivoted to enterprise, and started metering users' own history at
30 days. Every claim behind that sentence is sourced in
[`canon/P1-research/EVIDENCE.md`](canon/P1-research/EVIDENCE.md).

What Earshot does differently, and why:

| Gap | Evidence | Earshot's answer |
|---|---|---|
| Free plan caps history at 30 days | E-1 | Unlimited history, free forever. On-device AI costs nothing per minute, so there is nothing to meter. |
| Transcripts have no speaker labels | E-2 | On-device diarization + voice prints that persist across meetings. Name a voice once. |
| Notes stay stranded in the app | E-3, E-7 | **Deliveries** — accepted action items become real Reminders with due dates, and completing them there closes them here. |
| Share links public by default; training on by default | E-4 | Local by default, nothing outbound without an itemised preview, a Privacy Ledger showing everything that ever left, and no training, ever, with no toggle. |
| Enterprise pivot lost individuals | E-5 | Individual-first. $6/mo, not $14/seat. |

## Layout

```
canon/          product truth — evidence, PRD, design system, RFC, launch pack
brain/          session context: PROJECT.md, STATUS.md, NEXT_SESSION.md
app/            the Swift source
  EarshotKit/     shared package (models, intelligence, delivery, sync)
  iOS/Earshot/    iPhone app
  Watch/          watchOS app
  project.yml     XcodeGen spec
earshot/        Earshot's App Store support / privacy / terms pages
*.html          ← Hydrate's live pages. Leave alone.
```

## Status

Canon is complete. **The Swift source has never been compiled** — it was
authored in a Linux container with no Swift toolchain. Treat it as
reviewed-but-unverified.

To build:

```bash
brew install xcodegen
cd app && xcodegen generate && open Earshot.xcodeproj
```

Start with [`brain/NEXT_SESSION.md`](brain/NEXT_SESSION.md) — it lists what is
most likely to break, in order.

## Working on this

Read [`brain/PROJECT.md`](brain/PROJECT.md) first. It contains seven invariants;
a change that breaks one of them is a regression regardless of what else it
does. The shortest version:

1. The user's own words are never overwritten by AI.
2. Free capabilities never move behind the paywall.
3. Nothing leaves the device without an itemised, previewed action and a receipt.
4. No silent degradation — if the on-device model didn't write it, the app says so.
5. The phone owns every note; the Watch owns only in-flight audio.
6. A wrong speaker name is worse than no name.
7. Nothing steals focus mid-capture.
