# F020 evaluator runtime interruption and retry

- Failure domain: capability_gap
- Failure summary: first cold evaluator exited before a verdict, reporting Codex usage-limit errors (log /tmp/swipe-F020-evaluator.log). Orchestrator preserved passes=false and returned feature to todo; run 20260928T152213Z-F020-failure.md retained.
- Evidence: desktop usage tool subsequently reported ordinary usage allowed; it is not a provider verdict. A fresh real check through the original adapter, `HARNESS_AGENT_PROVIDER_CHECK=1 ./.agent-harness/scripts/run-evaluator-agent.sh`, returned exit 0 and `agent_provider_runtime_check=ok role=evaluator provider=codex` (/tmp/swipe-F020-provider-recheck.log).
- Resolution: retry the same cold evaluator using existing unchanged coding evidence. No model, credentials, account, provider configuration, test standards or completion state manually changed. No usage reset purchased or consumed by a tool.
- Harness improvement: no source patch justified by a transient provider failure; keep the independent gate and failure evidence. Do not classify missing verdict as a product defect or success.
- Follow-up feature: F020 remains awaiting independent evaluation; F018 device/iCloud remains incomplete.
