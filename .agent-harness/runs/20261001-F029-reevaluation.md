# Run Record: F029 - maximum text landscape repair reevaluation

## Summary

- Date: 2026-10-01 (Asia/Singapore)
- Agent role: independent cold-start Evaluator, dispatched by work-fast
- Feature: F029
- Result: accepted for normalized R22 simulator scope, including the reopened accessibility boundary.

## Repository State

- Starting/ending commit: 00a2fcc (no commit made).
- Existing uncommitted v3-v8 work preserved. Evaluator changed only this report and its evidence directory.
- F029 remains in_progress / passes=false for the orchestrator to transition; F018 remains todo / passes=false.
- 112 product/source/test/script files inventoried in `20261001-F029-reevaluation-evidence/source-hashes.json`; hashes unchanged after full recovery verification.
- Compared with the prior evaluator inventory, only ReviewStateTestHost.swift, ReviewEntryView.swift, VideoPlayback.swift and ReviewStateGlassTests.swift changed.

## Commands Run

```bash
./init.sh > .build/F029-reeval-init.log 2>&1
# Retry with approved Xcode/CoreSimulator filesystem permissions:
./init.sh > .build/F029-reeval-init-authorized.log 2>&1
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool export attachments --path .build/test-run.pwIzQ0/Tests.xcresult --output-path .build/F029-reeval-screenshots
git diff --check
```

## Evidence

- Full root recovery exited 0: harness layers, fixtures, six Python project tests, 85 unit tests and 44 UI tests passed with zero failures; native permission preflight passed separately. No SwiftData cross-queue Unbinding warning. App installed/launched successfully on the selected iOS 26.5 fixture simulator.
- Result: `.build/test-run.pwIzQ0/Tests.xcresult`; durable full output: `20261001-F029-reevaluation-evidence/init.log`.
- Work-fast dispatch confirmed in `.build/v8-F029-reevaluator.log` (round/evaluate F029). Repair handoff: `20260930T163459Z-F029-work-fast-handoff.md`. Repair coding record contains FAST_CODING_EVIDENCE and CODING_PASS, no evaluator-pass marker, and did not mark completion. Prior acceptance is historical and is superseded for current source by this evaluation.
- SPEC v8 contains required normalization fields and explicit decomposition. R22 is presentation integration over the separately accepted palette capability; media/domain algorithms, permissions and deletion protocols remain outside this feature. Implementations are project-owned, not repurposed harness examples.
- AC1: ComparisonView uses current-group PhotoColorBackdrop, readable fallback and shared glass; actual fixture selection, zero-keep guard, save, skip, keep-all and zoom tests passed, including maximum text/opaque controls.
- AC2: review state backgrounds use extracted color values or neutral fallback; completion/no-session/unavailable/retry states have scrollable glass presentation. Completion navigation, undo, write failure, position restoration and nearby-session undo regressions passed. Ready media fit, gestures, default control disclosure and video lifecycle remain intact.
- AC3: both actual-media landscape orientations, largest-type toolbar reachability, reduced-motion completion, opaque fallback, preview and zoom routes passed. The repaired accessibility toolbar uses a bounded 45 percent landscape height; video nonready states do not reserve unusable playback controls. Two new maximum-type landscape regressions passed independently: completion viewport fits at least a title line plus 8pt, and completion return/photo/video retry actions can be brought wholly above the toolbar. Resource-unavailable state geometry and exit also pass. Compact SE coding screenshots were separately inspected as supporting small-screen evidence, not substituted for this independent full run.
- AC4: independent five-state normal/maximum-text matrix and real-entry suites passed. `docs/design/v8-native-verification.md` provides the complete page inventory and explicitly separates F018. The matrix's pending evaluator labels are resolved by this run record.
- 33 screenshots retained in `20261001-F029-reevaluation-evidence/`; screenshots.json records original test/device/attachment provenance. Visually inspected the four new landscape captures, normal completion landscape, actual comparison, zoom and video error, plus compact coding completion-return/video-retry captures. At maximum text, content intentionally scrolls; the initial completion heading is below the icon and partially outside the viewport, while scrolling reveals the full return action. This is consistent with allowed accessibility scrolling; content is not hidden behind a non-scrollable toolbar.
- Rubric: correctness/completeness/maintainability/test coverage/recoverability/safety accepted. No implementation changes, personal-device installation/deletion, commit or push performed.

## Failure Analysis

- Failure domain: environment_gap for the initial sandbox invocation only; resolved by approved execution.
- Failure summary: Swift fixture generation could not write its standard module cache. The full retry passed. Attachment export similarly needed standard report-cache access and succeeded after approval. No verification was skipped or weakened.
- Harness improvement: prior missed maximum-type plus landscape combination was a product test_gap. Durable ReviewStateGlassTests now cover that combination with viewport geometry and full-action reachability, and are included in root recovery. No additional harness change is required; existing permission escalation and evaluator reopening gates worked.
- Follow-up feature: none required for F029. Real iCloud/private-library/large-library/multi-device acceptance remains F018 and is not inferred from simulator success.

## Files Changed

- `.agent-harness/runs/20261001-F029-reevaluation.md`
- `.agent-harness/runs/20261001-F029-reevaluation-evidence/`

## Evaluator Result

EVAL_PASS: F029

## Follow-Up

Orchestrator may complete only F029. Human review remains a separate optional layer. Preserve the older evaluation and repair history.
