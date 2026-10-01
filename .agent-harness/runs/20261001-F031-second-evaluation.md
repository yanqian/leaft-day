# Run Record: F031 - independent repaired-candidate evaluation

## Summary

- Date: 2026-10-01
- Agent role: Independent Evaluator, rendered provider workspace prompt
- Feature: F031
- Result: rejected; no completion state written

## Repository State

- Starting/ending commit: 3a9a54be1d7489cab7e6295211d23f547d5fdf48
- Working tree: existing uncommitted F031 implementation retained; only this record and evaluator artifacts added.

## Commands Run

```bash
SWIPE_VERIFY_FRESH=1 ./init.sh
python3 .build/F031-evaluator-process-probe.py
 git diff --check
```

## Evidence

- Read canonical startup state, recent history, root/harness AGENTS, R24 normalization, decomposition rationale, QUALITY, failure/evidence/capability/example/workflow rules and coding handoffs. One coherent project-owned CLI capability is normalized; no example repurposing or coding pass spoofing found. Orchestrator work-fast handoff and retained prior adapter failure are durable. F031 was not prematurely done; F018 remains deferred.
- Initial sandbox attempt failed doctor/CoreSimulator inventory: `.build/verification/20261001T223020-bd8j8zux/summary.json`. Retried with authorized CoreSimulator access, not weakened checks.
- Independent fresh run `.build/verification/20261001T223117-g7w46tqt/summary.json`: Harness and 32 project Python contracts passed; build and native permission preflight passed (1/1). Main suite deliberately interrupted after a separate blocking defect was proven. Final report records Interrupted and tests exit -15. No full-suite or reuse success claimed for this candidate; fresh plus reuse remain required after repair.
- Defect at `scripts/run-bounded-evaluator.py:21-30`: stop() sends group SIGTERM but waits only for the leader. If the leader terminates promptly, the SIGKILL branch is skipped even when another group member ignores SIGTERM. It then prints a false claim that the owned group was stopped.
- Reproducible independent probe: `F031-evaluator-artifacts/F031-evaluator-process-probe.py` (run from project root). It starts a leader plus same-group descendant which ignores SIGTERM. Wrapper timeout is 1 second. Wrapper exits 124, descendant remains alive and writes a heartbeat after the deadline. Probe kills its own descendant and removes the heartbeat afterward.
- Captured result: `F031-evaluator-artifacts/F031-evaluator-process-probe.json`: heartbeatWrittenAfterTimeout=true, descendantAliveAfterWrapperExit=true, wrapperExit=124. This verifies continued execution, not merely a zombie PID.
- Existing two wrapper tests cover immediate-child timeout and exit propagation only; both pass despite this defect. Source review and current contract run therefore do not justify acceptance.
- No product source edits, commit, push or device/private-library operations.

## Failure Analysis

- Failure domain: implementation_gap (secondary test_gap).
- Failure summary: R24 failure-improvement requirement to terminate the owned process group on timeout is unmet. Surviving descendants can keep work or output pipes active after the claimed bounded stop.
- Harness improvement: required within F031: implement owned-group cleanup independent of leader wait status, and add a durable real-process regression with a promptly exiting leader plus SIGTERM-ignoring descendant. Verify timeout and interruption cleanup and avoid claiming termination while work survives. This is a project-owned adapter wrapper repair, not permission to alter unrelated harness examples or weaken evaluator gating.
- Follow-up feature: none; repair the same F031 because its accepted contract is unmet.

## Files Changed

- This run record and the two process-probe artifacts only.

## Evaluator Result

EVAL_FAIL: F031: implementation_gap; timeout wrapper leaves a SIGTERM-ignoring same-group descendant executing after exit 124; durable group-cleanup regression and wrapper repair required.

## Follow-Up

Repair cleanup and tests, then rerun independent fresh root and same-environment reuse once. Orchestrator owns attempts/failure/completion state. Do not reuse older candidate evidence as final acceptance.
