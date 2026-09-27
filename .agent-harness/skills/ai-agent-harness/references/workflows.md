# AI Agent Harness Workflows

These workflows operate the repository-local harness. They are intentionally vendor-neutral; Codex, Claude Code, Cursor Agent, and other coding agents can follow the same file protocol.

If the skill is installed in an agent surface, invoke it by name, for example `Use $ai-agent-harness to initialize this project.` Codex uses `~/.codex/skills`, Claude Code supports `~/.claude/skills` and project `.claude/skills`, and Cursor can use `.cursor/rules` for a project-level rule. Manual `python3 skills/ai-agent-harness/scripts/init_harness.py` usage is for repository checkouts and tools without a skill loader.

## Initialize Harness

Use when the target project lacks harness files or the user asks to install, adopt, repair, upgrade, or check the harness.

1. Run `scripts/init_harness.py --mode check --root <project>` when the user only wants inspection.
2. Run `scripts/init_harness.py --mode adopt --layout hidden --root <project>` for an existing project unless the user asks for visible layout.
3. Run `scripts/init_harness.py --mode new --layout hidden --root <project>` for a new project unless the user asks for visible layout.
4. Run `scripts/init_harness.py --mode repair --root <project>` for an existing harness with missing files.
5. After updating the global skill, run `scripts/init_harness.py --mode check --root <project>` in existing installed projects; when `installed_version` is older than `template_version`, run `scripts/init_harness.py --mode upgrade --root <project>`.
6. Do not use `--force` unless the user explicitly approved overwriting conflicts.
7. After initialization, repair, or upgrade, run `<project>/init.sh` if present.

`new` and `adopt` scaffold only missing project state: a structured project `SPEC.md` referencing shared rules, an empty `feature_list.json`, and fresh `progress.md`. Existing project state is preserved, including on repeated calls and with `--force`. Template product requirements and run history are not imported. `repair` preserves existing project state and restores missing state from fresh scaffolds. `upgrade` leaves missing state for explicit repair. `upgrade` preserves project-owned state while updating harness-owned static files, installed runtime files, prompts, docs, template metadata, and the installation manifest.

Installed projects record `.agent-harness/manifest.json`. The template records `.agent-harness-template.json`. Use `check` before repair or upgrade decisions: it reports installed layout, installed version, template version, missing files, merge-sensitive conflicts, harness-owned drift, project-owned state changes, semantic validity, runnable status, and next action guidance.

In hidden layout, root `AGENTS.md` and root `init.sh` are project merge-sensitive entry points. Do not overwrite them during upgrade unless the user explicitly approves `--force`, especially after a minspec has turned root `./init.sh` into the project recovery contract. The project-local `.agent-harness/` runtime files are harness-owned and should be updated by `upgrade`.

Hidden-layout provider children should use `cwd: ".."` relative to `.agent-harness/agent-provider.json`. The adapter uses the same resolved project-root workspace for runtime preflight and real execution. Do not combine this with provider-specific directory flags. Rendered role prompts map logical harness paths to `.agent-harness/` and must ignore stale same-named root workflow files.

`hidden` layout is the default for user projects: root keeps thin `AGENTS.md` and `init.sh` entry points while the harness body lives under `.agent-harness/`. `visible` layout is for harness development and direct template inspection.

A project is an installed harness when `./init.sh` succeeds, the installed layout's `feature_list.json` is valid, `progress.md` contains recovery sections, `AGENTS.md` contains the startup and safety rules, prompts and scripts are present, run templates are available, and `check` reports `runnable_harness=true`.

In hidden layout, root `./init.sh` starts as harness verification only. Before a project minspec exists, that is enough to prove a recoverable planning environment. After minspec acceptance, use `docs/project-recovery-init.md` to plan a runnable-skeleton feature that makes root `./init.sh` install dependencies, start required services, run a real endpoint or core-function smoke test, print clear logs, avoid manual steps and TODO placeholders, and exit non-zero on failure.

From the evaluator-evidence baseline onward, `./init.sh` also verifies that completed features have matching `EVAL_PASS: Fxxx` run evidence.

## Human Evaluation

Human Eval is optional and may be deferred until several Features are complete. It is product acceptance evidence, not an orchestration gate, and must not block unrelated Feature work. Record one result with `make human-eval` or a mixed batch with `make human-eval-batch`; both write durable run evidence and update the Feature's `human_acceptance` history.

Classify every result explicitly. `current_feature` means the original Feature promise is still unmet: reopen that same Feature and continue its lifecycle, preserving attempts, history, and unknown fields. `new_requirement` means independent new value: leave the original Feature complete and create a Planning Agent handoff. Planning must perform SPEC normalization in `SPEC.md` and decompose the request before appending a new Feature. Human Eval evidence does not replace the automatic Evaluator `EVAL_PASS: Fxxx` evidence.

## Project SPEC handoff

When the canonical `feature_list.json` is empty, start at F001. Otherwise allocate after the largest existing project feature ID. Never derive numbering from template SPEC, Harness documentation, examples, or another repository. Preserve all existing IDs, state, and evidence.

The template repository retains its own SPEC and feature history. Installed project SPEC reuses the normalization structure and links to AGENTS.md, docs/, and QUALITY.md, then describes only the target product. Preserve existing source documents as planning inputs; do not replace an existing project SPEC automatically. Legacy contaminated projects require a separate reviewed migration, not renumbering during upgrade.

## Plan Requirement

Use when the user describes new work before implementation.

