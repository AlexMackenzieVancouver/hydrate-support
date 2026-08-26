# P4 — Watch Architecture

Status: APPROVED · Upstream: `P2-product/PRD.md`

## 1. Thesis

Granola's Watch app is a **remote shutter**: tap to record, audio ships to the
phone, phone thinks (E-0). Ours ships the shutter *and* the two things a wrist
is uniquely good at — **marking a moment** and **closing the loop on an action
item** — because those are the only two interactions in this product that are
worse on a phone.

| Capability | Granola Watch (Jul 2026) | Earshot Watch v1 |
|---|---|---|
| One-tap record from app | ✅ | ✅ |
| Complication launch | ✅ | ✅ + Control Center control + Action Button |
| Offline record, sync later | ✅ | ✅ |
| Haptic meeting reminders | ✅ | ✅ |
| **Moments (mark a moment mid-conversation)** | ✅ visual + sound confirm | ✅ **haptic-only, screen stays dark** |
| **Live "still recording" reassurance** | screen turns green | persistent Live Activity + wrist-raise elapsed time |
| **Action items confirmed on the wrist** | ❌ | ✅ swipe to accept/dismiss post-meeting |
| **Standalone (no phone in range) capture** | ✅ | ✅ + on-watch VAD trim before transfer |

## 2. State ownership — the non-negotiable

**The phone owns every note. The Watch owns nothing but in-flight audio.**

There is exactly one writer for `Note`: the iPhone's `NoteRepository`. The Watch
holds a `PendingCapture` (audio chunks + Moment timestamps + a UUID) and its
only mutation verbs are *append* and *hand off*. It never authors a `Note`, never
edits one, never deletes one. This eliminates the entire class of
watch/phone divergence bugs by construction.

```
Watch                                   iPhone
─────                                   ──────
PendingCapture(id, chunks[], moments[])
   │  WCSession.transferFile (per chunk, background-safe)
   ├──────────────────────────────────────▶ CaptureInbox
   │  transferUserInfo (moments, metadata)
   ├──────────────────────────────────────▶ CaptureInbox
   │                                          │
   │                                          ├─▶ NoteRepository.create(from:)
   │                                          ├─▶ TranscriptionEngine
   │                                          └─▶ Summarizer
   │  applicationContext (status: processed)
   ◀──────────────────────────────────────────┘
   └─ delete local chunks only after ack
```

**Deletion rule:** the Watch deletes a chunk only after the phone acknowledges
that specific chunk ID. An un-acked chunk survives reboot and retries. Storage
pressure never wins against an un-acked chunk; instead the Watch stops recording
and tells the user.

## 3. Recording on-wrist

- `AVAudioSession` category `.record`, mode `.default`, with
  `.allowBluetooth` so AirPods are used when present.
- 16 kHz mono, AAC-in-M4A. ~1 MB per 8 minutes — a 60-minute standalone capture
  is ~8 MB, comfortably transferable.
- Chunked at 60 s. Each chunk is finalised and queued independently (F-6).
- `WKExtendedRuntimeSession` (`.mindfulness` is *not* appropriate; use a
  background audio-recording session) keeps capture alive with the wrist down.
- On-watch `SpeechDetector`-style VAD is **not** run in v1 (battery). Silence
  trimming happens on the phone.

**Battery budget:** ≤ 12% of an Apple Watch Series 10 battery per 60-minute
standalone capture. Measured, not estimated, in `QA_STRATEGY.md`. If a build
exceeds it, the build does not ship.

## 4. Moments on the wrist (F-4)

The interaction that justifies the Watch existing. In a walking 1:1 you cannot
look at a screen — but you can press your wrist.

- Double-tap gesture (Series 9+) or the Action Button, screen never lights.
- Confirmation is a single `.success` haptic. **No sound, no screen.** Granola's
  green screen + sound is exactly wrong for a conversation you're in.
- Each Moment is `(uuid, offsetSeconds, source: .watch)`, transferred with
  metadata, and becomes a hard anchor the summary must address.

## 5. Post-meeting on the wrist

When the phone finishes processing, it pushes a compact
`WatchReviewPayload` (action items only, ≤ 8, text truncated to 60 chars) via
`updateApplicationContext`. The user swipes accept/dismiss per item; decisions
flow back as `transferUserInfo` and are applied by the phone. If the phone
never receives them, nothing is lost — the items simply remain unreviewed. The
Watch is never the system of record.

## 6. Complications / widgets

- `accessoryCircular`, `accessoryCorner`, `accessoryInline` — show "Tap to
  capture" or, if a calendar meeting starts within 10 minutes, its title.
- Control Center control (`ControlWidget`) for one-press capture.
- Timeline refreshes on calendar change notification, not on a poll.

## 7. Failure modes and their required behaviour

| Failure | Required behaviour |
|---|---|
| Phone out of range mid-capture | Keep recording. Never surface an error mid-conversation. Queue on wrist. |
| Watch storage < 50 MB | Refuse to *start* a new capture with a clear message. Never truncate a running one. |
| Transfer fails repeatedly | Exponential backoff, indefinite retry, visible "1 capture waiting to sync" state on both devices. |
| User deletes the note on phone before sync | Phone acks-and-discards, watch cleans up. No zombie. |
| App killed mid-capture | Chunks on disk; recovery offered on next launch (F-6). |

## 8. What the Watch must never do

- Never run transcription or summarisation (battery, thermals, quality).
- Never hold the only copy of anything the user has been told is saved.
- Never show a state the phone would contradict.
- Never record without the persistent recording indicator visible on wrist-raise.
