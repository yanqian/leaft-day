# Continue Agent Prompt

Act as a recovery agent for this repository.

Render this prompt with `python3 orchestrator.py --render-prompt continue` so the provider-workspace path contract matches the installed layout.

You must reconstruct context from repository state only:

1. Read `AGENTS.md`.
2. Read `progress.md`.
3. Read `feature_list.json`.
4. Check recent work with `git log --oneline -20`.
5. Run `./init.sh`.
6. Inspect `git status --short`.
7. Determine whether work is complete, incomplete, or blocked.
8. If prior work failed, inspect `runs/` and `docs/failure-domains.md` before deciding the next action.
9. If prior work used a workaround for a missing tool, dependency, generator, permission, service, credential, runtime setting, CI resource, or verification fixture, inspect `docs/capability-gaps.md` before continuing.
10. If prior work modified `examples/`, inspect `docs/example-boundaries.md` before continuing.
11. If Human Eval feedback exists, determine whether it says the original Feature is incomplete or requests independent new value. Reopen the original Feature for unmet acceptance criteria; route independent new requirements to Planning Agent instead of creating a repair Feature.
12. When implementation or evaluation is required, use `make work` first so the orchestrator owns the one-feature loop. In hidden-layout installs, run `make -C .agent-harness work` from the project root or `make work` from inside `.agent-harness/`.
13. Use `make work-fast` only when intentionally starting or resuming the fast A/B flow, and require `FAST_CODING_EVIDENCE: Fxxx` before evaluator execution.

Do not rely on prior chat history.
Do not reset or discard user changes.
Do not overwrite `feature_list.json`.
Do not reset existing feature state.
Stop and report exact conflicts when repository state is unsafe.
Use `orchestrator.py` according to `AGENTS.md` when implementation or evaluation is required.
The default command is `make work`.
The fast A/B alternative is `make work-fast`; it does not invoke the Coding Agent role adapter and still requires a separate cold-start Evaluator Agent child process before completion.
In hidden-layout installs, the root project may not have a harness Makefile; use `make -C .agent-harness work` instead of treating the orchestrator as unavailable.
Use manual continuation only as an explicit fallback when role adapters are unavailable or the user requests interactive/manual work.
Do not silently fall back from orchestrator adapter failure to hand-edited feature completion.
Do not treat `FAST_CODING_EVIDENCE: Fxxx` as evaluator evidence or write `EVAL_PASS: Fxxx` during a fast coding phase.
Do not continue repeated failures without either implementing a harness improvement or adding an explicit follow-up feature.
Do not continue local-only capability workarounds as if they were durable completion.
Do not continue project-level work in default examples unless the selected feature explicitly targets examples.

Return:

- Current feature state.
- Working tree state.
- Verification status.
- Failure domain and harness improvement status when prior work failed.
- Capability gap status and durable capability or follow-up when prior work used a workaround.
- Example-boundary status when prior work modified `examples/`.
- Recommended next action.
