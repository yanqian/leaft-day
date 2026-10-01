# F023 pending transition coding

FAST_CODING_EVIDENCE: F023

Handoff: 20260929T084104Z-F023-work-fast-handoff.md. Implements user-approved v4/R16, superseding only pending-after-action A01 (favorites still stay).

- PendingCoordinator still exclusively persists intent, never deletes originals. ReviewEntryView locks actions during save/transition, checks captured asset and session, then animates upward+fade over280ms (160ms fade-only for reduce motion). Failure to mark stays put. A later position-save failure truthfully retains the saved mark and offers retry/undo, with no false delete claim.
- ReviewSession holds original ordered IDs and skips pending IDs for next/previous/continuous extensions/nearby, scoped by existing snapshot. Optional completed payload persists terminal state without altering SwiftData entity schema. Remaining count is current-and-following non-pending session items, zero at completion; pending badge uses actual reviewable records with unknown count distinct. Home hero displays remaining/completed.
- Last mark presents a completion surface with persistent undo/back, not original media. Undo removes exact original intent and returns to its original position when still in current session; failed position restore does not claim mark is retained. Startup restores pending IDs and catches a saved mark whose advance was interrupted. Collection IDs are not erased or reordered.
- A 5-second actionable undo toast works with controls hidden; persistent toolbar undo remains. Completion suppresses redundant toast to prevent overlap on small landscape. Completion body scrolls for large text. Photo fit/zoom/video and native delete confirmation unchanged.

Verification:
- .build/F023-targeted.xcresult: five new pending/session fault tests + six continuity tests passed; initial UI toast timing failure retained (not overall pass).
- .build/F023-pending-fixed.xcresult: both standard swipe/undo/restart/favorite-confirm and reduced-motion video/end/undo/restart UI passed.
- Root ./init.sh exited0, .build/test-run.W4KKFP/Tests.xcresult:76 unit/25 UI, all existing permission/media/review/deletion checks passed.
- During root, final presentation refinements (completion scrolling and toast hit area) were added and tested separately in .build/F023-compact-recovered.xcresult: all three PendingUITests passed, including actual Home -> mark all -> landscape -> undo -> Home count. Direct-root fixture rotation and stale runner launch failures are preserved in diagnostics.
- Final completion-only fix suppresses overlapping redundant toast; .build/F023-landscape-final.xcresult passes actual Home/landscape plus button containment/non-overlap and Home count checks. Final screenshot docs/design/F023-completed-landscape-final.png uses full XCUIScreen capture; prior app-cropped landscape screenshot is historical, not final evidence.
- Evaluator must run complete root on final sources (76 unit/26 UI expected due added Home case); coding root predates the final presentation-only refinements, which have targeted final-source passes. git diff --check clean.

Signed package build prepared but no installation until separate acceptance. F018 remains unpassed. No commit/push, private-library test mutation or phone database export.

CODING_PASS: F023
