# Run Record: F031 - independent process-group repair evaluation

## Summary

- Date: 2026-10-01
- Agent role: Independent Evaluator, rendered provider workspace prompt
- Feature: F031
- Result: accepted; durable evaluator evidence recorded; orchestrator owns completion state

## Repository State

- Starting commit: 3a9a54b
- Working tree: existing F031 implementation retained. Evaluator changes only this record and a reprobe result under runs/F031-evaluator-artifacts/.

## Commands Run

```bash
SWIPE_VERIFY_FRESH=1 ./init.sh
python3 .agent-harness/runs/F031-evaluator-artifacts/F031-evaluator-process-probe.py
git diff --check
env -u SWIPE_VERIFY_FRESH ./init.sh
```

## Evidence

- Read canonical startup state, root/harness rules, recent history, QUALITY and required normalization/decomposition/failure/evidence/capability/example/workflow documents. R24 contains all normalization fields and explains its coherent CLI boundary. Product-owned implementation paths are used; examples are untouched.
- Reviewed scripts/verification.py, visual_regression.py, process_cleanup.py, run-bounded-evaluator.py, root wrappers, recovery integration and contracts. No product Swift/UI changes. Retained work-fast handoff and coding markers do not contain a fabricated evaluator pass; F031 is not marked complete. F018 remains deferred.
- Initial sandbox fresh run failed CoreSimulator inventory: .build/verification/20261001T223802-iinqa1fw/summary.json. Permission-enabled retry uses the same fresh command and checks, not weakened verification.
- Independent permission-enabled fresh run: .build/verification/20261001T223906-ly20h43v/. Harness and 34 Python contracts passed; permission preflight 1/1 passed. Final summary passed: 129/129 (85 unit, 44 UI), zero failed/skipped/expected failures, 1020.2 seconds. All 21 execution steps exited 0, including build, native permission, main suite, result export, install and launch. Actual tree/count coverage agrees and 96 attachments are indexed. Xcode 26.6 (17F113), iOS26.5 fixture simulator 1DF82DB5-2A3B-450A-9EB5-098FC4E8F812.
- Re-ran the prior evaluator's real process heartbeat probe. F031-evaluator-artifacts/F031-group-repair-reprobe.json records wrapper exit 124, descendantAliveAfterWrapperExit=false, heartbeatWrittenAfterTimeout=false. Shared cleanup sends KILL to the owned group even when its leader exits on TERM. New durable regressions exercise timeout, interruption and verification Runner cleanup.
- git diff --check passed. Native xcresult schema fixtures are tied to real Xcode bundles in the external-contracts record. Prior changed-mode native run exercised conservative shared-change fallback to full; current contracts cover paths and selector mappings.
- Optional visual baseline remains unconfigured; no baseline approved by this evaluator. Screenshots are evidence, not automatic aesthetic approval.

- Independent same-environment reuse: .build/verification/20261001T225646-_2yze7px/summary.json passed in 70.1 seconds. Assertions verified exact fresh receipt reference and original finish time, identical fingerprints, no build/permission/tests steps, and successful harness, Python, install and launch steps. The original evidence lifetime was not extended. Read both final summary.json files before detailed receipts.

## Failure Analysis

- Failure domain: none established for the repaired implementation; initial sandbox attempt was environment_gap.
- Harness improvement: prior implementation_gap has a durable shared cleanup and real-process regression. No additional harness rule change is presently indicated; existing gating retained prior failures and forces independent fresh verification.
- Follow-up feature: none; F018 remains outside scope.

## Files Changed

- This run record.
- runs/F031-evaluator-artifacts/F031-group-repair-reprobe.json.

## Evaluator Result

EVAL_PASS: F031

## Follow-Up

Orchestrator retains ownership of feature state transitions. No implementation changes, commit, push or phone/private-library operations. F018 remains outside this acceptance. Optional visual baselines remain unconfigured and do not imply aesthetic acceptance.
