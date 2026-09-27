#!/usr/bin/env python3
import argparse
from datetime import datetime, timezone
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

FEATURES_PATH = Path("feature_list.json")
PROGRESS_PATH = Path("progress.md")
PROMPTS_DIR = Path("prompts")
RUNS_DIR = Path("runs")
CODING_AGENT_ADAPTER = Path("scripts/run-coding-agent.sh")
EVALUATOR_AGENT_ADAPTER = Path("scripts/run-evaluator-agent.sh")
INSTALL_MANIFEST_PATH = Path("manifest.json")
MAX_ROUNDS = 1
MAX_ATTEMPTS = 3
FAST_CODING_EVIDENCE_PREFIX = "FAST_CODING_EVIDENCE:"
FAST_CODING_HANDOFF_PREFIX = "FAST_CODING_HANDOFF:"


class OrchestratorError(Exception):
    pass


def sh(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, text=True, check=check)


def run_capture(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, text=True, capture_output=True, check=check)


def load_state() -> dict:
    data = json.loads(FEATURES_PATH.read_text())
    if not isinstance(data, dict) or not isinstance(data.get("features"), list):
        raise OrchestratorError("feature_list.json must contain a top-level features array.")
    return data


def save_state(data: dict) -> None:
    FEATURES_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def features(data: dict) -> list[dict]:
    return data["features"]


def feature_by_id(data: dict, feature_id: str) -> dict:
    for feature in features(data):
        if feature.get("id") == feature_id:
            return feature
    raise OrchestratorError(f"Feature not found: {feature_id}")


def normalize_status(feature: dict) -> str:
    status = feature.get("status", "todo")
    if feature.get("passes") is True:
        return "done"
    if status == "done":
        return "todo"
    return status


def pick_feature(data: dict, max_attempts: int) -> Optional[dict]:
    priority = {"P0": 0, "P1": 1, "P2": 2}
    candidates = []
    ordered_features = features(data)
    for feature in ordered_features:
        attempts = int(feature.get("attempts", 0))
        status = normalize_status(feature)
        acceptance = feature.get("human_acceptance", {})
        reopened = isinstance(acceptance, dict) and acceptance.get("reopen_pending") is True
        if feature.get("passes") is False and status in {"todo", "in_progress"} and (attempts < max_attempts or reopened):
            candidates.append(feature)
    candidates.sort(key=lambda item: (priority.get(item.get("priority", "P2"), 9), ordered_features.index(item)))
    return candidates[0] if candidates else None


def pick_fast_feature(data: dict, max_attempts: int) -> Optional[dict]:
    priority = {"P0": 0, "P1": 1, "P2": 2}
    ordered_features = features(data)
    in_progress = [
        feature
        for feature in ordered_features
        if feature.get("passes") is False and normalize_status(feature) == "in_progress"
    ]
    if in_progress:
        in_progress.sort(key=lambda item: (priority.get(item.get("priority", "P2"), 9), ordered_features.index(item)))
        return in_progress[0]
    return pick_feature(data, max_attempts)


def mark_in_progress(feature_id: str) -> None:
    data = load_state()
    feature = feature_by_id(data, feature_id)
    feature["status"] = "in_progress"
    feature["attempts"] = int(feature.get("attempts", 0)) + 1
    feature["last_error"] = ""
    acceptance = feature.get("human_acceptance")
    if isinstance(acceptance, dict):
        acceptance["reopen_pending"] = False
    save_state(data)


def mark_done(feature_id: str) -> None:
    data = load_state()
    feature = feature_by_id(data, feature_id)
    feature["passes"] = True
    feature["status"] = "done"
    feature["last_error"] = ""
    save_state(data)


def mark_failed(feature_id: str, error: str, max_attempts: int) -> None:
    data = load_state()
    feature = feature_by_id(data, feature_id)
    attempts = int(feature.get("attempts", 0))
    feature["passes"] = False
    feature["status"] = "blocked" if attempts >= max_attempts else "todo"
    feature["last_error"] = error.strip()[:2000]
    save_state(data)


