# SESSION_LOG.md

## 2026-08-26 — Session 1: canon + initial source

**Objective:** Design and author a Granola-class meeting notepad for iOS +
Apple Watch, improved against real user feedback, Granola's shipped 2026
roadmap, and competitor strengths — using free on-device AI throughout.

### What was produced

- `canon/P1-research/EVIDENCE.md` — 11 numbered, sourced findings covering
  Granola's 2026 rebrand and pricing, its Series C enterprise pivot, its shipped
  features (Recipes, Spaces, Briefs, MCP, API, Android, Apple Watch), the
  recurring user complaints, competitor strengths, and the free on-device AI
  stack that changes the economics.
- Full canon P2–P5 and P7: strategy brief, PRD (28 numbered requirements),
  design system, technical RFC, watch architecture, privacy architecture,
  implementation backlog, App Store pack.
- `app/` — EarshotKit shared package (models, intelligence, delivery, capture,
  sync, support), iOS app, watchOS app, XcodeGen spec.
- `earshot/` — App Store-required support, privacy, and terms pages.

### Decisions worth remembering

1. **Free tier is unlimited by construction, not generosity.** On-device ASR +
   on-device LLM + on-device diarization cost nothing per minute, so there is
   nothing to meter. This is the wedge against a $1.5B competitor whose loudest
   complaint is a 30-day history cap.
2. **Deliveries are the product**, not the summary. The category's own reviewers
   say nothing is good at what happens after transcription; that is the gap.
3. **RevenueCat skipped** in favour of StoreKit 2 direct — deviation from the
   ios-app-os default, justified and recorded in RFC §9.
4. **The Watch gets two interactions a phone is worse at** — marking a moment
   without looking, and confirming action items — rather than being a remote
   shutter like the incumbent's.
5. **Named "Earshot"** after "Foolscap" was rejected. The name does double duty:
   earshot is a boundary, which is the privacy claim.

### Whole-project checklist

- Watch surface: designed, written, state ownership documented. ✅
- Widget surface: complications specced, not built. ⬜
- Notification surface: Pre-read is Pro, not built. ⬜
- Monetization boundary: `Feature.tier` frozen against PRD §8. ✅
- Progress semantics: action item review + completion round-trip defined. ✅
- Trust surface: consent, ledger, tier disclosure specced and written. ✅
- Observability: MetricKit only, not wired. ⬜
- Accessibility: specced launch-blocking, not implemented. ⬜

### Risks carried forward

- **Nothing was compiled.** No Swift toolchain in the authoring environment.
  The `SpeechAnalyzer` and `FoundationModels` call sites are the most likely to
  need adjusting against the shipping SDK.
- On-device summary quality on messy multi-speaker audio is unmeasured and is
  the single largest product risk.
- Watch battery per 60-minute standalone capture is unmeasured against the 12%
  budget.

### Repo note

The four Hydrate `.html` files at the repo root were briefly deleted during
restructuring and were restored byte-identical. They serve a shipped app's App
Store support and privacy URLs. Earshot's equivalents live under `earshot/`.
