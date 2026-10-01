# Run Record: F025 - independent recovery and welcome reevaluation

## Summary
- Date: 2026-09-30 (Asia/Singapore)
- Agent role: separate cold-start Evaluator, rendered provider prompt for F025.
- Feature: F025
- Result: accepted after independent complete recovery.

## Repository State
- Starting and ending commit: 00a2fcc.
- Pre-existing dirty work preserved; no product implementation changes, commits or device deployment.
- Feature remains in_progress/passes=false at evaluation time; orchestrator owns completion transition.
- Relevant source hashes recorded and rechecked unchanged in `20260930-F025-reevaluation-evidence/source-sha256.txt`.

## Commands Run
- Read root/canonical AGENTS, progress, feature list, git log -20, SPEC R18 and QUALITY.
- Read normalization, decomposition, failure-domain, evaluator-evidence, capability-gap, example-boundary and agent-workflow rules.
- Inspected F025 welcome/access model, PhotoKit gateway, permission domain, shared backdrop/glass, UI tests, recovery script, diagnostics and fast handoff/coding receipts.
- `./init.sh`: initial sandbox run failed opening Swift ModuleCache; approved full-environment rerun exited 0.
- `xcrun xcresulttool get test-results summary` for final main/setup bundles and prior compact six-case bundle. Final bundle parsing required approved TestReport-cache access.
- `git diff --check` and source hash verification passed.

## Evidence
- Durable log and summaries: `20260930-F025-reevaluation-evidence/`.
- Final main bundle: `.build/test-run.6GCtnt/Tests.xcresult`, iPhone 17 simulator, iOS 26.5; 115 passed, zero failed/skipped (80 unit + 35 UI).
- Native setup bundle: `.build/test-run.6GCtnt/PermissionSetup.xcresult`, one passed, zero failed/skipped.
- Root also passed harness verification, generated-fixture/Python checks, build, simulator install and launch with APP_READY. Physical/iCloud acceptance remains explicitly deferred to F018.
- Native denied/full/limited-empty/limited-selection-update tests and both welcome tests passed in this independent full run. Prior compact `.build/F025-native-recovered.xcresult` independently inspected: iPhone SE3 iOS26.5, six passed, zero failures/skips.
- Visually inspected `docs/design/F025-welcome-glass.png` and `F025-welcome-large-opaque.png`: bundled atmospheric image, glass symbol, title/guidance and reachable request action; largest text intentionally scrolls with a fixed action. UI audits cover hit regions, descriptions and clipped text.
- Loading gate hides request/guidance until the snapshot resolves; bundled-only artwork does not query PhotoKit. Gateway guards reads by permission. Readable permissions route directly to Home; denied opens Settings, restricted retains truthful guidance, foreground refresh remains active and avoids overlap with the native request.
- SPEC has all required normalization fields and explicitly separates F025 from F024 and F009. No example surfaces repurposed, required capabilities present.
- Fast handoff `20260929T155713Z-F025-work-fast-handoff.md` and `20260930-F025-repair-coding.md` contain durable coding markers without evaluator spoofing. This separate evaluator dispatch provides the gate; no nested orchestrator or coding was performed.

## Failure Analysis
- Failure domain: none outstanding for F025. Evaluation tooling encountered environment_gap from sandbox cache restrictions; approved retries resolved it without source changes.
- Prior failure summary: missing simulator authorization precondition and stale orientation event handling.
- Harness improvement: required durable project recovery improvement is present in `scripts/recover-ios.sh` and `docs/verification.md`: selected-simulator clean boot plus native full-access setup before the whole suite. This independent whole-root run verifies the repair, including all rotation cases. No additional harness framework change required.
- Follow-up feature: F018 retains its existing physical-device/iCloud boundary; unrelated F009 work is not accepted here.

## Files Changed
- Only this evaluation record and its evidence directory.

## Evaluator Result
EVAL_PASS: F025

## Follow-Up
- Orchestrator may record F025 completion using this evaluator result. Human review remains optional; no installation or publication performed.