def write_failure_run_record(
    feature_id: str,
    failure_summary: str,
    *,
    command: str = "python3 orchestrator.py",
    failure_domain: str = "agent_workflow_gap",
    harness_improvement: str = "No new harness improvement required; the orchestrator recorded this failure and kept the feature non-done.",
) -> None:
    RUNS_DIR.mkdir(exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    safe_feature = re.sub(r"[^A-Za-z0-9_-]+", "-", feature_id)
    path = RUNS_DIR / f"{timestamp}-{safe_feature}-failure.md"
    current_commit = run_capture(["git", "rev-parse", "--short", "HEAD"], check=False).stdout.strip() or "unknown"
    status = run_capture(["git", "status", "--short"], check=False).stdout.strip() or "clean"
    path.write_text(
        f"# Run Record: {feature_id} - orchestrator failure\n\n"
        "## Summary\n\n"
        f"- Date: {timestamp}\n"
        "- Agent role: Orchestrator\n"
        f"- Feature: {feature_id}\n"
        "- Result: fail\n\n"
        "## Repository State\n\n"
        f"- Starting commit: {current_commit}\n"
        f"- Ending commit: {current_commit}\n"
        f"- Working tree status: {status}\n\n"
        "## Commands Run\n\n"
        "```bash\n"
        f"{command}\n"
        "```\n\n"
        "## Evidence\n\n"
        "- Tests:\n"
        f"- Logs: {failure_summary.strip()[:1000]}\n"
        "- Screenshots or traces:\n"
        "- External behavior verification:\n\n"
        "## Failure Analysis\n\n"
        f"- Failure domain: {failure_domain}\n"
        f"- Failure summary: {failure_summary.strip()[:1000]}\n"
        f"- Harness improvement: {harness_improvement}\n"
        "- Follow-up feature:\n\n"
        "## Files Changed\n\n"
        "- `feature_list.json`\n\n"
        "## Evaluator Result\n\n"
        "```text\n"
        f"EVAL_FAIL: {feature_id}: {failure_summary.strip()[:1000]}\n"
        "```\n\n"
        "## Follow-Up\n\n"
        "- Classify the failure domain and assess harness improvement before the next retry.\n"
    )
    print(f"Wrote failure run record: {path}", flush=True)


def startup_protocol() -> None:
    if not PROGRESS_PATH.exists():
        raise OrchestratorError("progress.md is missing.")
    if not FEATURES_PATH.exists():
        raise OrchestratorError("feature_list.json is missing.")
    print("Reading progress.md and feature_list.json.", flush=True)
    PROGRESS_PATH.read_text()
    load_state()
    history = subprocess.run(["git", "log", "--oneline", "-20"], text=True, capture_output=True)
    if history.returncode == 0:
        print(history.stdout, end="", flush=True)
    else:
        # A freshly initialized repository has a symbolic HEAD but no branch ref.
        branch = subprocess.run(["git", "symbolic-ref", "-q", "HEAD"], text=True, capture_output=True)
        unborn = False
        if branch.returncode == 0:
            ref = subprocess.run(["git", "show-ref", "--verify", "--quiet", branch.stdout.strip()])
            unborn = ref.returncode == 1
        if not unborn:
            raise OrchestratorError(f"Cannot read Git history: {history.stderr.strip()}")
        print("Git repository has no commits yet; continuing initialization checks.", flush=True)
    sh(["./init.sh"])


def harness_layout() -> str:
    if INSTALL_MANIFEST_PATH.exists():
        try:
            manifest = json.loads(INSTALL_MANIFEST_PATH.read_text())
        except json.JSONDecodeError:
            manifest = {}
        if manifest.get("layout") in {"hidden", "visible"}:
            return str(manifest["layout"])
    if Path.cwd().name == ".agent-harness":
        return "hidden"
    return "visible"


def provider_workspace_path_contract(layout: Optional[str] = None) -> str:
    selected_layout = layout or harness_layout()
    if selected_layout not in {"hidden", "visible"}:
        raise OrchestratorError(f"Unsupported harness layout: {selected_layout}")
    prefix = ".agent-harness/" if selected_layout == "hidden" else ""
    mappings = [
        ("SPEC.md", f"{prefix}SPEC.md"),
        ("feature_list.json", f"{prefix}feature_list.json"),
        ("progress.md", f"{prefix}progress.md"),
        ("QUALITY.md", f"{prefix}QUALITY.md"),
        ("test_plan.md", f"{prefix}test_plan.md"),
        ("runs/", f"{prefix}runs/"),
        ("docs/", f"{prefix}docs/"),
        ("prompts/", f"{prefix}prompts/"),
        ("scripts/", f"{prefix}scripts/"),
        ("test/", f"{prefix}test/"),
    ]
    lines = [
        "# Provider Workspace Path Contract",
        "",
        f"Harness layout: `{selected_layout}`.",
        "All paths below are relative to the provider workspace selected by `agent-provider.json` `cwd`.",
    ]
    if selected_layout == "hidden":
        lines.extend([
            "The provider workspace is the project root; provider `cwd` is normally `..` relative to `.agent-harness/`.",
            "Root files with the same names as harness state are legacy/non-canonical and must not be read or modified.",
        ])
    else:
        lines.append("The provider workspace and harness root are the repository root; provider `cwd` is normally `.`.")
    lines.extend(["", "Canonical harness paths:"])
    lines.extend(f"- `{logical}` -> `{canonical}`" for logical, canonical in mappings)
    lines.extend([
        "",
        "Project-owned source, root `AGENTS.md`, and root `./init.sh` remain relative to the provider workspace.",
        "Treat later bare harness paths in this role prompt as logical names resolved through this mapping.",
    ])
    return "\n".join(lines)


def prompt_template(name: str, layout: Optional[str] = None) -> str:
    path = PROMPTS_DIR / name
    if not path.exists():
        raise OrchestratorError(f"Missing prompt template: {path}")
    return f"{provider_workspace_path_contract(layout)}\n\n{path.read_text()}"


def coding_prompt(feature_id: str) -> str:
    return f"{prompt_template('work.md')}\n\nSelected feature ID: `{feature_id}`\n"


def fast_coding_prompt(feature_id: str) -> str:
    return f"{prompt_template('work-fast.md')}\n\nSelected feature ID: `{feature_id}`\n"


def evaluator_prompt(feature_id: str) -> str:
    return f"{prompt_template('evaluate.md')}\n\nSelected feature ID: `{feature_id}`\n"


def ensure_adapter_configured(label: str, adapter_path: Path) -> None:
    if not adapter_path.exists():
        raise OrchestratorError(
            f"{label} adapter is missing: {adapter_path}. "
            "Configure the role adapter before running orchestrator work, or explicitly use the documented manual fallback."
        )
    if not adapter_path.is_file():
        raise OrchestratorError(f"{label} adapter is not a file: {adapter_path}")
    if (adapter_path.stat().st_mode & 0o111) == 0:
        raise OrchestratorError(
            f"{label} adapter is not executable: {adapter_path}. "
            "Run chmod +x after configuring the adapter."
        )
    marker = "is a template adapter."
    try:
        adapter_text = adapter_path.read_text()
    except UnicodeDecodeError:
        adapter_text = ""
    if marker in adapter_text:
        raise OrchestratorError(
            f"{label} adapter is still the template adapter: {adapter_path}. "
            "The default work entrypoint is orchestrator-first, but real work requires configured Coding Agent "
            "and Evaluator Agent adapters. Configure an agent provider, or explicitly use the manual fallback "
            "without bypassing evaluator pass evidence or final ./init.sh verification."
        )
    if "run-agent-provider.py" in adapter_text:
        env = os.environ.copy()
        env["HARNESS_AGENT_PROVIDER_CHECK"] = "1"
        result = subprocess.run([str(adapter_path)], text=True, capture_output=True, env=env)
        if result.returncode != 0:
            detail = "\n".join(part.strip() for part in [result.stdout, result.stderr] if part.strip())
            raise OrchestratorError(
                f"{label} provider is not configured for orchestrator-first work. "
                f"{detail or f'{adapter_path} exited with code {result.returncode}'}"
            )


def run_agent(prompt: str, dry_run: bool, label: str, adapter_path: Path) -> subprocess.CompletedProcess[str]:
    if dry_run:
        print(f"\n== {label} prompt ==")
        print(prompt)
        return subprocess.CompletedProcess(["dry-run"], 0, stdout="", stderr="")
    ensure_adapter_configured(label, adapter_path)
    result = subprocess.run([str(adapter_path)], input=prompt, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout, end="", flush=True)
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr, flush=True)
    return result


