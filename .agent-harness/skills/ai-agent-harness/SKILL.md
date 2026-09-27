---
name: ai-agent-harness
description: Use when initializing, adopting, repairing, or operating an AI Agent Harness repository; when the user mentions AGENTS.md, feature_list.json, progress.md, resumable AI coding, Planning Agent, Coding Agent, Evaluator Agent, harness workflow, or committing approved harness work. Supports project initialization, new requirement planning, one-feature implementation, evaluation, and explicit finalize-and-commit workflows while keeping repository files as the durable source of truth.
metadata:
  short-description: Initialize and operate an AI agent harness
---

# AI Agent Harness

Use this skill as the convenience layer for the repository-local AI Agent Harness protocol.

The repository remains the source of durable state. Do not store durable project state in the skill, in chat history, or in hidden local memory.

When this skill is installed, prefer natural invocation such as `Use $ai-agent-harness to initialize this project.` Codex installs skills under `~/.codex/skills`, Claude Code supports personal `~/.claude/skills/` and project `.claude/skills/` locations, and Cursor can use `.cursor/rules` as a project-level rule entry point. Manual `python3 .../init_harness.py` commands are for repository checkouts, direct script testing, or agent tools without a skill loader.

## Core Rule

Before planning, coding, evaluating, continuing, or committing harness work in a repository that already has `AGENTS.md`, follow that repository's startup protocol. For this harness, that means:

1. Read `progress.md`.
2. Read `feature_list.json`.
3. Run `git log --oneline -20`.
4. Run `./init.sh`.

If the repository does not have the harness yet, use the initializer script below.

## Initialize Or Repair

Use `scripts/init_harness.py` from this skill.

Modes:

- `new`: install the harness into a new or empty project and scaffold missing project state.
- `adopt`: install missing harness files and scaffold missing project state while preserving existing requirements and history; default mode.
- `repair`: add missing harness files but preserve existing `feature_list.json` and `progress.md`.
- `upgrade`: update an already installed harness to the current template version after the global skill has been updated; preserve project-owned state and root project recovery files unless `--force` is explicitly approved.
- `check`: report missing files, merge-sensitive conflicts, harness-owned drift, project state changes, installed/template versions, semantic validity, runnable status, and next action guidance without writing.

Layouts:

- `hidden`: default for installed projects; root keeps thin `AGENTS.md` and `init.sh` entry points while harness files live under `.agent-harness/`.
- `visible`: template-maintenance layout with harness files at repository root.

Default behavior never overwrites conflicting files. Use `--force` only after the user explicitly approves overwriting conflicts.

The initializer writes `.agent-harness/manifest.json` into installed projects and reads `.agent-harness-template.json` from the template. File categories matter:

- harness-owned static files are hash checked;
- project-owned state is validated semantically after initialization;
- merge-sensitive files are not overwritten by default;
- optional integrations are reported separately from core harness validity.

Examples:

```bash
python3 /path/to/skill/scripts/init_harness.py --root /path/to/project --mode adopt
python3 /path/to/skill/scripts/init_harness.py --root /path/to/project --mode check
python3 /path/to/skill/scripts/init_harness.py --root /path/to/project --mode repair
python3 /path/to/skill/scripts/init_harness.py --root /path/to/project --mode upgrade
```

After updating the global skill, run `check` in existing projects. If `installed_version` is older than `template_version`, run `upgrade` to refresh harness-owned files, installed runtime scripts, prompts, docs, and manifest metadata. Do not use `--force` unless the user explicitly approves overwriting merge-sensitive project files such as root `AGENTS.md` or root `init.sh`.

Fresh installations receive a structured project SPEC with shared-rule references, an empty feature list, and fresh progress. Existing project state is preserved even on repeated new/adopt runs. When the canonical `feature_list.json` is empty, start at F001. Otherwise allocate after the largest existing project feature ID. Never derive numbering from template SPEC, Harness documentation, examples, or another repository. Preserve all existing IDs, state, and evidence.

## Workflows

For planning, one-feature work, evaluation, continuation, and final commit rules, read `references/workflows.md`.

Use the workflow names as intent detectors:

