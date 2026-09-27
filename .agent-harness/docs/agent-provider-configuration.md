# Agent Provider Configuration

The orchestrator is the default work entrypoint, but it remains vendor-neutral. Real agent execution requires an explicit provider configuration.

## Contract

Copy `agent-provider.example.json` to `agent-provider.json` and set one provider:

```json
{
  "provider": "codex",
  "providers": {
    "codex": {
      "cwd": ".",
      "command": ["codex", "exec", "--model", "gpt-5.4", "-"],
      "runtime_check_command": ["codex", "exec", "--model", "gpt-5.4", "--ephemeral", "-"],
      "verified": "2026-07-13: Codex CLI reads the harness-supplied prompt from stdin when - is used. The project-local model override prevents an unavailable global model setting from breaking provider startup."
    }
  }
}
```

`agent-provider.json` is intentionally not committed by default because provider choice is local to a project or team. Commit it only when the team wants the same provider contract everywhere.

Rules:

- `provider` must be explicit. Do not use `auto`.
- `providers.<name>.command` must be a non-empty JSON array of strings.
- Optional `coding_command` and `evaluator_command` may override `command` for one role.
- Optional `runtime_check_command` verifies that the configured provider can actually start before the orchestrator mutates feature state.
- Optional `coding_runtime_check_command` and `evaluator_runtime_check_command` may override `runtime_check_command` for one role.
- Optional `cwd` sets the provider workspace. It is resolved relative to the directory containing `agent-provider.json`, not relative to the caller's shell directory.
- Runtime preflight and real role execution always use the same resolved `cwd`.
- Do not combine adapter `cwd` with a provider-specific directory switch such as Codex `--cd`; overlapping workspace controls are outside the portable contract.
- Optional `env` adds string environment variables.
- Commands run without a shell; shell snippets, pipes, and implicit expansion are not part of the contract.

## Failure Behavior

The adapters fail closed when:

- `agent-provider.json` is missing.
- Multiple known provider CLIs are detected but no provider is selected.
- The configured provider is missing from `providers`.
- The configured command is empty.
- The configured executable is not available.
- A configured runtime check command fails.
- A configured runtime check command reports a permission error such as `Operation not permitted`, `Permission denied`, provider state-file access failure, or app-server access failure.
- Provider JSON is invalid.

The orchestrator preflights provider configuration before marking a feature `in_progress`, so missing provider setup does not silently mutate feature state.

When runtime preflight detects a provider permission problem, the adapter emits a machine-readable marker:

```text
PROVIDER_RUNTIME_PERMISSION_REQUIRED: provider=<name> role=<coding|evaluator> ...
```

The harness does not automatically escalate permissions. The outer agent or user must explicitly approve escalated provider runtime execution before retrying. This keeps provider access to user-level state directories, credentials, app-server sockets, or similar resources visible and intentional.

## Provider Notes

Codex:

- Verified locally on 2026-07-13 with `codex exec --help` and a real evaluator preflight.
- `codex exec -` reads instructions from stdin.
- `codex exec --help` documents `--ephemeral` for runs without persisted session files.
- The harness supplies both role prompts and runtime-check prompts on stdin, so provider commands must use `-` and must not also include a prompt argument. Mixing an argv prompt with harness-supplied stdin can make Codex print `Reading additional input from stdin...` and exit unsuccessfully.
- The sample command is `["codex", "exec", "--model", "gpt-5.4", "-"]`.
- The sample runtime check command is `["codex", "exec", "--model", "gpt-5.4", "--ephemeral", "-"]`.
- The explicit model is a project-local known-good default. If it is unavailable in the installed CLI/account, replace it with a locally verified model instead of inheriting an unknown global model setting.
- If Codex cannot access `$CODEX_HOME` state such as `~/.codex/state_5.sqlite` or app-server resources, treat it as a provider runtime permission gap and ask the user to approve escalated execution.

Claude Code:

- Do not copy the Codex command shape.
- Verify the local Claude Code CLI help or official documentation before configuring `command` or `runtime_check_command`.
- Record the verified stdin, stdout, stderr, and exit-code behavior in `verified`.

Cursor Agent:

- Do not copy the Codex command shape.
- Verify the local Cursor Agent CLI help or official documentation before configuring `command` or `runtime_check_command`.
- Record the verified stdin, stdout, stderr, and exit-code behavior in `verified`.

Custom providers:

- Use a wrapper script when the provider needs flags, environment, credentials, or output normalization.
- The wrapper must accept the full role prompt on stdin and exit non-zero on failure.
- Add `runtime_check_command` when the provider needs user-level state, credentials, sockets, app servers, or external runtime access that may be denied by the current sandbox.
- If coding output is normalized, preserve the final `CODING_PASS: Fxxx` or `CODING_FAIL: Fxxx: <reason>` line when present.
- If evaluator output is normalized, preserve the final `EVAL_PASS: Fxxx` or `EVAL_FAIL: Fxxx: <reason>` line.
- The orchestrator uses the last matching role verdict for a feature so historical run evidence echoed in provider output cannot override the final role decision.
- If a provider exits non-zero after a final `CODING_PASS` or `EVAL_PASS`, the orchestrator treats the final structured verdict as authoritative and logs the provider exit-code contradiction.

## Commands

Preflight the configured provider:

```bash
HARNESS_AGENT_PROVIDER_CHECK=1 scripts/run-coding-agent.sh
HARNESS_AGENT_PROVIDER_CHECK=1 scripts/run-evaluator-agent.sh
```

Run one orchestrator round:

```bash
make work
```

From a hidden-layout project root, use `make -C .agent-harness work` because the provider config and harness Makefile live under `.agent-harness/`.

For a hidden-layout install, set `cwd` to `".."` in `.agent-harness/agent-provider.json`. The adapter resolves it from `.agent-harness/`, so the provider runs at the project root while rendered role prompts map canonical harness state to `.agent-harness/feature_list.json`, `.agent-harness/progress.md`, `.agent-harness/runs/`, and the other harness-owned paths. Root files with those names are legacy/non-canonical. Visible-layout repositories use `cwd: "."` and keep canonical harness paths at the repository root.

Render Planning or Continue prompts explicitly when using those manual role surfaces:

```bash
python3 orchestrator.py --render-prompt plan
python3 orchestrator.py --render-prompt continue
```

Preview without requiring a provider:

```bash
make dry-run
```
