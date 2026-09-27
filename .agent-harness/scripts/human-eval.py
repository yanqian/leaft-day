#!/usr/bin/env python3
"""Record optional human product acceptance without creating repair features."""

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FEATURES_PATH = Path(os.environ.get("HARNESS_FEATURE_LIST", ROOT / "feature_list.json"))
RUNS_DIR = Path(os.environ.get("HARNESS_RUNS_DIR", ROOT / "runs"))
FEATURE_ID_RE = re.compile(r"^F[0-9]{3,}$")


def load_state() -> dict:
    data = json.loads(FEATURES_PATH.read_text())
    if not isinstance(data, dict) or not isinstance(data.get("features"), list):
        raise SystemExit("feature_list.json must contain a top-level features array")
    return data


def find_feature(data: dict, feature_id: str) -> dict:
    for feature in data["features"]:
        if feature.get("id") == feature_id:
            return feature
    raise SystemExit(f"feature not found: {feature_id}")


def write_record(feature_id: str, result: str, classification: str, feedback: str) -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = RUNS_DIR / f"{timestamp}-{feature_id}-human-eval.md"
    RUNS_DIR.mkdir(exist_ok=True)
    if result == "fail" and classification == "current_feature":
        result_label = "fail"
        verdict = f"HUMAN_EVAL_FAIL: {feature_id}: {feedback}"
        follow_up = "Continue implementation on the same Feature; do not append a repair Feature."
        domain = "implementation_gap"
        improvement = "The Human Eval command routes unmet original scope back to the original Feature."
    elif result == "fail":
        result_label = "new_requirement"
        verdict = f"HUMAN_EVAL_NEW_REQUIREMENT: {feature_id}: {feedback}"
        follow_up = "Run Planning Agent SPEC normalization and feature decomposition before appending a new Feature."
        domain = "requirement_gap"
        improvement = "Human feedback is explicitly classified before any new Feature is appended."
    else:
        result_label = "pass"
        verdict = f"HUMAN_EVAL_PASS: {feature_id}"
        follow_up = "Feature remains complete; record unrelated new value through Planning Agent."
        domain = "none"
        improvement = "No new harness improvement required."
    path.write_text(
        f"# Run Record: {feature_id} - human evaluation\n\n"
        "## Summary\n\n"
        f"- Date: {timestamp}\n- Agent role: Human Product Evaluation\n- Feature: {feature_id}\n- Result: {result_label}\n\n"
        "## Evidence\n\n"
        f"- Feedback: {feedback}\n- Classification: {classification}\n\n"
        "## Failure Analysis\n\n"
        f"- Failure domain: {domain}\n- Failure summary: {feedback}\n- Harness improvement: {improvement}\n- Follow-up feature:\n\n"
        "## Evaluator Result\n\n```text\n"
        f"{verdict}\n```\n\n## Follow-Up\n\n- {follow_up}\n"
    )
    return path


