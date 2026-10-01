# F023 completion recovery repair coding receipt

FAST_CODING_EVIDENCE: F023
CODING_PASS: F023

Handoff: runs/20260929T091455Z-F023-work-fast-handoff.md. This supersedes the first coding receipt archived byte-for-byte under runs/history-before-manual-review. Independent rejection runs/20260929T0903Z-F023-evaluation.md is retained; its 76/26 root pass did not accept the feature.

## Repair

- Completion previous/next controls now invoke the ReviewSession navigation path without requiring a current asset ID. Media intents still require a captured asset ID.
- Pending undo write failures present a visible alert even on completion; undo can be retried.
- Successful unmark followed by failed position save is a distinct recovery state, updates pending count, offers a minimum-44pt retry control, and does not repeat unmark.
- Restoring a persisted completed terminal session whose accessible last asset is no longer pending recovers that asset, supporting process restart after the split-save failure.
- DEBUG fault wrapper forwards real LocalStateStore operations and injects one armed failure, only in the test host. No effect on normal App route.

## Verification

- Final exact-source root ./init.sh exited 0: .build/test-run.Hv305i/Tests.xcresult, 78 unit / 29 UI, no failures; simulator app installed/launched. Log .build/F023-repair-root.log.
- Targeted .build/F023-repair-targeted.xcresult: 7 PendingAdvanceTests + 3 new PendingUITests passed, including completed previous navigation, undo write failure and successful unmark/failed position recovery.
- Actual screenshots exported and visually inspected: docs/design/F023-completion-undo-write-failure.png and F023-completion-position-recovery.png. Yellow diagnostic text belongs only to DEBUG fixture host.
- Prior compact actual-Home landscape completion/undo evidence remains .build/F023-landscape-final.xcresult; final full root includes the same test and repaired source.
- git diff --check passed.
- Signed package rebuilt from current sources; .build/v4-device-build-receipt.json records source/binary hashes. NOT installed, awaiting independent acceptance.

No private photo deletion, database export, commit or push. F018 remains deferred, not accepted. Coding evidence does not set evaluator result or feature pass state.
