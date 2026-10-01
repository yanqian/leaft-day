# Run Record: F009 - v5 cover layout independent reevaluation

## Summary

- Date: 2026-09-30 Asia/Singapore.
- Agent role: separate cold-start Evaluator, rendered hidden-layout provider prompt.
- Feature: F009.
- Result: accepted after independent full recovery and visual verification.

## Repository State

- Starting and ending commit: 00a2fcc.
- Existing extensive uncommitted work preserved. No product source or feature flags changed by this evaluator. F009 remains in_progress/passes=false for the calling orchestrator to transition.
- Read root/canonical AGENTS, progress, feature list, recent 20 commits, SPEC, QUALITY, spec normalization, decomposition, failure domains, evaluator evidence, capability gaps, example boundaries, and agent workflow.
- Verified work-fast handoff 20260929T170627Z-F009-work-fast-handoff.md and coding receipt 20260930-F009-v5-layout-repair-coding.md. Receipt has FAST_CODING_EVIDENCE and CODING_PASS only, no evaluator spoofing. Prior visual rejection remains durable. Routing record explains the cumulative-attempt override and unused F018 handoff; no F018 completion is accepted.
- This evaluator dispatch does not recursively invoke another orchestrator. SPEC v5 has all nine normalization fields; F025 authorization and F024 history are separately scoped. F009 is the original home/shared-glass promise reopened for repair. Product implementation is in project-owned source/test paths, not default examples.

## Commands Run

```bash
git log --oneline -20
./init.sh
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path .build/F009-v5-cover-final.xcresult
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path .build/test-run.QKbNHZ/Tests.xcresult
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool export attachments --test-id HomeCoverStateTests --path .build/test-run.QKbNHZ/Tests.xcresult --output-path .agent-harness/runs/20260930-F009-v5-reevaluation-evidence/states
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool export attachments --test-id HomeTests --path .build/test-run.QKbNHZ/Tests.xcresult --output-path .agent-harness/runs/20260930-F009-v5-reevaluation-evidence/home
```

## Evidence

- Independent root ./init.sh exited 0: harness verification, six Python checks, generated fixtures, XcodeGen, native full-access authorization preflight, 80 unit tests and 36 UI tests passed, installation and launch emitted APP_READY. Device verification explicitly deferred to F018.
- Fresh result: .build/test-run.QKbNHZ/Tests.xcresult. xcresulttool summary: 116 passed, zero failed/skipped/expected failures. Xcode 26.6, iPhone 17 simulator, iOS 26.5. Build, permission setup and xcodebuild logs remain in that result directory. No SwiftData Unbinding gate failure.
- Supporting compact result independently read: .build/F009-v5-cover-final.xcresult, iPhone SE3/iOS26.5, five passed, zero failed/skipped. This coding-phase evidence supplements, rather than replaces, the independent final root run.
- Source hashes of 96 source/test/script/config files saved in sibling evidence/source-sha256.json during startup and compared after completion; no changes detected. git diff --check passed.
- Exported all ten fresh maximum-type cover/hero state attachments and seven HomeTests attachments with manifests. Visually inspected all ten state screenshots plus fresh ordinary home and scrolled maximum-type home. Also inspected approved v5 design and compact actual normal/large/opaque-unavailable/download/empty/offline screenshots.
- Previous blocker is resolved: HomePhotoCardContent keeps title and non-image state within one growing glass caption; HomeHeroCardContent similarly places title/status/summary/action in vertical flow. No status hides beneath an overlaid caption, meaningful status is accessible, and type is not reduced to fit. New HomeCoverStateTests exercises both actual production components at accessibility XXXL across empty/loading/downloading/offline/unavailable, including opaque unavailable, with label, on-screen bounds, ordering, hittability and accessibility audit assertions. These are presentation-state injections, not claims of real iCloud verification.
- Acceptance 1: three actual home entry flows and persisted Continue pass real UI navigation coverage; no cleaning leaderboard or extra cleanup feature introduced.
- Acceptance 2: shared native glass, two slim review pills, top close and accessible actions remain intact; full glass, tap, orientation and large-type UI regressions pass.
- Acceptance 3: pending card is last, uses trash icon, and computes ready/unknown counts from current records and accessible assets. Read failures are explicit. Limited permission and reconciliation notices precede it; home.scope is absent.
- Acceptance 4: actual main/compact screenshots retain tall secondary photo cards, photo-derived atmosphere and glass captions. Compact geometry assertions prove ordinary pending card fits initially. Maximum type stacks cards, allows scrolling and shows distinct non-overlapping content.
- Acceptance 5: HomeCoverLoader still filters photos, bounds fallback to three candidates in the segment, distinguishes non-image states, guards request generation/attempt, and cancels stale requests. Four loader unit tests pass. No whole-library request expansion or video cover substitution.

## Failure Analysis

- Failure domain: none outstanding for F009. Evaluation-only environment_gap resolved: initial xcresulttool export/summary could not write TestReport cache under sandbox; approved escalated retry succeeded.
- Failure summary: prior implementation_gap/test_gap repaired and independently verified; old rejected run and screenshots retained.
- Harness improvement: prior evaluator required a durable maximum-type cover-state regression; it is now implemented against production components and included in root verification. Existing visual-evaluation rule successfully caught the original defect. No further generic harness engine improvement required for this repaired layout.
- Follow-up feature: F018 remains incomplete for actual physical/iCloud/performance acceptance; no scope bypass or device claim made here.

## Files Changed

- This evaluation record and sibling screenshot/manifest/hash evidence only, aside from generated build/recovery artifacts.
- No product edits, feature state transition, commit, push, physical-device install, or new feature implementation.

## Evaluator Result

```text
EVAL_PASS: F009
```

## Follow-Up

- Calling orchestrator may complete F009 using this independent receipt. Preserve existing human-feedback history.
- Any delivery build must be rebuilt from the repaired source; this evaluation did not install a physical-device build. Do not schedule F018 as part of this acceptance.