def role_output(result: subprocess.CompletedProcess[str]) -> str:
    return "\n".join(part for part in [result.stdout, result.stderr] if part)


def final_role_verdict(output: str, pass_line: str, fail_prefix: str) -> tuple[Optional[bool], str]:
    verdict: tuple[Optional[bool], str] = (None, "")
    for line in output.splitlines():
        stripped = line.strip()
        if stripped == pass_line:
            verdict = (True, "")
        elif stripped.startswith(fail_prefix):
            verdict = (False, stripped[len(fail_prefix):].strip() or "Role reported failure.")
    return verdict


def evaluator_result(feature_id: str, result: subprocess.CompletedProcess[str]) -> tuple[bool, str]:
    output = role_output(result)
    pass_line = f"EVAL_PASS: {feature_id}"
    fail_prefix = f"EVAL_FAIL: {feature_id}:"
    passed, reason = final_role_verdict(output, pass_line, fail_prefix)
    if passed is not None:
        if passed:
            return True, ""
        return False, reason or "Evaluator reported failure."
    return False, f"Evaluator did not emit required pass line: {pass_line}"


def coding_result(feature_id: str, result: subprocess.CompletedProcess[str]) -> tuple[Optional[bool], str]:
    output = role_output(result)
    pass_line = f"CODING_PASS: {feature_id}"
    fail_prefix = f"CODING_FAIL: {feature_id}:"
    return final_role_verdict(output, pass_line, fail_prefix)


