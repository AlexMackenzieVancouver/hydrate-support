# P3 — Design System & UX

Status: APPROVED · Upstream: `P2-product/PRD.md`

## 1. Design thesis

The app is a **notepad first and a machine second**. Every screen answers "where
do I write?" before it answers anything else. AI output is always visually
subordinate to the user's own words — literally lighter, literally secondary.

Granola's 2026 rebrand went loud and green. We go quiet: paper, ink, and one
accent used sparingly enough that when it appears (recording, unsent delivery)
it means something.

## 2. Tokens

Never hardcode. All values via `DesignTokens` in `EarshotKit/Support`.

### Colour

| Token | Light | Dark | Use |
|---|---|---|---|
| `ink` | `#16181C` | `#F2F1EC` | User's own text. Highest contrast in the app. |
| `graphite` | `#5A5F68` | `#A7ADB6` | AI-authored text — deliberately one step back (F-11) |
| `paper` | `#FBFAF6` | `#141518` | Page background |
| `card` | `#FFFFFF` | `#1D1F24` | Elevated surfaces |
| `rule` | `#E6E3DA` | `#2C2F36` | Hairlines, 0.5pt |
| `accent` | `#B4471F` | `#E0703F` | Recording, Moments, unsent deliveries. Nothing else. |
| `sent` | `#2F6F4F` | `#57A67C` | Delivered receipts only |

Contrast: `ink`/`paper` ≥ 13:1, `graphite`/`paper` ≥ 4.6:1, `accent`/`paper`
≥ 4.5:1. No state is signalled by colour alone (PRD §10) — recording also
pulses and is labelled, deliveries also carry an icon.

### Type — one family, `.serif` for the user, `.default` for the machine

| Token | Style | Use |
|---|---|---|
| `noteBody` | `.body`, serif, `ink` | What you typed |
| `machineBody` | `.body`, default, `graphite` | What the AI added |
| `transcriptBody` | `.callout`, monospaced digits for timestamps | Transcript |
| `sectionTitle` | `.headline` | Recipe sections |

The serif/sans split is the load-bearing signal of F-11: at a glance, you can
always see which words are yours. It survives greyscale, Dynamic Type, and
VoiceOver (AI content carries an accessibility prefix, "Added by Earshot:").

### Spacing — 4pt scale

`xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32`. No magic numbers.

### Motion

One motion primitive: the recording pulse (2s ease-in-out, opacity 0.5→1.0).
Everything else is a standard SwiftUI transition. `reduceMotion` replaces the
pulse with a static filled dot — never nothing, because the indicator is a
trust surface (F-5).

## 3. Screen inventory

| Screen | Job | Key requirement |
|---|---|---|
| **Shelf list** | Home. Notes newest-first, grouped by day, search. | Must load in < 200ms with 5,000 notes |
| **Capture** | Two panes: your notes / live transcript (F-1) | Keyboard focus on *your* pane at launch |
| **Review** | Digest + action items with accept/edit/dismiss | Accept-all must be one tap |
| **Delivery sheet** | Exactly what leaves, where (F-17) | Never pre-confirmed on first use of a target |
| **Note detail** | Enhanced note, transcript toggle, receipts | "Strip AI" restores raw notes (F-11) |
| **Threads** | Ask across the archive (F-21) | Every answer cites note + timestamp |
| **Privacy Ledger** | Everything that ever left (F-27) | Empty state is the *goal state*, worded as such |
| **Recipes** | Manage output templates (F-13) | — |
| **Settings** | Speakers, consent, sync, tier | Pricing promise visible here |

## 4. Capture screen — the one screen that matters

```
┌──────────────────────────────────────┐
│ ● 12:04   Weekly Product         ⋯   │  accent dot pulses; elapsed always visible (F-5)
├──────────────────────────────────────┤
│                                      │
│  Your notes                          │  serif, ink, cursor here on open
│  - Priya pushing for the Nov date    │
│  - I said infra isn't ready |        │
│                                      │
├────────── drag to resize ────────────┤
│  Transcript              🔍          │  sans, graphite, searchable (F-3)
│  Priya  12:03  ...we should just...  │  speaker chips, tappable to rename (F-10)
│  You    12:04  ...the migration...   │
├──────────────────────────────────────┤
│        ⌾ Moment            Stop      │  Moment = large, thumb-reachable (F-4)
└──────────────────────────────────────┘
```

Rules:
1. The notes pane is never smaller than 40% of the screen. The machine does not
   get to crowd the human.
2. Nothing may steal keyboard focus mid-meeting. No modal, no toast, no
   permission prompt (all permissions are resolved before capture starts).
3. The Moment button is at least 60×60pt and reachable one-handed. It is the
   only control that must work without looking.
4. If transcription fails, capture *continues* and says so quietly in the
   transcript pane. Losing the transcript must never lose the audio or notes.

## 5. Watch UI

Three screens, no more.

- **Idle**: one large "Capture" button filling the face. Below it, the next
  calendar meeting if within an hour.
- **Recording**: elapsed time, a Moment button occupying the lower half, Stop
  behind a swipe (never adjacent to Moment — a mis-tap must not end the
  recording). Screen stays dark until wrist-raise. **No sound.** (WATCH §4)
- **Review**: action-item cards, swipe right accept, left dismiss.

Haptics: `.success` for Moment, `.stop` for capture end, `.notification` for a
meeting nudge. Every audio cue has a haptic equivalent (PRD §10).

## 6. Empty and failure states — written, not improvised

| State | Copy |
|---|---|
| No notes yet | "Nothing here yet. Tap capture when your next conversation starts — nothing leaves this iPhone." |
| Privacy Ledger empty | "Nothing has ever left this device. That's the idea." |
| Apple Intelligence unavailable | "This iPhone can't run the on-device model, so Earshot is using plain extraction — accurate, just less fluent. Nothing was sent anywhere." (F-14) |
| Transcription failed mid-capture | "Transcript paused. Still recording — you won't lose the audio." |
| Watch capture waiting | "1 capture waiting for your iPhone." |

Tone: plain, specific, never apologetic, never cute. Never says "Oops."