1. Follow the repository startup protocol.
2. Read `AGENTS.md`, `SPEC.md`, `feature_list.json`, and `progress.md`. For direct prompt use, render the Planning role with `python3 orchestrator.py --render-prompt plan` so hidden-layout paths resolve under `.agent-harness/`.
3. Use `docs/spec-normalization.md` to append a normalized SPEC entry with goal, included scope, excluded scope, core flows, constraints, ambiguities or assumptions, required capabilities, implementation paths, and verification surface.
4. Reject vague requirements instead of turning them directly into feature entries; ask for clarification, record assumptions, or create capability, blocker, or follow-up work when needed.
5. Use `docs/feature-decomposition.md` to split broad requirements into independently verifiable feature entries.
6. Use `docs/project-recovery-init.md` when planning a fresh project, accepted minspec, runnable skeleton, or root `./init.sh` change.
7. Identify required capabilities, including tools, permissions, generators, dependencies, services, credentials, runtime settings, CI resources, and verification fixtures.
8. Identify project-owned implementation and verification paths; use `examples/` only when the requirement explicitly targets example maintenance.
9. Append new feature entries to `feature_list.json`, including explicit capability features when needed.
10. Preserve feature IDs, ordering, status, attempts, errors, and unknown fields.
11. Do not implement business logic during planning.
12. Run `./init.sh`.

## Work One Feature

Use when the user asks to implement, continue, or work on a harness feature.

1. Follow the repository startup protocol.
2. Default to orchestrator-first work:

   ```bash
   make work
   ```

   In hidden-layout installs, run this from the project root instead:

   ```bash
   make -C .agent-harness work
   ```

   You can also `cd .agent-harness && make work`. Do not treat a missing root `Makefile` as a fail-closed adapter setup gap.
3. Let the orchestrator select one unfinished feature, mark it `in_progress`, increment attempts, run Coding Agent and Evaluator Agent adapters, and mark done only after evaluator pass.
4. Use `make work-fast` only as the fast A/B alternative: it skips the Coding Agent role adapter, records provider-native coding evidence with `FAST_CODING_EVIDENCE: Fxxx`, and still requires a separate cold-start Evaluator Agent child process before completion.
5. Configure `agent-provider.json` from `agent-provider.example.json` using `docs/agent-provider-configuration.md` before real provider execution.
6. If adapters or providers are missing, unavailable, ambiguous, or still unconfigured, treat that as a fail-closed adapter setup gap. Do not silently hand-edit feature completion.
7. Use manual or interactive Coding Agent work only as an explicit fallback when adapters are not configured or the user asks for manual work.
8. For manual fallback, select exactly one feature, implement only that feature, preserve unrelated working-tree changes, update `progress.md`, and update only the selected feature in `feature_list.json`.
9. Manual fallback must record that it was a fallback in `progress.md` or `runs/` and must not bypass evaluator pass, evaluator evidence, attempts, failure records, or final `./init.sh` verification.
10. Record a run note in `runs/` for non-trivial work, external behavior verification, failures, or evaluator handoff.
11. When a required capability is missing, follow `docs/capability-gaps.md`; make the capability durable, block the feature, or create follow-up work instead of relying on local-only workarounds.
12. When implementation touches `examples/`, follow `docs/example-boundaries.md`; do not use default examples as the product implementation surface.
13. Run `./init.sh` after changes.
14. Do not stage or commit during orchestrated Coding Agent work.

## Evaluate Feature

Use when the user asks whether a feature is complete or asks for evaluation.

1. Follow the repository startup protocol.
2. Inspect the selected feature's implementation.
3. Verify acceptance criteria in `feature_list.json`.
4. Apply `QUALITY.md`.
5. Check relevant run evidence in `runs/`.
6. Check `docs/evaluator-evidence.md` and record `EVAL_PASS: Fxxx` in `runs/` before completion.
7. Check `docs/feature-decomposition.md` and reject over-bundled features that should have been split into independently verifiable entries.
8. Check `docs/capability-gaps.md` and reject missing required capabilities that were bypassed instead of made durable or tracked.
9. Check `docs/example-boundaries.md` and reject project-level work implemented by repurposing default examples.
10. Do not implement new features.
11. Output exactly `EVAL_PASS: Fxxx` or `EVAL_FAIL: Fxxx: <reason>` when acting as an Evaluator Agent.

## Continue Harness Work

Use after interruption or when the user asks to resume.

1. Reconstruct context from repository files and git history only.
2. Read `progress.md`, `feature_list.json`, `AGENTS.md`, and recent commits.
3. Run `./init.sh`.
4. Identify the next safe action from repository state.
5. Continue implementation or evaluation through `make work` first, using `make -C .agent-harness work` from the project root in hidden-layout installs.
6. Use manual continuation only as an explicit fallback when adapters are unavailable or the user asks for interactive/manual work.
7. Inspect `docs/capability-gaps.md` when prior work used local-only workarounds for missing capabilities.
8. Inspect `docs/example-boundaries.md` when prior work modified `examples/`.
9. Stop and report exact conflicts if state is unsafe.

## Finalize And Commit

Use only when the user explicitly says they are satisfied or asks to commit.

1. Follow the repository startup protocol.
2. Run relevant verification, normally `./init.sh`.
3. Inspect `git status --short`.
4. Identify files changed by the approved work.
5. If unrelated changes are present, ask the user before staging.
6. Stage only approved files.
7. Read `docs/commit-messages.md`.
8. Commit feature work with a subject that starts with the feature ID, normally `Fxxx <Action> <concise summary>`.
9. Verify every feature ID referenced in the commit subject exists in `feature_list.json`.
10. Use `No-feature: <summary>` only for explicitly non-feature work.
11. Default to no push. Push or pull request creation requires a separate explicit request.

Never commit merely because implementation finished. The commit boundary is user satisfaction.
