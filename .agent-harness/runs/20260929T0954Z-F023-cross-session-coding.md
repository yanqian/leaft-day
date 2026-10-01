# F023 cross-session undo repair

FAST_CODING_EVIDENCE: F023
CODING_PASS: F023

Handoff: runs/20260929T095219Z-F023-work-fast-handoff.md. Previous rejection runs/20260929T0941Z-F023-reevaluation.md and prior coding receipt (archived byte-for-byte) retained.

## Implementation

ReviewEntryView captures the session UUID on successful pending mark and retains it across nearby exploration and recovery retry. ReviewSession.returnToUnmarked accepts that original UUID, reads the original durable session through existing repository session(id:), restores its original ordered IDs and mode at the original asset, validates availability/scope and saves before publishing. Missing session/asset or still-pending target throws instead of silent success. Save failure leaves the currently displayed nearby session unchanged and supports retry using the original session ID. No harness runtime changes, no anniversary-scope widening.

## Verification

- Final-source targeted .build/F023-cross-targeted.xcresult passed all 8 PendingAdvanceTests and the new cross-session PendingUITest. Domain case covers original anniversary scope/ID restoration, inaccessible asset rejection, injected save failure and retry, missing session rejection, and durable reopen. UI case covers mark -> completion -> nearby -> undo -> original asset / one-item count -> restart.
- Existing full independent root on the immediately preceding repair passed 78 unit / 29 UI in .build/test-run.LNtUeB/Tests.xcresult but was correctly rejected for this uncovered cross-flow. This is NOT claimed as a final-source full pass. Independent evaluator must run final root including new tests (expected 79 unit / 30 UI).
- git diff --check passed. All tests generated simulator assets only.
- User verification checklist updated in docs/manual-review-2026-09-29-v4.md with cross-session flow. Diagnostics and prior failures preserved.

Awaiting independent evaluation; no install, commit, push, private photo test or F018 acceptance.
