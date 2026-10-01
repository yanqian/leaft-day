# F031 process group repair

FAST_CODING_EVIDENCE: F031

Second independent evaluation correctly rejected the timeout wrapper: a leader exiting on SIGTERM did not prove a SIGTERM-ignoring descendant stopped. Its real heartbeat probe and interrupted native result are retained.

Fixed with shared project-owned `scripts/process_cleanup.py`: after group SIGTERM and a bounded leader grace period, always SIGKILL the still-existing owned group independently of leader status, then reap the leader. Both bounded Evaluator and verification Runner use it. Added real-process heartbeat regressions for wrapper timeout, wrapper interruption and verification Runner timeout, explicitly confirming descendant readiness before checking no continued execution.

34 project Python tests passed (`.build/F031-group-repair-contracts.log`, 9.445s). Existing complete native results are historical candidates only. Final candidate requires independent fresh root and one reuse probe. Preserve F018 deferred and do not commit or install to a phone. Inspect current tests and the two known repairs first, then run exactly one fresh full root; stop promptly with a concrete rejection if a blocking issue is proven, otherwise record evidence and emit final verdict. Do not let a completed test wait indefinitely for report writing.

CODING_PASS: F031
