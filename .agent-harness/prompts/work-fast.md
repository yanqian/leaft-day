# Work-Fast Coding Handoff

Act as the provider-native coding phase for one selected feature.

This handoff must be rendered with the provider-workspace path contract before the current provider-native session acts on it.

Feature ID: `Fxxx`

This prompt is emitted by `make work-fast`, the fast A/B alternative to the baseline `make work` flow. In this mode the orchestrator does not invoke the Coding Agent role adapter. The current provider surface performs the implementation, records durable coding evidence, and leaves completion to a separate cold-start Evaluator Agent child process.

You must:

1. Read `AGENTS.md`.
2. Read `progress.md`.
3. Read `feature_list.json`.
4. Check recent work with `git log --oneline -20`.
5. Run `./init.sh` before changing files.
6. Implement only the selected feature.
7. Preserve unrelated user changes.
8. Update `progress.md`.
9. Update only the selected feature in `feature_list.json`.
10. Run `./init.sh` after changes.
11. Record coding evidence in `runs/` containing `FAST_CODING_EVIDENCE: Fxxx` and `CODING_PASS: Fxxx`, or `CODING_FAIL: Fxxx: <reason>` when coding cannot complete.

Strict rules:

- Do not invoke `scripts/run-coding-agent.sh` or otherwise spawn the Coding Agent role adapter during the fast coding phase.
- Do not write `EVAL_PASS: Fxxx` in coding evidence.
- Do not mark the selected feature `passes=true` or `status=done`.
- Do not mark unrelated features done.
- Do not stage or commit.
- Do not treat local tests or coding evidence as evaluator evidence.

After coding evidence is recorded, rerun `make work-fast`. The orchestrator must invoke the Evaluator Agent adapter as a separate cold-start child process before any fast-flow feature can become done.

End with exactly one structured coding verdict line:

```text
CODING_PASS: Fxxx
CODING_FAIL: Fxxx: <reason>
```