def fast_coding_evidence_result(feature_id: str) -> tuple[Optional[bool], str]:
    """Return the final fast-coding verdict from durable run evidence."""
    verdict: tuple[Optional[bool], str] = (None, "")
    if not RUNS_DIR.exists():
        return verdict

    marker = re.compile(rf"^\s*{re.escape(FAST_CODING_EVIDENCE_PREFIX)}\s+{re.escape(feature_id)}\s*$", re.MULTILINE)
    eval_pass = re.compile(rf"^\s*EVAL_PASS:\s+{re.escape(feature_id)}\s*$", re.MULTILINE)
    coding_pass = f"CODING_PASS: {feature_id}"
    coding_fail_prefix = f"CODING_FAIL: {feature_id}:"
    for path in sorted(RUNS_DIR.glob("*.md")):
        if path.name == "RUN_TEMPLATE.md":
            continue
        text = path.read_text(errors="replace")
        if f"{FAST_CODING_HANDOFF_PREFIX} {feature_id}" in text:
            continue
        if not marker.search(text):
            continue
        if eval_pass.search(text):
            return (
                False,
                f"fast coding evidence must not contain evaluator pass evidence: {path}",
            )
        passed, reason = final_role_verdict(text, coding_pass, coding_fail_prefix)
        if passed is not None:
            verdict = (passed, reason)
    return verdict


