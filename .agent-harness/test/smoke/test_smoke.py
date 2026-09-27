import subprocess
import json
import os
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run_command(args):
    return subprocess.run(args, cwd=ROOT, text=True, capture_output=True)


class SmokeTests(unittest.TestCase):
    def test_human_eval_batch_command_routes_mixed_outcomes(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            feature_path = tmp / "feature_list.json"
            runs_dir = tmp / "runs"
            runs_dir.mkdir()
            feature_path.write_text(json.dumps({"features": [
                {"id": "F039", "title": "first", "description": "desc", "acceptance": ["works"], "passes": True, "status": "done", "attempts": 3, "last_error": ""},
                {"id": "F040", "title": "second", "description": "desc", "acceptance": ["works"], "passes": True, "status": "done", "attempts": 1, "last_error": ""}
            ]}))
            batch_path = tmp / "human-eval.json"
            batch_path.write_text(json.dumps([
                {"feature_id": "F039", "result": "fail", "classification": "current_feature", "feedback": "original scope incomplete"},
                {"feature_id": "F040", "result": "fail", "classification": "new_requirement", "feedback": "add export"}
            ]))
            env = os.environ.copy()
            env["HARNESS_FEATURE_LIST"] = str(feature_path)
            env["HARNESS_RUNS_DIR"] = str(runs_dir)
            result = subprocess.run(["python3", "scripts/human-eval.py", "--batch-file", str(batch_path)], cwd=ROOT, text=True, capture_output=True, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            features = json.loads(feature_path.read_text())["features"]
            self.assertFalse(features[0]["passes"])
            self.assertTrue(features[1]["passes"])
            self.assertEqual(len(features), 2)
            self.assertEqual(len(list(runs_dir.glob("*-batch.md"))), 1)
    def test_primary_template_commands(self):
        commands = [
            ["python3", "scripts/validate-state.py"],
            ["scripts/summarize-progress.sh"],
            ["scripts/summarize-runs.sh"],
            ["scripts/check-failure-domains.sh"],
        ]
        for command in commands:
            with self.subTest(command=command):
                result = run_command(command)
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
