# P2 — Strategy Brief: Earshot

Status: APPROVED · Last updated: 2026-08-25 · Upstream: `P1-research/EVIDENCE.md`

---

## The name

**Earshot**. Plain English, spells itself when you hear it, and it says what the
app does without being another "-ly" or "AI" compound.

It also does the strategic work for free: *earshot* is a boundary. Everything
within it is heard; nothing outside it is. That is precisely the privacy claim
(F-24) — the conversation goes as far as the phone in your pocket and no
further. Tagline: **stays within earshot.**

## Positioning statement

> For people who take their own notes and resent being metered on their own
> memory, Earshot is a meeting notepad that runs its AI entirely on your
> iPhone. Unlike Granola, your whole history is free forever, your speakers are
> named, and every action item leaves the app on its own.

## The three bets

**Bet 1 — The cost floor fell out, so the paywall should move.**
Apple's on-device ASR (E-8) and on-device LLM (E-9) cost us nothing per minute.
Granola meters history (E-1) because it pays for cloud inference. We don't, so
we won't. *Unlimited meetings, unlimited history, unlimited AI notes, free,
forever.* This is not generosity; it is the only defensible wedge against a
$1.5B competitor, and it is the loudest complaint in the category.

**Bet 2 — Name the speakers.**
On-device diarization (E-10) is a solved, MIT-licensed problem that Granola
still gets wrong (E-2). Voice prints are enrolled locally and persist across
meetings, so "Speaker 2" becomes "Priya" once, forever. Calendar attendees are
a *hint*, never the source of truth.

**Bet 3 — The note is not the deliverable. The follow-through is.**
The category's own reviewers say nothing is good at what happens after the
transcript (E-3, E-7). Earshot's output is not a document — it's a set of
**Deliveries**: reminders that appear in Reminders with real due dates, calendar
holds, a drafted follow-up email, a file in your Obsidian vault, a webhook.
Configured once per meeting type, fired automatically, always previewable
before they go.

## What we deliberately keep from Granola

Per E-6, these are load-bearing and must not be "improved":

- No bot joins the call. Ever.
- You type your own notes during the meeting. The AI enhances; it does not
  replace your voice.
- The post-meeting document reads like *your* notes, filled in.

## What we deliberately refuse

| Refusal | Why |
|---|---|
| No account required to use the app | E-4. Sign-in is for sync, not for function. |
| No training on user content, ever, at any tier, no toggle | E-4. A toggle implies a default. |
| Share links are private by default and expire by default | E-4 inverted. |
| No enterprise seat-count pivot in year one | E-5. Individuals first. |
| No "AI credits" | Bet 1 collapses if we meter anything per-minute. |

## Monetization

Free tier is genuinely complete. **Earshot Pro — $6/mo or $49/yr** (deliberately
under Granola's $14) sells *convenience and reach*, never access to your own
data:

- Deliveries beyond the two built-in ones (Reminders, Markdown export)
- **Threads** — ask questions across your entire archive
- **Pre-read** — auto brief before a meeting, built from your history with those people
- Encrypted iCloud sync across your devices + Mac app
- Cloud escalation for >2h recordings using your own API key (BYO), or ours
- Custom Recipes beyond the three built-in ones

Explicit anti-goal: nothing that exists on the device should ever move behind
the paywall in a later release. Written into `PRICING_PROMISE.md` and shown
in-app.

## Success metrics (12 weeks post-launch)

| Metric | Target | Why this one |
|---|---|---|
| Meetings captured per active user per week | ≥ 4 | The habit is the product. |
| % of meetings where the user typed ≥ 1 note themselves | ≥ 60% | Proves we kept E-6, not drifted into a bot. |
| % of extracted action items that are *accepted* by the user | ≥ 70% | Extraction quality, honestly measured. |
| % of accepted action items **delivered** out of the app | ≥ 90% | Bet 3. The whole thesis. |
| Speaker-label correction rate after first enrollment | ≤ 10% | Bet 2. |
| Free → Pro conversion | 4–6% | Sanity only. Not a north star. |
| Watch-initiated captures / total captures | ≥ 15% | Proves the Watch is a real surface, not a demo. |

## The one-sentence risk

If Apple's on-device summary quality is materially worse than a frontier cloud
model on messy 45-minute multi-speaker audio, Bet 1's economics survive but the
product's perceived quality does not — mitigation is the honest-quality ladder
in `P4-technical/RFC.md` §6, not silently shipping cloud inference.
