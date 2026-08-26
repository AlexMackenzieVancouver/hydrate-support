# P2 — PRD: Earshot v1.0

Status: APPROVED · Upstream: `STRATEGY_BRIEF.md`, `P1-research/EVIDENCE.md`

Requirement IDs (`F-n`) are cited by code and by the fidelity checker. Every
requirement names the evidence it answers.

---

## 1. The core loop

```
        ┌── Watch: one tap ──┐
Calendar│                    │
 nudge  ├── iPhone: one tap ─┼──▶ CAPTURE ──▶ ENHANCE ──▶ REVIEW ──▶ DELIVER
        │                    │     (live)      (local)    (accept)   (out)
        └── Shortcut / Siri ─┘
```

The loop must close in under 90 seconds for a 30-minute meeting, entirely
offline, on an iPhone 15 Pro or later.

---

## 2. Capture

**F-1 · Two-pane live view.** Left/top: your own typed notes, plain text, always
editable, never touched by AI during the meeting. Right/bottom: live transcript.
The user's pane is the primary focus target on launch. *(E-6 — this is the thing
people love; do not invert it.)*

**F-2 · No bot, ever.** Capture is microphone-local. Earshot never joins a
conference call as a participant, never dials in, never appears in an attendee
list. *(E-6)*

**F-3 · Live transcript with search.** Transcript streams during the meeting
with sub-2s latency and is searchable mid-meeting. *(Otter's differentiator, C)*

**F-4 · Moments.** One tap (phone) or one firm press (Watch) drops a timestamped
bookmark. Moments are hard anchors: the summary must quote or reference every
Moment. Haptic confirmation, no visual interruption.

**F-5 · Consent surface.** Before first capture, and on request thereafter,
a one-tap "Tell the room" card: a plain-language sentence to read aloud, plus a
persistent, non-dismissible recording indicator. If the device region is in a
known all-party-consent jurisdiction, the consent card is shown *every* time
until the user checks "I handle this myself." Earshot never records without an
on-screen indicator. *(Trust surface — E-4 inverted.)*

**F-6 · Nothing is lost.** Audio is written to disk continuously in ≤10s chunks.
Force-quit, battery death, or a crash loses at most the final chunk. On next
launch, an interrupted capture is offered for recovery.

## 3. Speakers

**F-7 · On-device diarization.** Every transcript segment carries a speaker
index. *(E-10)*

**F-8 · Persistent voice prints.** Naming a speaker once stores a local voice
embedding; the same voice is auto-named in future meetings. Embeddings never
leave the device and are deleted with the speaker. *(E-2 — the direct fix.)*

**F-9 · Calendar as hint only.** Attendee lists rank naming suggestions. They
never assign a label on their own. *(E-2 — Granola's exact failure mode.)*

**F-10 · Correction is one tap.** Tap any speaker chip in the transcript →
rename → the change applies retroactively to the whole meeting and forward to
all future ones.

## 4. Enhance

**F-11 · Enhancement, not replacement.** Output is the user's own notes with
gaps filled, in the user's ordering. Machine-added content is visually
distinguishable and can be stripped in one tap to recover the raw notes. *(E-6)*

**F-12 · Structured extraction.** Every meeting produces: summary, decisions,
action items (text + assignee + due date when stated), open questions, and
follow-ups. Structured, typed output — not prose that has to be re-parsed.

**F-13 · Recipes.** Output templates. Ship three (Standard, 1:1, Interview);
Pro users author their own with named sections and per-section instructions.
A Recipe can be auto-selected by meeting title pattern, attendee count, or
calendar category. *(Matches Granola's Recipes, plus auto-selection.)*

**F-14 · Honest quality ladder.** If on-device summarisation is unavailable or
the transcript exceeds the model's context, the app says so plainly and offers:
(a) chunked local summarisation, (b) deterministic template extraction, or
(c) BYO-key cloud — never a silent downgrade and never a silent upload.

**F-15 · Zero-note meetings still work.** If the user typed nothing, the Recipe
runs against the transcript alone.

## 5. Deliver — *the differentiator*

**F-16 · Deliveries.** Post-review, accepted content is pushed out via
configured targets. v1 targets:

| Target | Behaviour | Tier |
|---|---|---|
| Reminders | One `EKReminder` per accepted action item, with due date + notes deep-link | Free |
| Markdown / Files | One `.md` per meeting to any Files location or Obsidian vault | Free |
| Calendar | Holds for follow-ups with an explicit date | Pro |
| Mail draft | Pre-composed follow-up, never auto-sent | Pro |
| Shortcuts / Webhook | Full note as JSON to any endpoint or Shortcut | Pro |

**F-17 · Preview before send.** Every Delivery shows exactly what will leave the
device and where, with a per-item toggle. Nothing outbound is automatic on the
first run of a given target. *(E-4)*

**F-18 · Delivery receipts.** A per-note ledger records what left, when, and to
where — including "nothing left this device," which is the common case.

**F-19 · Round-trip.** Completing the Reminder marks the action item done in
Earshot. The follow-through is observable. *(E-3, E-7 — the category's
admitted failure.)*

## 6. Recall

**F-20 · Shelves.** Local folders that carry standing context (project glossary,
people, goals) injected into summarisation for meetings filed there.
*(Granola's Spaces, minus the requirement to be an enterprise.)*

**F-21 · Threads (Pro).** Ask a question across the whole archive; answers cite
the meetings and timestamps they came from. On-device embedding + retrieval,
answered by the on-device model. *(tl;dv's differentiator, C.)*

**F-22 · Pre-read (Pro).** 15 minutes before a calendar meeting, generate a
brief from prior notes with those attendees: what was decided, what's open,
what you owe them. Delivered as a notification. *(Granola's Briefs.)*

**F-23 · Export is a right, not a feature.** Full-archive export to Markdown +
JSON, unpaywalled, at every tier, including audio. No export restriction may
ever be added. *(E-1, E-5.)*

## 7. Privacy — hard requirements

**F-24** Default state is fully local. Nothing reaches a network without an
explicit, per-target, previewed user action.
**F-25** No content is ever used to train any model, at any tier. No toggle.
**F-26** Share links: private by default, expiring by default, revocable.
*(Direct inversion of E-4.)*
**F-27** A visible **Privacy Ledger** screen: every byte that has ever left the
device, per note, with target and timestamp.
**F-28** No account required for the entire free feature set.

## 8. Free vs Pro boundary (frozen)

**Free forever:** unlimited meetings · unlimited history · unlimited on-device
AI notes · diarization + voice prints · Moments · 3 Recipes · Reminders &
Markdown deliveries · full export · Watch app.

**Pro ($6/mo, $49/yr):** Threads · Pre-read · custom Recipes · Calendar/Mail/
Webhook deliveries · encrypted cross-device sync · long-recording cloud
escalation.

**Frozen:** no capability listed as Free may move to Pro in any future release.
Enforced by `monetization-guardian` in CI against this table.

## 9. Non-goals for v1.0

Android · web app · real-time multi-user collaborative editing · CRM
integrations · team seats/admin console · video recording · translation ·
in-call bot of any kind.

## 10. Accessibility (launch-blocking, not polish)

Full VoiceOver on capture and review · Dynamic Type to AX5 without truncation ·
reduce-motion honoured on the capture pulse · transcript readable at 200% ·
no colour-only state · haptic parity for every audio cue on Watch.