- Initialize Harness
- Plan Requirement
- Work One Feature
- Evaluate Feature
- Continue Harness Work
- Finalize And Commit

When an installed harness reports a missing tool, permission, generator, dependency, service, credential, runtime setting, CI resource, or verification fixture, follow the target repository's `docs/capability-gaps.md`. Do not treat local-only workarounds as durable completion.

When planning new requirements, follow the target repository's `docs/spec-normalization.md` before feature decomposition. Normalize vague user input into explicit goal, included scope, excluded scope, core flows, constraints, ambiguities or assumptions, required capabilities, implementation paths, and verification surface. Do not turn vague requirements directly into feature entries.

When planning broad requirements, follow the target repository's `docs/feature-decomposition.md`. Split independently verifiable behavior, capability, implementation-boundary, risk-domain, and verification-surface work into separate features.

When a project has just been initialized or a minspec has just been accepted, follow the target repository's `docs/project-recovery-init.md`. Treat `.agent-harness/scripts/init.sh` as harness verification and root `./init.sh` as the project recovery entry point. Before a minspec exists, root `./init.sh` may only prove the harness is runnable. After minspec acceptance, plan a runnable-skeleton feature that installs dependencies, starts required services, runs a real endpoint or core-function smoke test, emits clear logs, and exits non-zero on failure.

When completing or evaluating a feature, follow the target repository's `docs/evaluator-evidence.md`. From the enforcement baseline onward, a feature should not be marked done unless `runs/` contains `EVAL_PASS: Fxxx` for that feature.

Human Product Evaluation is an optional, deferred acceptance layer. It may happen after one Feature or after a batch of Features and must not block unrelated Feature work. Record it with `make human-eval` or `make human-eval-batch`; the result belongs in both durable `runs/` evidence and the Feature's `human_acceptance` history. If the original acceptance promise is unmet, classify it as `current_feature` and reopen that same Feature. If it is genuinely new value, classify it as `new_requirement` and hand it to Planning for SPEC normalization and decomposition; do not auto-append a repair Feature. Human Eval does not replace the separate automatic Evaluator `EVAL_PASS` evidence.

When project work touches `examples/`, follow the target repository's `docs/example-boundaries.md`. Default examples are references, not the default place for product requirements.

For one-feature implementation and evaluation, default to the repository's orchestrator-first entrypoint, normally `make work`. In hidden-layout installs, run `make -C .agent-harness work` from the project root, or `make work` from inside `.agent-harness/`; a missing root `Makefile` is not an orchestrator-unavailable condition. Manual or interactive Coding Agent work is an explicit fallback only when role adapters are unavailable or the user asks for manual work; it must not bypass evaluator gating, evaluator evidence, or final `./init.sh` verification.

Use `make work-fast` only as the evaluator-gated fast A/B alternative to `make work`: provider-native coding must record `FAST_CODING_EVIDENCE: Fxxx` and `CODING_PASS: Fxxx`, must not write `EVAL_PASS: Fxxx`, and must rerun the orchestrator so a separate cold-start Evaluator Agent child process gates completion.

When `make work` needs real agent execution, configure the target repository's provider contract from `agent-provider.example.json` using `docs/agent-provider-configuration.md`. Do not guess between Codex, Claude Code, Cursor Agent, or custom providers; missing or ambiguous provider setup is a capability gap.

In hidden layout, configure the project-local provider with `cwd: ".."` relative to `.agent-harness/agent-provider.json`. Runtime preflight and real execution must share that adapter cwd; do not add overlapping provider-specific directory flags. Use the orchestrator's rendered prompts so canonical workflow state, docs, scripts, tests, and runs resolve under `.agent-harness/` while project-owned source and root recovery entry points remain at the provider workspace root.

## Commit Boundary

Only commit after the user explicitly says they are satisfied or asks to commit.

Before committing:

1. Run the harness startup protocol.
2. Run the relevant verification command, normally `./init.sh`.
3. Inspect `git status --short`.
4. Stage only files related to the approved work.
5. Stop and ask if unrelated changes are present.
6. Commit with a subject that follows `docs/commit-messages.md`, normally `Fxxx <Action> <concise summary>`.

Default to commit only. Push or pull request creation requires a separate explicit request.