def write_fast_coding_handoff(feature_id: str) -> Path:
    RUNS_DIR.mkdir(exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    safe_feature = re.sub(r"[^A-Za-z0-9_-]+", "-", feature_id)
    path = RUNS_DIR / f"{timestamp}-{safe_feature}-work-fast-handoff.md"
    current_commit = run_capture(["git", "rev-parse", "--short", "HEAD"], check=False).stdout.strip() or "unknown"
    status = run_capture(["git", "status", "--short"], check=False).stdout.strip() or "clean"
    path.write_text(
        f"# Run Record: {feature_id} - work-fast coding handoff\n\n"
        "## Summary\n\n"
        f"- Date: {timestamp}\n"
        "- Agent role: Orchestrator fast handoff\n"
        f"- Feature: {feature_id}\n"
        "- Result: in_progress\n\n"
        "## Repository State\n\n"
        f"- Starting commit: {current_commit}\n"
        f"- Ending commit: {current_commit}\n"
        f"- Working tree status: {status}\n\n"
        "## Commands Run\n\n"
        "```bash\n"
        "python3 orchestrator.py --work-fast\n"
        "```\n\n"
        "## Evidence\n\n"
        f"- Fast handoff: {FAST_CODING_HANDOFF_PREFIX} {feature_id}\n"
        "- Coding evidence required: write a separate run record containing the fast coding evidence marker "
        "and matching coding pass verdict after implementation.\n"
        "- Evaluator pass prohibited in coding evidence: do not write evaluator pass evidence during the fast coding phase.\n"
    )
    print(f"Wrote fast coding handoff: {path}", flush=True)
    return path


def evaluate_feature(feature_id: str, dry_run: bool) -> bool:
    print(f"\n== Evaluate: {feature_id} ==", flush=True)
    result = run_agent(evaluator_prompt(feature_id), dry_run, "Evaluator Agent", EVALUATOR_AGENT_ADAPTER)
    if dry_run:
        return True
    passed, reason = evaluator_result(feature_id, result)
    if passed:
        if result.returncode != 0:
            print(
                f"Evaluator emitted EVAL_PASS despite provider exit code {result.returncode}; accepting final verdict.",
                flush=True,
            )
        print(f"Evaluator accepted {feature_id}.", flush=True)
        return True
    if result.returncode != 0:
        print(f"EVAL_FAIL: {feature_id}: evaluator exited with code {result.returncode}: {reason}", flush=True)
        return False
    print(f"EVAL_FAIL: {feature_id}: {reason}", flush=True)
    return False


def evaluate_fast_feature(feature_id: str, dry_run: bool, max_attempts: int) -> bool:
    print(f"\n== Work-fast evaluate: {feature_id} ==", flush=True)
    if dry_run:
        run_agent(evaluator_prompt(feature_id), dry_run=True, label="Evaluator Agent", adapter_path=EVALUATOR_AGENT_ADAPTER)
        return True

    evaluator = run_agent(evaluator_prompt(feature_id), dry_run=False, label="Evaluator Agent", adapter_path=EVALUATOR_AGENT_ADAPTER)
    passed, reason = evaluator_result(feature_id, evaluator)
    if passed:
        if evaluator.returncode != 0:
            print(
                f"Evaluator emitted EVAL_PASS despite provider exit code {evaluator.returncode}; accepting final verdict.",
                flush=True,
            )
        mark_done(feature_id)
        print(f"Done: {feature_id}", flush=True)
        return True

    if evaluator.returncode != 0:
        error = f"evaluator exited with code {evaluator.returncode}: {reason}"
    else:
        error = reason or "Evaluator rejected the feature."
    mark_failed(feature_id, error, max_attempts)
    write_failure_run_record(
        feature_id,
        error,
        command="python3 orchestrator.py --work-fast",
        failure_domain="agent_workflow_gap",
        harness_improvement="No new harness improvement required; work-fast preserved evaluator gating and recorded the evaluator failure.",
    )
    print(f"Evaluation failed: {feature_id}: {reason}", flush=True)
    return False


def run_work_fast_round(round_no: int, max_attempts: int, dry_run: bool) -> bool:
    data = load_state()
    feature = pick_fast_feature(data, max_attempts)
    if not feature:
        print("No runnable unfinished feature left.", flush=True)
        return True
    feature_id = str(feature["id"])
    print(f"\n== Work-fast round {round_no}: {feature_id} ==", flush=True)

    evidence_passed, evidence_reason = fast_coding_evidence_result(feature_id)
    if dry_run:
        print("\n== Fast coding handoff prompt ==")
        print(fast_coding_prompt(feature_id))
        run_agent(evaluator_prompt(feature_id), dry_run=True, label="Evaluator Agent", adapter_path=EVALUATOR_AGENT_ADAPTER)
        return True

    ensure_adapter_configured("Evaluator Agent", EVALUATOR_AGENT_ADAPTER)

    if evidence_passed is True:
        return evaluate_fast_feature(feature_id, dry_run=False, max_attempts=max_attempts)

    if evidence_passed is False:
        error = evidence_reason or "Fast coding evidence reported failure."
        mark_failed(feature_id, error, max_attempts)
        write_failure_run_record(
            feature_id,
            error,
            command="python3 orchestrator.py --work-fast",
            failure_domain="agent_workflow_gap",
            harness_improvement="No new harness improvement required; work-fast rejected invalid coding evidence before evaluator completion.",
        )
        return False

    if normalize_status(feature) != "in_progress":
        mark_in_progress(feature_id)
    write_fast_coding_handoff(feature_id)
    print(f"{FAST_CODING_HANDOFF_PREFIX} {feature_id}", flush=True)
    print(
        "Fast coding evidence is required before evaluator execution. "
        f"Record `{FAST_CODING_EVIDENCE_PREFIX} {feature_id}` and `CODING_PASS: {feature_id}` in runs/ after coding.",
        flush=True,
    )
    return True


def feature_ids_for_eval(target: str) -> list[str]:
    data = load_state()
    if target == "all":
        return [str(feature["id"]) for feature in features(data)]
    feature_by_id(data, target)
    return [target]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run AI agent harness orchestration.")
    parser.add_argument("--max-rounds", type=int, default=MAX_ROUNDS)
    parser.add_argument("--max-attempts", type=int, default=MAX_ATTEMPTS)
    parser.add_argument("--eval-only", metavar="FEATURE_ID|all")
    parser.add_argument("--work-fast", action="store_true", help="run evaluator-gated fast work mode")
    parser.add_argument(
        "--render-prompt",
        choices=["plan", "work", "evaluate", "continue", "work-fast"],
        help="render one role prompt with the detected provider-workspace path contract",
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    startup_protocol()

    if args.render_prompt:
        prompt_names = {
            "plan": "plan.md",
            "work": "work.md",
            "evaluate": "evaluate.md",
            "continue": "continue.md",
            "work-fast": "work-fast.md",
        }
        print(prompt_template(prompt_names[args.render_prompt]))
        return 0

    if args.eval_only:
        results = [evaluate_feature(feature_id, args.dry_run) for feature_id in feature_ids_for_eval(args.eval_only)]
        return 0 if all(results) else 1

    if args.work_fast:
        results = [run_work_fast_round(round_no, args.max_attempts, args.dry_run) for round_no in range(1, args.max_rounds + 1)]
        return 0 if all(results) else 1

    for round_no in range(1, args.max_rounds + 1):
        data = load_state()
        feature = pick_feature(data, args.max_attempts)
        if not feature:
            print("No runnable unfinished feature left.", flush=True)
            return 0
        feature_id = str(feature["id"])
        print(f"\n== Round {round_no}: {feature_id} ==", flush=True)

        if args.dry_run:
            run_agent(coding_prompt(feature_id), dry_run=True, label="Coding Agent", adapter_path=CODING_AGENT_ADAPTER)
            run_agent(evaluator_prompt(feature_id), dry_run=True, label="Evaluator Agent", adapter_path=EVALUATOR_AGENT_ADAPTER)
            continue

        ensure_adapter_configured("Coding Agent", CODING_AGENT_ADAPTER)
        ensure_adapter_configured("Evaluator Agent", EVALUATOR_AGENT_ADAPTER)
        mark_in_progress(feature_id)
        coding = run_agent(coding_prompt(feature_id), dry_run=False, label="Coding Agent", adapter_path=CODING_AGENT_ADAPTER)
        coding_passed, coding_reason = coding_result(feature_id, coding)
        if coding_passed is False:
            error = coding_reason or "Coding Agent reported failure."
            mark_failed(feature_id, error, args.max_attempts)
            write_failure_run_record(feature_id, error)
            continue
        if coding.returncode != 0:
            if coding_passed is True:
                print(
                    f"Coding Agent emitted CODING_PASS despite provider exit code {coding.returncode}; continuing.",
                    flush=True,
                )
            else:
                error = f"coding agent exited with code {coding.returncode}"
                mark_failed(feature_id, error, args.max_attempts)
                write_failure_run_record(feature_id, error)
                continue

        evaluator = run_agent(evaluator_prompt(feature_id), dry_run=False, label="Evaluator Agent", adapter_path=EVALUATOR_AGENT_ADAPTER)
        passed, reason = evaluator_result(feature_id, evaluator)
        if passed:
            if evaluator.returncode != 0:
                print(
                    f"Evaluator emitted EVAL_PASS despite provider exit code {evaluator.returncode}; accepting final verdict.",
                    flush=True,
                )
            mark_done(feature_id)
            print(f"Done: {feature_id}", flush=True)
        else:
            if evaluator.returncode != 0:
                error = f"evaluator exited with code {evaluator.returncode}: {reason}"
            else:
                error = reason or "Evaluator rejected the feature."
            mark_failed(feature_id, error, args.max_attempts)
            write_failure_run_record(feature_id, error)
            print(f"Evaluation failed: {feature_id}: {reason}", flush=True)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except OrchestratorError as exc:
        print(f"orchestrator error: {exc}", file=sys.stderr)
        raise SystemExit(1)