def write_batch_record(entries: list[dict]) -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = RUNS_DIR / f"{timestamp}-human-eval-batch.md"
    RUNS_DIR.mkdir(exist_ok=True)
    lines = []
    has_current_failure = False
    has_new_requirement = False
    for entry in entries:
        feature_id = entry["feature_id"]
        result = entry["result"]
        classification = entry["classification"]
        feedback = entry["feedback"]
        lines.append(f"- `{feature_id}`: result={result}, classification={classification}, feedback={feedback}")
        has_current_failure |= result == "fail" and classification == "current_feature"
        has_new_requirement |= result == "fail" and classification == "new_requirement"
    if has_current_failure:
        domain = "implementation_gap"
        improvement = "The batch Human Eval command reopens original Features for unmet original scope."
        result_label = "fail"
    elif has_new_requirement:
        domain = "requirement_gap"
        improvement = "The batch Human Eval command routes independent value to Planning without auto-appending Features."
        result_label = "new_requirement"
    else:
        domain = "none"
        improvement = "No new harness improvement required."
        result_label = "pass"
    verdicts = []
    for entry in entries:
        feature_id = entry["feature_id"]
        if entry["result"] == "pass":
            verdicts.append(f"HUMAN_EVAL_PASS: {feature_id}")
        elif entry["classification"] == "current_feature":
            verdicts.append(f"HUMAN_EVAL_FAIL: {feature_id}: {entry['feedback']}")
        else:
            verdicts.append(f"HUMAN_EVAL_NEW_REQUIREMENT: {feature_id}: {entry['feedback']}")
    path.write_text(
        "# Run Record: Human Evaluation Batch\n\n## Summary\n\n"
        f"- Date: {timestamp}\n- Agent role: Human Product Evaluation\n- Feature: batch\n- Result: {result_label}\n- Feature count: {len(entries)}\n\n"
        "## Evidence\n\n" + "\n".join(lines) + "\n\n"
        "## Failure Analysis\n\n"
        f"- Failure domain: {domain}\n- Failure summary: batch Human Eval routing\n- Harness improvement: {improvement}\n- Follow-up feature:\n\n"
        "## Evaluator Result\n\n```text\n" + "\n".join(verdicts) + "\n```\n\n"
        "## Follow-Up\n\n- Current-Feature failures continue on their original Features. New requirements require Planning Agent normalization.\n"
    )
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description="Record optional Human Eval feedback for one or a batch of Features.")
    parser.add_argument("feature_id", nargs="?", help="Feature ID, such as F039")
    parser.add_argument("--batch-file", help="JSON array of {feature_id, result, classification, feedback} entries")
    parser.add_argument("--result", choices=["pass", "fail"])
    parser.add_argument("--classification", choices=["current_feature", "new_requirement"])
    parser.add_argument("--feedback")
    args = parser.parse_args()
    if bool(args.feature_id) == bool(args.batch_file):
        raise SystemExit("provide exactly one Feature ID or --batch-file")
    if args.batch_file:
        entries = json.loads(Path(args.batch_file).read_text())
        if not isinstance(entries, list) or not entries:
            raise SystemExit("--batch-file must contain a non-empty JSON array")
    else:
        entries = [{"feature_id": args.feature_id, "result": args.result, "classification": args.classification, "feedback": args.feedback}]
    normalized = []
    for entry in entries:
        if not isinstance(entry, dict) or not FEATURE_ID_RE.fullmatch(str(entry.get("feature_id", ""))):
            raise SystemExit("each entry needs a feature_id matching F###")
        result = entry.get("result")
        classification = entry.get("classification")
        feedback = str(entry.get("feedback", "")).strip()
        if result not in {"pass", "fail"} or classification not in {"current_feature", "new_requirement"} or not feedback:
            raise SystemExit("each entry needs result, classification, and non-empty feedback")
        if result == "pass" and classification != "current_feature":
            raise SystemExit("a passing Human Eval must use classification current_feature")
        normalized.append({"feature_id": str(entry["feature_id"]), "result": result, "classification": classification, "feedback": feedback})
    data = load_state()
    for entry in normalized:
        feature = find_feature(data, entry["feature_id"])
        now = datetime.now(timezone.utc).isoformat()
        acceptance = feature.setdefault("human_acceptance", {"status": "unreviewed", "history": []})
        if not isinstance(acceptance, dict):
            raise SystemExit(f"feature {entry['feature_id']} has invalid human_acceptance metadata")
        history = acceptance.setdefault("history", [])
        if not isinstance(history, list):
            raise SystemExit(f"feature {entry['feature_id']} has invalid human_acceptance history")
        history.append({"at": now, "result": entry["result"], "classification": entry["classification"], "feedback": entry["feedback"]})
        acceptance["last_feedback"] = entry["feedback"]
        acceptance["last_recorded_at"] = now
        if entry["result"] == "fail" and entry["classification"] == "current_feature":
            feature["passes"] = False
            feature["status"] = "todo"
            feature["last_error"] = f"Human Eval: {entry['feedback']}"[:2000]
            acceptance["status"] = "rejected"
            acceptance["reopen_pending"] = True
        elif entry["result"] == "fail":
            acceptance["status"] = "new_requirement"
            acceptance["reopen_pending"] = False
        else:
            if feature.get("passes") is not True or feature.get("status") != "done":
                raise SystemExit(f"cannot record Human Eval pass for {entry['feature_id']}: it is not evaluator-complete")
            acceptance["status"] = "accepted"
            acceptance["reopen_pending"] = False

    FEATURES_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    record = write_batch_record(normalized) if args.batch_file else write_record(**normalized[0])
    for entry in normalized:
        if entry["result"] == "fail" and entry["classification"] == "current_feature":
            print(f"Reopened {entry['feature_id']}; continue the same Feature.")
        elif entry["result"] == "fail":
            print(f"Recorded a new-requirement candidate for {entry['feature_id']}; no Feature was appended.")
        else:
            print(f"Accepted {entry['feature_id']}; it remains complete.")
    try:
        display_record = record.relative_to(ROOT)
    except ValueError:
        display_record = record
    print(f"Run record: {display_record}")
    if any(entry["classification"] == "new_requirement" for entry in normalized):
        print("Next: normalize the requirement in SPEC.md, then let Planning Agent append a separate Feature.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
