import json
import importlib.util
import contextlib
import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run_command(args, env=None, input_text=None):
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(args, cwd=ROOT, text=True, capture_output=True, env=merged_env, input=input_text)


def write_executable(path, text):
    path.write_text(text)
    path.chmod(0o755)


def load_orchestrator():
    spec = importlib.util.spec_from_file_location("orchestrator", ROOT / "orchestrator.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_human_eval():
    spec = importlib.util.spec_from_file_location("human_eval", ROOT / "scripts" / "human-eval.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ScriptUnitTests(unittest.TestCase):
    def test_human_eval_reopens_same_feature_and_preserves_state(self):
        human_eval = load_human_eval()
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            feature_path = tmp / "feature_list.json"
            runs_dir = tmp / "runs"
            runs_dir.mkdir()
            feature_path.write_text(json.dumps({"features": [{
                "id": "F039", "title": "feature", "description": "desc", "acceptance": ["works"],
                "passes": True, "status": "done", "attempts": 3, "last_error": "",
                "custom_field": "preserve"
            }]}))
            with mock.patch.object(human_eval, "FEATURES_PATH", feature_path), mock.patch.object(human_eval, "RUNS_DIR", runs_dir), mock.patch.object(sys, "argv", ["human-eval.py", "F039", "--result", "fail", "--classification", "current_feature", "--feedback", "flow is incomplete"]):
                self.assertEqual(human_eval.main(), 0)
            feature = json.loads(feature_path.read_text())["features"][0]
            self.assertFalse(feature["passes"])
            self.assertEqual(feature["status"], "todo")
            self.assertEqual(feature["attempts"], 3)
            self.assertEqual(feature["custom_field"], "preserve")
            self.assertTrue(feature["human_acceptance"]["reopen_pending"])
            self.assertEqual(len(list(runs_dir.glob("*human-eval.md"))), 1)

    def test_orchestrator_selects_human_reopened_feature_after_attempt_limit(self):
        orchestrator = load_orchestrator()
        data = {"features": [{
            "id": "F039", "title": "feature", "description": "desc", "acceptance": ["works"],
            "passes": False, "status": "todo", "attempts": 3, "last_error": "",
            "human_acceptance": {"reopen_pending": True}
        }]}
        self.assertEqual(orchestrator.pick_feature(data, 3)["id"], "F039")

    def test_human_eval_new_requirement_does_not_mark_original_incomplete(self):
        human_eval = load_human_eval()
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            feature_path = tmp / "feature_list.json"
            runs_dir = tmp / "runs"
            runs_dir.mkdir()
            feature_path.write_text(json.dumps({"features": [{
                "id": "F039", "title": "feature", "description": "desc", "acceptance": ["works"],
                "passes": True, "status": "done", "attempts": 1, "last_error": ""
            }]}))
            with mock.patch.object(human_eval, "FEATURES_PATH", feature_path), mock.patch.object(human_eval, "RUNS_DIR", runs_dir), mock.patch.object(sys, "argv", ["human-eval.py", "F039", "--result", "fail", "--classification", "new_requirement", "--feedback", "add OAuth"]):
                self.assertEqual(human_eval.main(), 0)
            feature = json.loads(feature_path.read_text())["features"][0]
            self.assertTrue(feature["passes"])
            self.assertEqual(feature["status"], "done")
            self.assertFalse(feature["human_acceptance"]["reopen_pending"])

    def test_human_eval_batch_routes_mixed_outcomes_without_appending_features(self):
        human_eval = load_human_eval()
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            feature_path = tmp / "feature_list.json"
            runs_dir = tmp / "runs"
            runs_dir.mkdir()
            feature_path.write_text(json.dumps({"features": [
                {"id": "F039", "title": "first", "description": "desc", "acceptance": ["works"], "passes": True, "status": "done", "attempts": 3, "last_error": ""},
                {"id": "F040", "title": "second", "description": "desc", "acceptance": ["works"], "passes": True, "status": "done", "attempts": 1, "last_error": ""}
            ]}))
            batch = tmp / "human-eval.json"
            batch.write_text(json.dumps([
                {"feature_id": "F039", "result": "fail", "classification": "current_feature", "feedback": "original flow incomplete"},
                {"feature_id": "F040", "result": "fail", "classification": "new_requirement", "feedback": "add exports"}
            ]))
            with mock.patch.object(human_eval, "FEATURES_PATH", feature_path), mock.patch.object(human_eval, "RUNS_DIR", runs_dir), mock.patch.object(sys, "argv", ["human-eval.py", "--batch-file", str(batch)]):
                self.assertEqual(human_eval.main(), 0)
            features = json.loads(feature_path.read_text())["features"]
            self.assertFalse(features[0]["passes"])
            self.assertEqual(features[0]["status"], "todo")
            self.assertTrue(features[1]["passes"])
            self.assertEqual(features[1]["status"], "done")
            self.assertEqual(len(features), 2)
            self.assertEqual(len(list(runs_dir.glob("*-batch.md"))), 1)

    def test_human_eval_batch_records_pass_without_reopening(self):
        human_eval = load_human_eval()
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            feature_path = tmp / "feature_list.json"
            runs_dir = tmp / "runs"
            runs_dir.mkdir()
            feature_path.write_text(json.dumps({"features": [{
                "id": "F039", "title": "feature", "description": "desc", "acceptance": ["works"],
                "passes": True, "status": "done", "attempts": 1, "last_error": ""
            }]}))
            batch = tmp / "human-eval.json"
            batch.write_text(json.dumps([{"feature_id": "F039", "result": "pass", "classification": "current_feature", "feedback": "accepted"}]))
            with mock.patch.object(human_eval, "FEATURES_PATH", feature_path), mock.patch.object(human_eval, "RUNS_DIR", runs_dir), mock.patch.object(sys, "argv", ["human-eval.py", "--batch-file", str(batch)]):
                self.assertEqual(human_eval.main(), 0)
            feature = json.loads(feature_path.read_text())["features"][0]
            self.assertTrue(feature["passes"])
            self.assertEqual(feature["status"], "done")
    def test_validate_state_accepts_current_feature_list(self):
        result = run_command([sys.executable, "scripts/validate-state.py"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("validated", result.stdout)

    def test_validate_feature_rejects_unknown_feature(self):
        result = run_command(["scripts/validate-feature.sh", "F999"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown feature id: F999", result.stderr)

    def test_summarize_progress_reports_counts(self):
        result = run_command(["scripts/summarize-progress.sh"])
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads((ROOT / "feature_list.json").read_text())
        features = data["features"]
        unfinished = [
            feature
            for feature in features
            if not (feature.get("passes") is True and feature.get("status") == "done")
        ]
        self.assertIn(f"features_total={len(features)}", result.stdout)
        self.assertIn(f"features_unfinished={len(unfinished)}", result.stdout)
        if unfinished:
            next_feature = unfinished[0]
            self.assertIn(f"next_feature={next_feature['id']} {next_feature['title']}", result.stdout)
        else:
            self.assertIn("next_feature=none", result.stdout)

    def test_summarize_runs_reports_empty_records(self):
        result = run_command(["scripts/summarize-runs.sh"])
        self.assertEqual(result.returncode, 0, result.stderr)
        records = sorted(
            path for path in (ROOT / "runs").glob("*.md")
            if path.name != "RUN_TEMPLATE.md"
        )
        self.assertIn(f"run_records={len(records)}", result.stdout)
        if records:
            latest = records[-1].relative_to(ROOT)
            self.assertIn(f"latest_run={latest}", result.stdout)
        else:
            self.assertIn("latest_run=none", result.stdout)

    def test_check_failure_domains_requires_improvement_assessment(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            runs_dir = Path(tmp_dir)
            record = runs_dir / "_unit_failure.md"
            record.write_text(
                "# Run Record: F999 - unit failure\n\n"
                "## Summary\n\n"
                "- Result: fail\n\n"
                "## Failure Analysis\n\n"
                "- Failure domain: test_gap\n"
                "- Failure summary: synthetic failure\n"
                "- Harness improvement:\n"
                "- Follow-up feature:\n"
            )
            env = {"HARNESS_RUNS_DIR": str(runs_dir)}
            result = run_command(["scripts/check-failure-domains.sh"], env=env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing_harness_improvement=1", result.stdout)

            record.write_text(
                "# Run Record: F999 - unit failure\n\n"
                "## Summary\n\n"
                "- Result: fail\n\n"
                "## Failure Analysis\n\n"
                "- Failure domain: test_gap\n"
                "- Failure summary: synthetic failure\n"
                "- Harness improvement: add a regression test for this failure class\n"
                "- Follow-up feature: F999\n"
            )
            result = run_command(["scripts/check-failure-domains.sh"], env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("failure_records=1", result.stdout)
            self.assertIn("domain[test_gap]=1", result.stdout)

    def test_check_evaluator_evidence_requires_matching_pass_record(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            feature_list = tmp / "feature_list.json"
            runs_dir = tmp / "runs"
            runs_dir.mkdir()
            feature_list.write_text(json.dumps({
                "features": [
                    {
                        "id": "F026",
                        "title": "historical feature",
                        "description": "before baseline",
                        "acceptance": ["historical features are not checked"],
                        "passes": True,
                        "status": "done",
                        "attempts": 1,
                        "last_error": "",
                    },
                    {
                        "id": "F027",
                        "title": "needs evaluator evidence",
                        "description": "at baseline",
                        "acceptance": ["must have EVAL_PASS"],
                        "passes": True,
                        "status": "done",
                        "attempts": 1,
                        "last_error": "",
                    },
                ]
            }) + "\n")
            env = {
                "HARNESS_FEATURE_LIST": str(feature_list),
                "HARNESS_RUNS_DIR": str(runs_dir),
                "HARNESS_EVALUATOR_EVIDENCE_BASELINE": "F027",
            }

            result = run_command(["scripts/check-evaluator-evidence.sh"], env=env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing_evaluator_evidence=1", result.stdout)
            self.assertIn("missing evaluator evidence: F027", result.stderr)

            (runs_dir / "F027.md").write_text(
                "# Run Record: F027\n\n"
                "## Evaluator Result\n\n"
                "```text\n"
                "EVAL_PASS: F027\n"
                "```\n"
            )
            result = run_command(["scripts/check-evaluator-evidence.sh"], env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("evaluator_evidence_checked=1", result.stdout)
            self.assertIn("missing_evaluator_evidence=0", result.stdout)

    def test_clean_state_resets_project_state_only(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            shutil.copy(ROOT / "feature_list.json", project / "feature_list.json")
            (project / "progress.md").write_text("# Progress\n\nold state\n")
            runs = project / "runs"
            runs.mkdir()
            (runs / "RUN_TEMPLATE.md").write_text((ROOT / "runs" / "RUN_TEMPLATE.md").read_text())
            (runs / ".gitkeep").write_text("")
            (runs / "20260101T000000Z-F001.md").write_text("old run")

            result = run_command([sys.executable, "scripts/clean-state.py", "--root", str(project)])
            self.assertEqual(result.returncode, 0, result.stderr)

            data = json.loads((project / "feature_list.json").read_text())
            self.assertEqual(data, {"features": []})
            progress = (project / "progress.md").read_text()
            self.assertIn("Harness state has been reset for a new project.", progress)
            self.assertIn("Add the first feature to `feature_list.json`.", progress)
            self.assertTrue((runs / "RUN_TEMPLATE.md").exists())
            self.assertTrue((runs / ".gitkeep").exists())
            self.assertFalse((runs / "20260101T000000Z-F001.md").exists())

    def test_ai_agent_harness_skill_initializer_adopts_project(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            script = ROOT / "skills" / "ai-agent-harness" / "scripts" / "init_harness.py"
            result = run_command([
                sys.executable,
                str(script),
                "--root",
                str(project),
                "--template-root",
                str(ROOT),
                "--mode",
                "adopt",
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("mode=adopt", result.stdout)
            self.assertIn("layout=hidden", result.stdout)

            data = json.loads((project / ".agent-harness" / "feature_list.json").read_text())
            self.assertEqual(data, {"features": []})
            progress = (project / ".agent-harness" / "progress.md").read_text()
            self.assertIn("Project requirements have not been accepted yet.", progress)
            self.assertTrue((project / "AGENTS.md").exists())
            self.assertTrue((project / ".agent-harness" / "skills" / "ai-agent-harness" / "SKILL.md").exists())
            self.assertFalse((project / ".agent-harness" / "skills" / "ai-agent-harness" / "assets" / "template" / "AGENTS.md").exists())

    def test_ai_agent_harness_skill_initializer_reports_conflicts_without_force(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            (project / "AGENTS.md").write_text("custom project agent rules\n")
            script = ROOT / "skills" / "ai-agent-harness" / "scripts" / "init_harness.py"
            result = run_command([
                sys.executable,
                str(script),
                "--root",
                str(project),
                "--template-root",
                str(ROOT),
                "--mode",
                "adopt",
                "--dry-run",
            ])
            self.assertEqual(result.returncode, 1)
            self.assertIn("blocking_conflicts:", result.stdout)
            self.assertIn("AGENTS.md", result.stdout)
            self.assertEqual((project / "AGENTS.md").read_text(), "custom project agent rules\n")

    def test_agent_provider_fails_when_no_config_is_present(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            env = {
                "HARNESS_AGENT_PROVIDER_CONFIG": str(Path(tmp_dir) / "agent-provider.json"),
                "PATH": str(Path(tmp_dir) / "bin"),
            }
            result = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "coding", "--check"], env=env)
            self.assertEqual(result.returncode, 2)
            self.assertIn("no agent provider configured", result.stderr)

    def test_agent_provider_rejects_ambiguous_unconfigured_candidates(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            bin_dir = Path(tmp_dir) / "bin"
            bin_dir.mkdir()
            write_executable(bin_dir / "codex", "#!/usr/bin/env bash\nexit 0\n")
            write_executable(bin_dir / "claude", "#!/usr/bin/env bash\nexit 0\n")
            env = {
                "HARNESS_AGENT_PROVIDER_CONFIG": str(Path(tmp_dir) / "agent-provider.json"),
                "PATH": str(bin_dir),
            }
            result = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "coding", "--check"], env=env)
            self.assertEqual(result.returncode, 2)
            self.assertIn("multiple agent provider candidates detected", result.stderr)
            self.assertIn("codex", result.stderr)
            self.assertIn("claude-code", result.stderr)

    def test_agent_provider_rejects_missing_configured_command(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            config = Path(tmp_dir) / "agent-provider.json"
            config.write_text(json.dumps({
                "provider": "custom",
                "providers": {
                    "custom": {
                        "command": ["missing-agent-provider-command"]
                    }
                }
            }))
            env = {"HARNESS_AGENT_PROVIDER_CONFIG": str(config)}
            result = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "coding", "--check"], env=env)
            self.assertEqual(result.returncode, 2)
            self.assertIn("configured provider command is missing", result.stderr)

    def test_agent_provider_dispatches_configured_provider(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            provider = Path(tmp_dir) / "provider.py"
            provider.write_text(
                "import sys\n"
                "prompt = sys.stdin.read()\n"
                "print('provider received: ' + prompt)\n"
            )
            config = Path(tmp_dir) / "agent-provider.json"
            config.write_text(json.dumps({
                "provider": "custom",
                "providers": {
                    "custom": {
                        "command": [sys.executable, str(provider)]
                    }
                }
            }))
            env = {"HARNESS_AGENT_PROVIDER_CONFIG": str(config)}

            check = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "evaluator", "--check"], env=env)
            self.assertEqual(check.returncode, 0, check.stderr)
            self.assertIn("agent_provider_check=ok", check.stdout)

            result = run_command(
                [sys.executable, "scripts/run-agent-provider.py", "--role", "evaluator"],
                env=env,
                input_text="hello evaluator",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("provider received: hello evaluator", result.stdout)

    def test_agent_provider_runtime_check_runs_when_configured(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            marker = Path(tmp_dir) / "runtime.marker"
            checker = Path(tmp_dir) / "checker.py"
            checker.write_text(
                "import sys\n"
                "from pathlib import Path\n"
                "prompt = sys.stdin.read()\n"
                f"Path({str(marker)!r}).write_text(prompt)\n"
            )
            config = Path(tmp_dir) / "agent-provider.json"
            config.write_text(json.dumps({
                "provider": "custom",
                "providers": {
                    "custom": {
                        "command": [sys.executable, str(checker)],
                        "runtime_check_command": [sys.executable, str(checker)],
                    }
                }
            }))
            env = {"HARNESS_AGENT_PROVIDER_CONFIG": str(config)}

            result = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "coding", "--check"], env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("agent_provider_check=ok", result.stdout)
            self.assertIn("agent_provider_runtime_check=ok role=coding provider=custom", result.stdout)
            self.assertEqual(marker.read_text(), "Reply exactly: PROVIDER_CHECK_OK\n")

    def test_agent_provider_runtime_check_reports_permission_required(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            provider = Path(tmp_dir) / "provider.py"
            provider.write_text("print('provider ok')\n")
            checker = Path(tmp_dir) / "checker.py"
            checker.write_text(
                "import sys\n"
                "print('/Users/example/.codex/state_5.sqlite: Operation not permitted', file=sys.stderr)\n"
                "raise SystemExit(1)\n"
            )
            config = Path(tmp_dir) / "agent-provider.json"
            config.write_text(json.dumps({
                "provider": "custom",
                "providers": {
                    "custom": {
                        "command": [sys.executable, str(provider)],
                        "runtime_check_command": [sys.executable, str(checker)],
                    }
                }
            }))
            env = {"HARNESS_AGENT_PROVIDER_CONFIG": str(config)}

            result = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "evaluator", "--check"], env=env)
            self.assertEqual(result.returncode, 2)
            self.assertIn("PROVIDER_RUNTIME_PERMISSION_REQUIRED", result.stderr)
            self.assertIn("provider=custom role=evaluator", result.stderr)
            self.assertIn("approve escalated provider runtime execution", result.stderr)

    def test_agent_provider_runtime_check_supports_role_specific_commands(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            provider = Path(tmp_dir) / "provider.py"
            provider.write_text("print('provider ok')\n")
            coding_marker = Path(tmp_dir) / "coding.marker"
            evaluator_marker = Path(tmp_dir) / "evaluator.marker"
            coding_checker = Path(tmp_dir) / "coding_checker.py"
            coding_checker.write_text(f"from pathlib import Path\nPath({str(coding_marker)!r}).write_text('coding')\n")
            evaluator_checker = Path(tmp_dir) / "evaluator_checker.py"
            evaluator_checker.write_text(f"from pathlib import Path\nPath({str(evaluator_marker)!r}).write_text('evaluator')\n")
            config = Path(tmp_dir) / "agent-provider.json"
            config.write_text(json.dumps({
                "provider": "custom",
                "providers": {
                    "custom": {
                        "command": [sys.executable, str(provider)],
                        "coding_runtime_check_command": [sys.executable, str(coding_checker)],
                        "evaluator_runtime_check_command": [sys.executable, str(evaluator_checker)],
                    }
                }
            }))
            env = {"HARNESS_AGENT_PROVIDER_CONFIG": str(config)}

            coding = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "coding", "--check"], env=env)
            self.assertEqual(coding.returncode, 0, coding.stderr)
            self.assertEqual(coding_marker.read_text(), "coding")
            self.assertFalse(evaluator_marker.exists())

            evaluator = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "evaluator", "--check"], env=env)
            self.assertEqual(evaluator.returncode, 0, evaluator.stderr)
            self.assertEqual(evaluator_marker.read_text(), "evaluator")

    def test_agent_provider_uses_same_config_relative_cwd_for_preflight_and_execution(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir) / "project"
            harness = project / ".agent-harness"
            harness.mkdir(parents=True)
            (project / "feature_list.json").write_text("stale-root-feature-state")
            (project / "progress.md").write_text("stale-root-progress")
            (harness / "feature_list.json").write_text("canonical-feature-state")
            (harness / "progress.md").write_text("canonical-progress")
            provider = harness / "fake_provider.py"
            provider.write_text(
                "import os, sys\n"
                "from pathlib import Path\n"
                "prompt = sys.stdin.read()\n"
                "name = 'preflight.cwd' if 'PROVIDER_CHECK_OK' in prompt else 'execution.cwd'\n"
                "Path(name).write_text(os.getcwd())\n"
            )
            config = harness / "agent-provider.json"
            config.write_text(json.dumps({
                "provider": "custom",
                "providers": {
                    "custom": {
                        "cwd": "..",
                        "command": [sys.executable, str(provider)],
                        "runtime_check_command": [sys.executable, str(provider)],
                    }
                }
            }))
            env = {"HARNESS_AGENT_PROVIDER_CONFIG": str(config)}

            check = run_command([sys.executable, "scripts/run-agent-provider.py", "--role", "coding", "--check"], env=env)
            self.assertEqual(check.returncode, 0, check.stderr)
            execute = run_command(
                [sys.executable, "scripts/run-agent-provider.py", "--role", "coding"],
                env=env,
                input_text="coding prompt",
            )
            self.assertEqual(execute.returncode, 0, execute.stderr)
            self.assertEqual((project / "preflight.cwd").read_text(), str(project.resolve()))
            self.assertEqual((project / "execution.cwd").read_text(), str(project.resolve()))
            self.assertEqual((project / "feature_list.json").read_text(), "stale-root-feature-state")
            self.assertEqual((project / "progress.md").read_text(), "stale-root-progress")
            self.assertEqual((harness / "feature_list.json").read_text(), "canonical-feature-state")
            self.assertEqual((harness / "progress.md").read_text(), "canonical-progress")

    def test_orchestrator_renders_layout_aware_contract_for_every_role_surface(self):
        orchestrator = load_orchestrator()
        role_prompts = ["plan.md", "work.md", "evaluate.md", "continue.md", "work-fast.md"]
        hidden = [orchestrator.prompt_template(name, layout="hidden") for name in role_prompts]
        for prompt in hidden:
            self.assertIn("Harness layout: `hidden`", prompt)
            self.assertIn("`feature_list.json` -> `.agent-harness/feature_list.json`", prompt)
            self.assertIn("`progress.md` -> `.agent-harness/progress.md`", prompt)
            self.assertIn("`runs/` -> `.agent-harness/runs/`", prompt)
            self.assertIn("legacy/non-canonical", prompt)
            self.assertIn("root `./init.sh` remain relative to the provider workspace", prompt)

        visible = orchestrator.prompt_template("work.md", layout="visible")
        self.assertIn("Harness layout: `visible`", visible)
        self.assertIn("`feature_list.json` -> `feature_list.json`", visible)
        self.assertNotIn("`.agent-harness/feature_list.json`", visible)

    def test_hidden_manifest_selects_canonical_paths_without_touching_stale_root_state(self):
        orchestrator = load_orchestrator()
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir) / "project"
            harness = project / ".agent-harness"
            harness.mkdir(parents=True)
            stale_feature = project / "feature_list.json"
            stale_progress = project / "progress.md"
            canonical_feature = harness / "feature_list.json"
            canonical_progress = harness / "progress.md"
            stale_feature.write_text("stale-root-feature-sentinel")
            stale_progress.write_text("stale-root-progress-sentinel")
            canonical_feature.write_text("canonical-feature-sentinel")
            canonical_progress.write_text("canonical-progress-sentinel")
            (harness / "manifest.json").write_text(json.dumps({"layout": "hidden"}))

            previous = Path.cwd()
            try:
                os.chdir(harness)
                with (
                    mock.patch.object(orchestrator, "INSTALL_MANIFEST_PATH", Path("manifest.json")),
                    mock.patch.object(orchestrator, "PROMPTS_DIR", ROOT / "prompts"),
                ):
                    prompt = orchestrator.prompt_template("evaluate.md")
            finally:
                os.chdir(previous)

            self.assertIn("Harness layout: `hidden`", prompt)
            self.assertIn("`feature_list.json` -> `.agent-harness/feature_list.json`", prompt)
            self.assertIn("`runs/` -> `.agent-harness/runs/`", prompt)
            self.assertEqual(stale_feature.read_text(), "stale-root-feature-sentinel")
            self.assertEqual(stale_progress.read_text(), "stale-root-progress-sentinel")
            self.assertEqual(canonical_feature.read_text(), "canonical-feature-sentinel")
            self.assertEqual(canonical_progress.read_text(), "canonical-progress-sentinel")

    def test_orchestrator_evaluator_result_uses_final_matching_verdict(self):
        orchestrator = load_orchestrator()
        result = subprocess.CompletedProcess(
            ["evaluator"],
            0,
            stdout=(
                "historical run evidence\n"
                "EVAL_FAIL: F006: old provider failure\n"
                "final evaluator decision\n"
                "EVAL_PASS: F006\n"
            ),
            stderr="",
        )
        self.assertEqual(orchestrator.evaluator_result("F006", result), (True, ""))

        result = subprocess.CompletedProcess(
            ["evaluator"],
            0,
            stdout=(
                "historical run evidence\n"
                "EVAL_PASS: F006\n"
                "final evaluator decision\n"
                "EVAL_FAIL: F006: acceptance criteria not met\n"
            ),
            stderr="",
        )
        self.assertEqual(
            orchestrator.evaluator_result("F006", result),
            (False, "acceptance criteria not met"),
        )

    def test_orchestrator_coding_result_uses_final_matching_verdict(self):
        orchestrator = load_orchestrator()
        result = subprocess.CompletedProcess(
            ["coding"],
            1,
            stdout=(
                "intermediate failed attempt\n"
                "CODING_FAIL: F009: transient command failed\n"
                "final coding decision\n"
                "CODING_PASS: F009\n"
            ),
            stderr="",
        )
        self.assertEqual(orchestrator.coding_result("F009", result), (True, ""))

        result = subprocess.CompletedProcess(
            ["coding"],
            1,
            stdout="completed without structured coding verdict\n",
            stderr="",
        )
        self.assertEqual(orchestrator.coding_result("F009", result), (None, ""))

    def test_orchestrator_fast_coding_evidence_rejects_eval_pass_spoofing(self):
        orchestrator = load_orchestrator()
        with tempfile.TemporaryDirectory() as tmp_dir:
            runs_dir = Path(tmp_dir)
            with mock.patch.object(orchestrator, "RUNS_DIR", runs_dir):
                self.assertEqual(orchestrator.fast_coding_evidence_result("F123"), (None, ""))

                (runs_dir / "handoff.md").write_text(
                    "# Run Record\n\n"
                    "FAST_CODING_HANDOFF: F123\n"
                    "FAST_CODING_EVIDENCE: F123\n"
                    "CODING_PASS: F123\n"
                    "EVAL_PASS: F123\n"
                )
                self.assertEqual(orchestrator.fast_coding_evidence_result("F123"), (None, ""))

                (runs_dir / "valid.md").write_text(
                    "# Run Record\n\n"
                    "FAST_CODING_EVIDENCE: F123\n"
                    "CODING_PASS: F123\n"
                )
                self.assertEqual(orchestrator.fast_coding_evidence_result("F123"), (True, ""))

                (runs_dir / "spoof.md").write_text(
                    "# Run Record\n\n"
                    "FAST_CODING_EVIDENCE: F123\n"
                    "CODING_PASS: F123\n"
                    "EVAL_PASS: F123\n"
                )
                passed, reason = orchestrator.fast_coding_evidence_result("F123")
                self.assertFalse(passed)
                self.assertIn("must not contain evaluator pass evidence", reason)

    def test_orchestrator_fast_evidence_ignores_verdict_examples_in_other_run_records(self):
        orchestrator = load_orchestrator()
        with tempfile.TemporaryDirectory() as tmp_dir:
            runs_dir = Path(tmp_dir)
            (runs_dir / "coding.md").write_text("FAST_CODING_EVIDENCE: F123\nCODING_PASS: F123\n")
            (runs_dir / "evaluation.md").write_text("- Logs: coding evidence must not contain `EVAL_PASS: F123`\n")
            with mock.patch.object(orchestrator, "RUNS_DIR", runs_dir):
                self.assertEqual(orchestrator.fast_coding_evidence_result("F123"), (True, ""))

    def test_orchestrator_work_fast_starts_without_coding_adapter(self):
        orchestrator = load_orchestrator()
        data = {
            "features": [
                {
                    "id": "F123",
                    "title": "fast feature",
                    "description": "feature",
                    "acceptance": ["done"],
                    "passes": False,
                    "status": "todo",
                    "attempts": 0,
                    "last_error": "",
                    "priority": "P0",
                }
            ]
        }
        with tempfile.TemporaryDirectory() as tmp_dir:
            runs_dir = Path(tmp_dir)
            with (
                mock.patch.object(orchestrator, "RUNS_DIR", runs_dir),
                mock.patch.object(orchestrator, "load_state", return_value=data),
                mock.patch.object(orchestrator, "ensure_adapter_configured") as ensure,
                mock.patch.object(orchestrator, "mark_in_progress") as mark_in_progress,
                mock.patch.object(orchestrator, "write_fast_coding_handoff") as handoff,
                mock.patch.object(orchestrator, "evaluate_fast_feature") as evaluate,
            ):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertTrue(orchestrator.run_work_fast_round(1, 3, False))
                ensure.assert_called_once()
                self.assertEqual(ensure.call_args.args[0], "Evaluator Agent")
                mark_in_progress.assert_called_once_with("F123")
                handoff.assert_called_once_with("F123")
                evaluate.assert_not_called()

    def test_orchestrator_work_fast_requires_evaluator_after_coding_evidence(self):
        orchestrator = load_orchestrator()
        data = {
            "features": [
                {
                    "id": "F123",
                    "title": "fast feature",
                    "description": "feature",
                    "acceptance": ["done"],
                    "passes": False,
                    "status": "in_progress",
                    "attempts": 3,
                    "last_error": "",
                    "priority": "P0",
                }
            ]
        }
        with tempfile.TemporaryDirectory() as tmp_dir:
            runs_dir = Path(tmp_dir)
            (runs_dir / "coding.md").write_text(
                "# Run Record\n\n"
                "FAST_CODING_EVIDENCE: F123\n"
                "CODING_PASS: F123\n"
            )
            with (
                mock.patch.object(orchestrator, "RUNS_DIR", runs_dir),
                mock.patch.object(orchestrator, "load_state", return_value=data),
                mock.patch.object(orchestrator, "ensure_adapter_configured") as ensure,
                mock.patch.object(orchestrator, "evaluate_fast_feature", return_value=True) as evaluate,
                mock.patch.object(orchestrator, "mark_in_progress") as mark_in_progress,
            ):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertTrue(orchestrator.run_work_fast_round(1, 3, False))
                ensure.assert_called_once()
                self.assertEqual(ensure.call_args.args[0], "Evaluator Agent")
                evaluate.assert_called_once_with("F123", dry_run=False, max_attempts=3)
                mark_in_progress.assert_not_called()


if __name__ == "__main__":
    unittest.main()
