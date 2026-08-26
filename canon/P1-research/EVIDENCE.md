# P1 — Evidence Base

Status: APPROVED · Last updated: 2026-08-25

Everything in this document is sourced. Product decisions downstream cite the
numbered findings here (`E-1`, `E-2`, …). If a finding is later contradicted,
revise this file first, then the PRD — never the other way round.

---

## A. What Granola is today (the thing we are making a version of)

| Fact | Source |
|---|---|
| Desktop-first "AI notepad": user types sparse notes, AI enhances them after the call. Does **not** join calls as a visible bot — captures system audio locally. | [Efficient App](https://efficient.app/apps/granola), [tldv](https://tldv.io/blog/granola-review/) |
| Feb 2026 rebrand + repricing. Free "Basic" plan, Business $14/user/mo, Enterprise from $35/user/mo. | [usecarly](https://www.usecarly.com/blog/granola-pricing/), [layer3labs](https://www.layer3labs.io/guides/granola-ai-pricing) |
| Mar 2026: $125M Series C at $1.5B. Explicit pivot from personal notetaker → **enterprise context platform**. | [SiliconANGLE](https://siliconangle.com/2026/03/25/granola-raises-125m-1-5b-valuation-ai-note-taking-app/) |
| Shipped 2025–26: **Recipes** (custom output templates), **Spaces** (shared team folders), **Briefs** (pre-meeting prep), **MCP integration** (notes into Claude/ChatGPT), **personal + enterprise API**. | [TechCrunch via search](https://www.createwith.com/tool/granola), [Granola updates](https://www.granola.ai/updates/whats-new-2026-01-16) |
| Jul 2026: Android app; **Apple Watch app** (free). Now Mac / Windows / iPhone / Android / Watch. | [MacRumors](https://www.macrumors.com/2026/07/28/granola-launches-on-apple-watch/), [9to5Mac](https://9to5mac.com/2026/07/28/granola-meeting-notepad-comes-to-watchos-as-apple-watch-becomes-an-ai-device/) |
| Watch app specifics: one-tap record from app or complication, screen goes green + confirmation sound, second tap stops, audio **syncs to paired iPhone** for processing, records offline, haptic reminders for upcoming calendar meetings. | [MacDailyNews](https://macdailynews.com/2026/07/30/granola-ai-notepad-launches-on-apple-watch-bringing-one-tap-meeting-notes-to-your-wrist/), [Yahoo Tech](https://tech.yahoo.com/wearables/articles/granola-launched-apple-watch-app-114156041.html) |

**E-0 — the Watch bar is now set.** Granola's watch app is a *remote shutter*: it
records, it does not think. All intelligence happens on the phone. That is the
gap we attack (see D).

---

## B. What users actually complain about

**E-1 · The free tier taketh away.** The Feb 2026 rebrand added a rolling
**30-day note-history window** on free — older notes are stored but you cannot
open them until you pay. Reported elsewhere as a 25-note lifetime cap.
Consistently the single loudest complaint.
Sources: [usecarly](https://www.usecarly.com/blog/granola-pricing/),
[alfred_](https://get-alfred.ai/blog/granola-pricing),
[itsconvo](https://www.itsconvo.com/blog/granola-ai-review)

**E-2 · Speaker attribution is unreliable.** Transcripts render as continuous
text with no speaker labels. AI notes try to infer speakers from calendar
invitees; accuracy collapses past 2–3 participants.
Sources: [tldv](https://tldv.io/blog/granola-review/),
[thebusinessdive](https://thebusinessdive.com/granola-review)

**E-3 · Notes are a cul-de-sac.** The most common structural complaint across
Reddit threads: notes stay isolated instead of flowing into the tools people
already work in.
Sources: [aitooldiscovery](https://www.aitooldiscovery.com/guides/granola-ai-reddit),
[hirekai](https://hirekai.ai/blog/granola-review)

**E-4 · Privacy defaults lean the wrong way.** Shared notes are viewable by
**anyone with the link, by default**. Non-enterprise data may be used
"anonymized" to improve the service; even on Business, model-improvement is
**on by default** and must be switched off.
Sources: [hedy.ai](https://www.hedy.ai/post/granola-redesign-alternative-hedy/),
[usecarly](https://www.usecarly.com/blog/granola-pricing/)

**E-5 · The enterprise pivot lost the original audience.** Visible unhappiness
on LinkedIn / Threads / Reddit about the new direction after the rebrand.
Source: [hedy.ai](https://www.hedy.ai/post/granola-redesign-alternative-hedy/)

**E-6 · What people genuinely love** (do not break these): no bot in the call,
you keep writing your own notes, AI fills the gaps rather than replacing your
voice. r/productivity, r/remotework, r/MacApps are positive on exactly this.
Source: [aitooldiscovery](https://www.aitooldiscovery.com/guides/granola-ai-reddit)

---

## C. Competitive field — what to take

| Tool | The one thing worth stealing |
|---|---|
| **Fathom** | Unlimited free recording; ~30-second post-call processing. Free tier that isn't a trap is a *growth strategy*, not charity. ([simular](https://www.simular.ai/alternatives/ai-meeting-note-takers)) |
| **Otter** | Best-in-class **live** transcription and real-time note collaboration *during* the meeting. ([itsconvo](https://www.itsconvo.com/blog/otter-vs-fireflies-vs-fathom)) |
| **Fireflies** | Workflow automation + CRM push — the meeting *causes* downstream records to exist. ([usecarly](https://www.usecarly.com/blog/best-ai-notetakers/)) |
| **tl;dv** | Cross-meeting pattern analysis — ask questions across the whole archive, not one call. ([itsconvo](https://www.itsconvo.com/blog/otter-vs-fireflies-vs-fathom)) |
| **Granola** | The core insight: your notes stay yours, AI fills gaps. |

**E-7 · The category's admitted failure.** Independent 2026 round-ups converge on
one sentence: *transcription is table stakes; almost nothing is good at what
happens after transcription.* Action items get captured but don't move
anywhere; summaries sit in an app nobody returns to.
Sources: [get-alfred](https://get-alfred.ai/blog/best-ai-meeting-notetakers),
[meetingnotes](https://meetingnotes.com/blog/best-ai-note-takers)

---

## D. The free / on-device AI stack (this is what makes the model work)

**E-8 · Transcription is free and local now.** `SpeechAnalyzer` +
`SpeechTranscriber` (iOS 26+) is Apple's long-form, on-device ASR — explicitly
optimised for lectures, meetings and conversations, low-latency, no model
download, no per-minute cost. `SpeechDetector` gives voice-activity detection.
Sources: [WWDC25 s277](https://developer.apple.com/videos/play/wwdc2025/277/),
[Callstack](https://www.callstack.com/blog/on-device-speech-transcription-with-apple-speechanalyzer)

**E-9 · Summarisation is free and local now.** The **Foundation Models
framework** exposes Apple's on-device LLM with guided/structured generation.
The documented pattern is exactly ours: transcribe with SpeechTranscriber →
summarise with the on-device model → never leave the device.
Sources: [swift-scribe](https://github.com/FluidInference/swift-scribe),
[dev.to WWDC25](https://dev.to/arshtechpro/wwdc-2025-the-next-evolution-of-speech-to-text-using-speechanalyzer-6lo)

**E-10 · Diarization is free and local now — and this is Granola's open flank.**
`FluidAudio` is an MIT/Apache-2.0 Swift SDK running pyannote-derived speaker
diarization and Parakeet TDT v3 ASR **on the Apple Neural Engine**, iOS 16+.
Granola cannot label speakers (E-2). We can, on-device, for free.
Sources: [FluidAudio](https://github.com/FluidInference/FluidAudio),
[Spokenly](https://spokenly.app/blog/parakeet-vs-whisper)

---

## E. The synthesis, in one paragraph

Granola won by removing the bot from the call. It is now spending its Series C
on becoming an enterprise context platform (E-0, A), and in doing so has
metered its users' own history (E-1), left speakers unlabelled (E-2), left
notes stranded in-app (E-3, E-7), set sharing and model-training defaults
against the user (E-4), and lost the individuals who made it (E-5). Meanwhile
Apple shipped free on-device transcription and a free on-device LLM (E-8, E-9),
and the open-source community shipped free on-device diarization (E-10). The
entire cost structure that justified the metering has evaporated. That is the
opening.
