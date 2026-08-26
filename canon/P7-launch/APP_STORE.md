# P7 — App Store Submission Pack

Status: DRAFT · Upstream: `P2-product/PRD.md`, `P4-technical/RFC.md`

## 1. Listing

**Name:** Earshot
**Subtitle (30 char max):** `Meeting notes, off the cloud` (28)
**Bundle ID:** `ca.lifescience.earshot`
**Category:** Productivity · Secondary: Business
**Age rating:** 4+

**Promotional text (170):**
> Your notes, finished by AI that runs on your iPhone. Unlimited conversations,
> unlimited history, free forever — because nothing is sent anywhere to process.

**Description opening** (the part anyone actually reads):
> Earshot is a notepad that listens. You take your own notes the way you always
> have; when the conversation ends, it fills in what you missed — decisions,
> who committed to what, the questions nobody answered.
>
> The transcription and the AI both run on your iPhone. Not "encrypted in
> transit." Not "we delete it after 30 days." It does not leave.
>
> That's also why the free tier isn't a countdown. Unlimited conversations,
> unlimited history, unlimited AI notes. Your own past is not a subscription.

**Keywords (100 char, comma-separated, no spaces):**
`transcribe,meeting,notes,minutes,recorder,offline,private,summary,action,items,voice,watch,ai`

## 2. Screenshots — 6.9" and Apple Watch

Each screenshot sells one claim, in this order:

1. Capture screen mid-meeting — caption **"Take your own notes. It fills the gaps."**
2. Review screen with named speakers — **"It knows who said what."** *(the E-2 gap)*
3. Reminders with delivered action items — **"Action items that actually leave the app."** *(the E-7 gap)*
4. Privacy Ledger, empty — **"Nothing has ever left this device."** *(the E-4 inversion)*
5. Pricing promise in Settings — **"Free means free. Not 30 days."** *(the E-1 gap)*
6. Watch recording + Moment — **"Mark the moment without looking at anything."**

App Preview video: 18 seconds, no voiceover, real capture → real reminder.

## 3. App Privacy — the nutrition label

Declare **Data Not Collected** across the board. This is only truthful if
RFC §7 holds, so it is verified before every submission:

- [ ] No analytics SDK in the dependency graph
- [ ] `URLSession` imported only by `RemoteSummarizer` and `WebhookDelivery`
- [ ] Neither is reachable in the free path
- [ ] Every outbound path writes a `DeliveryReceipt` in the same transaction
- [ ] No `NSPrivacyTracking` domains in the privacy manifest

`PrivacyInfo.xcprivacy`: required-reason APIs limited to `UserDefaults`
(`CA92.1`) and file timestamps (`C617.1`). No tracking domains.

## 4. Review notes to Apple

> Earshot records audio only when the user taps Capture, with a persistent
> on-screen indicator throughout. Transcription uses SpeechAnalyzer and
> summarisation uses the Foundation Models framework — both entirely on-device.
> The app makes no network requests in its default configuration.
>
> To test: tap Capture, speak for ~30 seconds, tap Stop. Notes generate
> offline; you can verify in Airplane Mode. Reminders permission is used only to
> create action items the reviewer explicitly accepts.
>
> The Apple Watch app records standalone and transfers audio to the iPhone via
> WatchConnectivity for processing.

## 5. Rejection risks, pre-answered

| Risk | Guideline | Mitigation |
|---|---|---|
| Recording consent | 5.1.1 / legal | `Consent` surface (F-5), persistent indicator, purpose strings that state what is *not* done |
| "Free forever" claim | 3.1.1, 2.3.1 | Claim is literally true — no server, no metering. `PricingPromise` copy is the same in-app and on the listing |
| Background audio mode | 2.5.4 | Only used for an active user-initiated capture; no silent-audio keepalive |
| Watch app needs standalone justification | Watch HIG | `WKRunsIndependentlyOfCompanionApp` is genuine — offline capture is the feature |
| On-device model unavailable on older devices | 2.2 | Honest ladder (F-14) — app is fully functional at every rung, and says which is in effect |

## 6. Required URLs — served from this repo

- **Support:** `https://<pages-domain>/earshot/support.html`
- **Privacy:** `https://<pages-domain>/earshot/privacy.html`
- **Terms (EULA):** `https://<pages-domain>/earshot/terms.html`

> Note: Hydrate's own `support.html`, `privacy.html`, and `terms.html` remain at
> the repo root and are **live App Store URLs for a shipped app**. Do not move,
> rename, or delete them. Earshot's pages live under `/earshot/` for exactly
> this reason.

## 7. Pre-submission gate

Nothing is submitted until all of these pass:

- [ ] IMPL-10 through IMPL-17 complete (see `P5-implementation/BACKLOG.md`)
- [ ] Full flow works in Airplane Mode, end to end
- [ ] Watch battery ≤12% for a 60-minute standalone capture
- [ ] VoiceOver pass on capture and review
- [ ] AX5 Dynamic Type with no truncation on any screen
- [ ] Privacy Ledger reads empty after a full manual test pass
- [ ] `Feature.tier` diffed against PRD §8 — zero drift
