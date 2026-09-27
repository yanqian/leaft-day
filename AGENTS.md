# AGENTS.md

This repository uses the AI Agent Harness in hidden layout.

Agents must reconstruct context from repository files and git history, not chat history.

Before planning, coding, evaluating, or resuming work:

1. Read `.agent-harness/progress.md`.
2. Read `.agent-harness/feature_list.json`.
3. Check recent work:

   ```bash
   git log --oneline -20
   ```

4. Run:

   ```bash
   ./init.sh
   ```

Full harness rules live in `.agent-harness/AGENTS.md`.
Project-specific implementation should live in project-owned source and test paths, not in `.agent-harness/` unless the selected feature explicitly changes the harness.

Provider child agents run from the project root. Configure `.agent-harness/agent-provider.json` with provider `cwd` set to `..`, resolved relative to the `.agent-harness/` directory. Do not also use provider-specific directory flags such as Codex `--cd`; runtime preflight and real role execution must share the adapter `cwd`.

Canonical workflow state, docs, scripts, prompts, tests, and run evidence remain under `.agent-harness/`. Legacy root files with the same names are non-canonical and must not be read or modified.

For orchestrator work, the harness Makefile is inside `.agent-harness/`. From the project root, run:

```bash
make -C .agent-harness work
```

Equivalently, run `cd .agent-harness && make work`. Do not treat a missing root `Makefile` as a reason to bypass the orchestrator-first workflow.

Preferred interactive mode:

- For interactive user-led development, default to evaluator-gated fast work from the project root:

  ```bash
  make -C .agent-harness work-fast
  ```

- In this mode, the current agent/provider-native session implements the selected feature after the fast handoff.
- The coding phase must record `FAST_CODING_EVIDENCE: Fxxx` and `CODING_PASS: Fxxx` in `.agent-harness/runs/`.
- The coding phase must not write `EVAL_PASS: Fxxx`, must not mark the feature `passes=true` or `status=done`, and must not treat local tests as evaluator evidence.
- After coding evidence is recorded, rerun `make -C .agent-harness work-fast` so a separate cold-start Evaluator Agent child process can accept or reject the feature.
- Use baseline `make -C .agent-harness work` when the user explicitly asks for the full two-child-process flow, unattended execution, or batch work.

Root `./init.sh` starts as harness verification only. Before a minspec exists, it proves the harness can plan and resume. After minspec acceptance, plan a runnable-skeleton feature that turns root `./init.sh` into the project recovery contract described in `.agent-harness/docs/project-recovery-init.md`.

Spec Normalization rules live in `.agent-harness/docs/spec-normalization.md`. Planning must define goal, included scope, excluded scope, core flows, constraints, ambiguities or assumptions, required capabilities, implementation paths, and verification surface before appending feature entries.
