# F002 Coding capability gap

- Date: 2026-09-27
- Role: orchestrated Coding Agent; supplied rendered F002 role prompt, no nested orchestrator or manual fallback.
- Starting commit: 6f6d466; incoming F002 status=in_progress, attempts=1 was preserved.
- Result: incomplete; only root evaluator-evidence baseline implemented.

## Verification

- Startup ./init.sh: PASS (32 unit, 32 contract, 11 harness, 2 smoke tests plus examples).
- ./scripts/doctor.sh: exit 1. Full Xcode 26.6 and SDK 26.5 detected; CoreSimulatorService invalid connection, logging Operation not permitted, device-set connection refused. See 20260927T0900-F002-doctor.log.
- command -v xcodegen: absent. No generator was selected/required yet; no hand-written generated project artifact substituted.
- Final ./init.sh: PASS, exit 0, evidence baseline F001 (1 completed feature checked, zero missing); see 20260927T0900-F002-final-init.log. Harness-only verification cannot establish App recovery.
- No real App build, launch or UI test has run. No project or test target created.

## Failure Analysis

- Failure domain: capability_gap
- Failure summary: mandatory simulator service unavailable to this Coding process, whose approval policy is never. No escalation is callable under this session contract.
- Harness improvement: outer orchestration must provision authorized Coding access to the same user-level services needed by Evaluator. Existing docs describe this requirement, but evaluator-only permission recovery did not resolve Coding access. Do not change security/provider settings from this role or bypass sandbox with another tool.
- Follow-up feature: none; resume F002 itself after the outer execution capability is supplied.
- Temporary workarounds: none.
- Example boundary: no examples changed.

## Files Changed

- init.sh: fixed evaluator evidence baseline F001, explicitly documented incomplete recovery.
- .agent-harness/feature_list.json: F002 last_error only; orchestrator retains transition/attempt ownership.
- .agent-harness/progress.md: recovery and permission blocker.
- This run record and logs.

Suggested eventual commit subject after completion/evaluation: F002 Add runnable iOS skeleton and project recovery
