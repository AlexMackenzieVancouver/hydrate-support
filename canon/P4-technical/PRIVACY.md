# P4 — Privacy Architecture

Status: APPROVED · Upstream: `P2-product/PRD.md` F-24 → F-28, `RFC.md` §7

## 1. The claim we are making

"Nothing leaves your device" is a marketing claim only if it is also an
architectural fact. This document is what makes it checkable.

Every claim below is verified before each App Store submission
(`P7-launch/APP_STORE.md` §3) and enforced per-commit by `pre_commit_guard`.

## 2. Enforcement, not intention

| Rule | How it is enforced |
|---|---|
| No networking in the free path | CI grep: only `RemoteSummarizer` and `WebhookDelivery` may import `URLSession`. Neither is reachable without an explicit per-note opt-in. |
| No outbound call without a receipt | Unit test: every `DeliveryTarget.deliver` returns a result, and `NoteRepository.record` writes the receipt in the same transaction. A call with no receipt fails the test. |
| No analytics | Dependency-graph check. `FluidAudio` is the only third-party package (RFC §9). |
| No training on user content | There is no pipeline, no upload, and no toggle. F-25. |
| Audio at rest | `.completeFileProtection`, in Application Support, excluded from iCloud backup unless the user enables sync. |
| Voice prints | Never exported, never synced, never in a share payload. Deleted with the speaker. |

## 3. Consent

`Consent.allPartyRegions` lists jurisdictions where all parties to a
conversation typically must agree to being recorded. It is deliberately
over-inclusive — a needless prompt costs a tap; a missing one can cost the user
their job.

**This is not legal advice, and the app says so in those words.** The list is
reviewed each release. It drives a prompt, never a block: Earshot does not
refuse to record, it makes sure the user knows to ask.

An unknown region resolves to *prompt*. Fail safe, not silent.

## 4. Privacy Ledger

Append-only, per note, showing target, timestamp, item count, and a
human-readable description of exactly what left — written for a suspicious
reader, not a reassured one.

The screen's empty state is the goal state and the copy says so: *"Nothing has
ever left this device. That's the idea."*

## 5. The App Store privacy label

**Data Not Collected**, across every category. This is only truthful while §2
holds, which is why §2 is enforced mechanically rather than by review.

## 6. What we deliberately do not do

- No account requirement for any free feature (F-28).
- No default-public share links. Private and expiring by default (F-26) — the
  direct inversion of the incumbent's default (E-4).
- No "anonymized data to improve our services" clause. There is no clause
  because there is no collection.
