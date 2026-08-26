# STATUS.md

**Phase:** P5 Implementation — pre-first-build
**Last session:** 2026-08-26 · initial canon + full source authoring

## Canon

| Phase | State |
|---|---|
| P1 Research & evidence | ✅ approved |
| P2 Strategy + PRD | ✅ approved |
| P3 Design system | ✅ approved |
| P4 Technical RFC + Watch architecture | ✅ approved |
| P5 Backlog | ✅ active |
| P6 QA strategy | ⬜ not started |
| P7 App Store pack | 🟡 draft |
| P8 Post-launch | ⬜ not started |

## Code

| Area | State |
|---|---|
| Data model + repository | written, uncompiled |
| Intelligence (ASR / summariser / ladder) | written, uncompiled |
| Deliveries (Reminders, Markdown) | written, uncompiled |
| Capture + chunked durable audio | written, uncompiled |
| Watch link + watchOS app | written, uncompiled |
| iOS views (list, capture, review, consent) | written, uncompiled |
| Diarization | protocol only — IMPL-12 |
| Colour assets | missing — IMPL-11 |
| Tests + corpus | missing — IMPL-13 |

**Nothing here has been compiled.** No Swift toolchain in the authoring
environment. First build is IMPL-10.

## Metrics baseline

None yet — pre-launch. Targets in `canon/P2-product/STRATEGY_BRIEF.md`.

## Whole-project checklist for the last session

- [x] Watch surface — designed and written; state ownership documented
- [x] Widget surface — complications specced (WATCH §6), not built
- [ ] Notification surface — Pre-read notifications are Pro, not built
- [x] Monetization boundary — `Feature.tier` frozen against PRD §8
- [x] Progress semantics — action item review/completion round-trip defined
- [x] Trust surface — consent, ledger, tier disclosure all specced and written
- [ ] Observability — MetricKit only, not wired
- [ ] Accessibility — specced as launch-blocking, not implemented (IMPL-17)
