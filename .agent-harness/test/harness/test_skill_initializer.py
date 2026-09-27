import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INIT_SCRIPT = ROOT / "skills" / "ai-agent-harness" / "scripts" / "init_harness.py"
TEMPLATE_VERSION = json.loads((ROOT / ".agent-harness-template.json").read_text())["template_version"]


def run_initializer(project: Path, mode: str, *extra: str):
    return subprocess.run(
        [
            sys.executable,
            str(INIT_SCRIPT),
            "--root",
            str(project),
            "--template-root",
            str(ROOT),
            "--mode",
            mode,
            *extra,
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )


def run_initializer_with_template(project: Path, template: Path, mode: str, *extra: str):
    return subprocess.run(
        [
            sys.executable,
            str(INIT_SCRIPT),
            "--root",
            str(project),
            "--template-root",
            str(template),
            "--mode",
            mode,
            *extra,
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )


def run_project_init(project: Path):
    return subprocess.run(
        [str(project / "init.sh")],
        cwd=project,
        text=True,
        capture_output=True,
        env={**os.environ, "HARNESS_SKIP_TEST_LAYERS": "1"},
    )


def run_installed_contract_tests(project: Path):
    return subprocess.run(
        [sys.executable, "-m", "unittest", "discover", "-s", "test/contract"],
        cwd=project / ".agent-harness",
        text=True,
        capture_output=True,
    )


class SkillInitializerHarnessTests(unittest.TestCase):
    EXECUTABLE_PATHS = [
        "init.sh",
        ".agent-harness/scripts/check-evaluator-evidence.sh",
        ".agent-harness/init.sh",
        ".agent-harness/scripts/check-failure-domains.sh",
        ".agent-harness/scripts/init.sh",
        ".agent-harness/scripts/run-coding-agent.sh",
        ".agent-harness/scripts/run-evaluator-agent.sh",
        ".agent-harness/scripts/summarize-progress.sh",
        ".agent-harness/scripts/summarize-runs.sh",
        ".agent-harness/scripts/validate-feature.sh",
    ]

    def test_fresh_project_handoff_in_both_layouts(self):
        import re
        for mode in ("new", "adopt"):
            for layout in ("hidden", "visible"):
                with self.subTest(mode=mode, layout=layout), tempfile.TemporaryDirectory() as tmp:
                    project = Path(tmp)
                    (project / "product-notes.md").write_text("Existing product requirements\n")
                    result = run_initializer(project, mode, "--layout", layout)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    harness = project / ".agent-harness" if layout == "hidden" else project
                    spec = (harness / "SPEC.md").read_text()
                    self.assertTrue(spec.startswith("# Project SPEC\n"))
                    for heading in ("Goal", "Scope included", "Scope excluded", "Core flows", "Constraints",
                                    "Ambiguities or assumptions", "Required capabilities", "Implementation paths",
                                    "Verification surface", "Feature decomposition"):
                        self.assertIn("## " + heading, spec)
                    for link in re.findall(r"\]\(([^)]+)\)", spec):
                        self.assertTrue((harness / link).is_file(), link)
                    self.assertNotIn("Synchronize template version", spec)
                    self.assertNotIn("F043", spec)
                    self.assertIn("not been accepted yet", spec)
                    self.assertEqual(json.loads((harness / "feature_list.json").read_text()), {"features": []})
                    self.assertIn("F001", (harness / "progress.md").read_text())
                    self.assertEqual({p.name for p in (harness / "runs").iterdir()}, {"RUN_TEMPLATE.md", ".gitkeep"})
                    self.assertEqual((project / "product-notes.md").read_text(), "Existing product requirements\n")
                    self.assertIn("start at F001", (harness / "prompts/plan.md").read_text())
                    contracts = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "test/contract"],
                                               cwd=harness, capture_output=True, text=True)
                    self.assertEqual(contracts.returncode, 0, contracts.stdout + contracts.stderr)

    def test_existing_project_state_survives_all_lifecycle_modes(self):
        for layout in ("hidden", "visible"):
            with self.subTest(layout=layout), tempfile.TemporaryDirectory() as tmp:
                project = Path(tmp)
                harness = project / ".agent-harness" if layout == "hidden" else project
                harness.mkdir(exist_ok=True)
                # Preserve existing requirements even before an installation manifest exists.
                (harness / "SPEC.md").write_text("# Existing project SPEC\nUser-owned scope.\n")
                result = run_initializer(project, "adopt", "--layout", layout)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((harness / "SPEC.md").read_text(), "# Existing project SPEC\nUser-owned scope.\n")
                state = {"features": [{"id": "F044", "title": "Existing", "description": "Keep",
                         "acceptance": ["Keep"], "passes": False, "status": "todo", "attempts": 2,
                         "last_error": "keep", "custom": {"history": [1, 2]}}], "custom": True}
                (harness / "feature_list.json").write_text(json.dumps(state))
                (harness / "progress.md").write_text("# Progress\n## Current System Status\nExisting\n## Next Feature\nF044\n## Known Issues\nNone\n")
                (harness / "runs" / "existing.txt").write_text("Existing evidence\n")
                paths = [harness / p for p in ("SPEC.md", "feature_list.json", "progress.md", "runs/existing.txt")]
                before = {p: p.read_bytes() for p in paths}
                for mode in ("new", "adopt", "repair", "upgrade"):
                    for flags in ((), ("--force",)):
                        result = run_initializer(project, mode, "--layout", layout, *flags)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertEqual({p: p.read_bytes() for p in paths}, before)

    def test_repair_missing_state_uses_fresh_scaffolds(self):
        for layout in ("hidden", "visible"):
            with self.subTest(layout=layout), tempfile.TemporaryDirectory() as tmp:
                project = Path(tmp)
                self.assertEqual(run_initializer(project, "new", "--layout", layout).returncode, 0)
                harness = project / ".agent-harness" if layout == "hidden" else project
                for rel in ("SPEC.md", "feature_list.json", "progress.md"):
                    (harness / rel).unlink()
                repaired = run_initializer(project, "repair", "--layout", layout)
                self.assertEqual(repaired.returncode, 0, repaired.stdout + repaired.stderr)
                self.assertTrue((harness / "SPEC.md").read_text().startswith("# Project SPEC"))
                self.assertEqual(json.loads((harness / "feature_list.json").read_text()), {"features": []})
                self.assertIn("F001", (harness / "progress.md").read_text())

    def test_dry_run_does_not_create_target_or_execute_project_init(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp) / "absent"
            result = run_initializer(project, "new", "--dry-run")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse(project.exists())
            self.assertEqual(run_initializer(project, "new").returncode, 0)
            (project / "init.sh").write_text("#!/bin/sh\ntouch must-not-exist\n")
            before = {str(p.relative_to(project)): p.read_bytes() for p in project.rglob("*") if p.is_file()}
            result = run_initializer(project, "adopt", "--dry-run")
            after = {str(p.relative_to(project)): p.read_bytes() for p in project.rglob("*") if p.is_file()}
            self.assertEqual(after, before)
            self.assertFalse((project / "must-not-exist").exists())

    def test_new_mode_creates_runnable_harness_and_clean_check(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            result = run_initializer(project, "new")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("mode=new", result.stdout)
            self.assertIn("layout=hidden", result.stdout)
            self.assertIn("state_valid=true", result.stdout)
            self.assertIn("runnable_harness=true", result.stdout)
            self.assertIn("state_reset=.agent-harness/feature_list.json,.agent-harness/progress.md", result.stdout)
            provider_example = json.loads((project / ".agent-harness" / "agent-provider.example.json").read_text())
            self.assertEqual(provider_example["providers"]["codex"]["cwd"], "..")
            self.assertIn("provider `cwd` set to `..`", (project / "AGENTS.md").read_text())

            data = json.loads((project / ".agent-harness" / "feature_list.json").read_text())
            self.assertEqual(data, {"features": []})
            manifest = json.loads((project / ".agent-harness" / "manifest.json").read_text())
            self.assertEqual(manifest["template_version"], TEMPLATE_VERSION)
            self.assertEqual(manifest["layout"], "hidden")
            self.assertIn("category", manifest["files"][".agent-harness/scripts/validate-state.py"])
            self.assertTrue((project / "AGENTS.md").exists())
            self.assertTrue((project / "init.sh").exists())
            self.assertTrue((project / ".agent-harness" / "docs" / "project-recovery-init.md").exists())
            self.assertTrue((project / ".agent-harness" / "docs" / "spec-normalization.md").exists())
            self.assertFalse((project / ".agent-harness" / "skills" / "ai-agent-harness" / "assets").exists())
            self.assertIn("project recovery contract", (project / "AGENTS.md").read_text())
            self.assertIn("Spec Normalization", (project / "AGENTS.md").read_text())
            self.assertIn("make -C .agent-harness work", (project / "AGENTS.md").read_text())
            self.assertIn("missing root `Makefile`", (project / "AGENTS.md").read_text())
            self.assertIn("Pre-minspec state", (project / "init.sh").read_text())
            self.assertIn(
                "root `./init.sh` may only verify the harness",
                (project / ".agent-harness" / "docs" / "project-recovery-init.md").read_text(),
            )
            self.assertIn(
                "Required Fields",
                (project / ".agent-harness" / "docs" / "spec-normalization.md").read_text(),
            )
            self.assertIn(
                "Reject vague requirements",
                (project / ".agent-harness" / "prompts" / "plan.md").read_text(),
            )
            for rel in self.EXECUTABLE_PATHS:
                self.assertTrue(os.access(project / rel, os.X_OK), f"{rel} should be executable")
            self.assertFalse((project / "feature_list.json").exists())
            self.assertFalse((project / "scripts").exists())

            init = run_project_init(project)
            self.assertEqual(init.returncode, 0, init.stderr)

            check = run_initializer(project, "check")
            self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            self.assertIn("layout=hidden", check.stdout)
            self.assertIn(f"template_version={TEMPLATE_VERSION}", check.stdout)
            self.assertIn(f"installed_version={TEMPLATE_VERSION}", check.stdout)
            self.assertIn("state_valid=true", check.stdout)
            self.assertIn("runnable_harness=true", check.stdout)
            self.assertIn("project_state_changed=", check.stdout)
            self.assertIn("next_action=harness is installed and runnable", check.stdout)

    def test_hidden_layout_repairs_executable_bits_when_template_modes_are_lost(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp = Path(tmp_dir)
            template = tmp / "template"
            project = tmp / "project"
            shutil.copytree(
                ROOT,
                template,
                ignore=shutil.ignore_patterns(".git", "__pycache__", ".pytest_cache"),
            )
            for rel in [
                "init.sh",
                "scripts/check-evaluator-evidence.sh",
                "scripts/check-failure-domains.sh",
                "scripts/init.sh",
                "scripts/run-coding-agent.sh",
                "scripts/run-evaluator-agent.sh",
                "scripts/summarize-progress.sh",
                "scripts/summarize-runs.sh",
                "scripts/validate-feature.sh",
            ]:
                (template / rel).chmod(0o644)

            result = run_initializer_with_template(project, template, "new")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("state_valid=true", result.stdout)
            self.assertIn("runnable_harness=true", result.stdout)
            for rel in self.EXECUTABLE_PATHS:
                self.assertTrue(os.access(project / rel, os.X_OK), f"{rel} should be executable")
            init = run_project_init(project)
            self.assertEqual(init.returncode, 0, init.stderr)

    def test_visible_layout_remains_available_for_harness_development(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            result = run_initializer(project, "new", "--layout", "visible")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("layout=visible", result.stdout)
            self.assertIn("state_reset=feature_list.json,progress.md", result.stdout)
            self.assertTrue((project / "feature_list.json").exists())
            self.assertTrue((project / "scripts" / "init.sh").exists())
            self.assertTrue((project / "prompts" / "work.md").exists())
            manifest = json.loads((project / ".agent-harness" / "manifest.json").read_text())
            self.assertEqual(manifest["layout"], "visible")

    def test_adopt_mode_does_not_overwrite_merge_sensitive_files_by_default(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            (project / "README.md").write_text("existing readme\n")
            (project / "AGENTS.md").write_text("existing agent rules\n")

            result = run_initializer(project, "adopt")
            self.assertEqual(result.returncode, 1)
            self.assertIn("blocking_conflicts:", result.stdout)
            self.assertIn("AGENTS.md", result.stdout)
            self.assertEqual((project / "README.md").read_text(), "existing readme\n")
            self.assertEqual((project / "AGENTS.md").read_text(), "existing agent rules\n")
            self.assertFalse((project / ".agent-harness" / "manifest.json").exists())
            self.assertFalse((project / ".agent-harness" / "feature_list.json").exists())

            forced = run_initializer(project, "adopt", "--force")
            self.assertEqual(forced.returncode, 0, forced.stderr)
            self.assertIn("overwritten=1", forced.stdout)
            self.assertEqual((project / "README.md").read_text(), "existing readme\n")
            self.assertNotEqual((project / "AGENTS.md").read_text(), "existing agent rules\n")

    def test_repair_restores_missing_harness_files_and_preserves_project_state(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            initial = run_initializer(project, "new")
            self.assertEqual(initial.returncode, 0, initial.stderr)

            custom_features = {
                "features": [
                    {
                        "id": "F999",
                        "title": "Custom project feature",
                        "description": "Project-owned feature state must survive repair.",
                        "acceptance": ["state remains intact"],
                        "passes": False,
                        "status": "todo",
                        "attempts": 7,
                        "last_error": "keep me",
                    }
                ]
            }
            (project / ".agent-harness" / "feature_list.json").write_text(json.dumps(custom_features, indent=2) + "\n")
            (project / ".agent-harness" / "progress.md").write_text(
                "# Progress\n\n"
                "## Current System Status\n\ncustom\n\n"
                "## Last Completed Feature\n\nNone.\n\n"
                "## Next Feature\n\nF999\n\n"
                "## Known Issues\n\nNone.\n"
            )
            (project / ".agent-harness" / "scripts" / "validate-state.py").unlink()
            (project / ".agent-harness" / "prompts" / "work.md").unlink()

            repaired = run_initializer(project, "repair")
            self.assertEqual(repaired.returncode, 0, repaired.stdout + repaired.stderr)
            self.assertIn("mode=repair", repaired.stdout)
            self.assertIn("created=2", repaired.stdout)
            self.assertTrue((project / ".agent-harness" / "scripts" / "validate-state.py").exists())
            self.assertTrue((project / ".agent-harness" / "prompts" / "work.md").exists())
            self.assertEqual(json.loads((project / ".agent-harness" / "feature_list.json").read_text()), custom_features)
            self.assertIn("F999", (project / ".agent-harness" / "progress.md").read_text())

    def test_upgrade_updates_installed_harness_and_preserves_project_state(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            initial = run_initializer(project, "new")
            self.assertEqual(initial.returncode, 0, initial.stderr)

            custom_features = {
                "features": [
                    {
                        "id": "F123",
                        "title": "Existing project feature",
                        "description": "Upgrade must preserve project-owned state.",
                        "acceptance": ["state remains intact"],
                        "passes": False,
                        "status": "todo",
                        "attempts": 3,
                        "last_error": "keep",
                    }
                ]
            }
            custom_progress = (
                "# Progress\n\n"
                "## Current System Status\n\ncustom\n\n"
                "## Last Completed Feature\n\nNone.\n\n"
                "## Next Feature\n\nF123\n\n"
                "## Known Issues\n\nNone.\n"
            )
            custom_spec = "# Project SPEC\n\nProject-owned requirements replace template-specific SPEC prose.\n"
            custom_init = "#!/usr/bin/env bash\nset -euo pipefail\necho project recovery\n"
            (project / ".agent-harness" / "SPEC.md").write_text(custom_spec)
            (project / ".agent-harness" / "feature_list.json").write_text(json.dumps(custom_features, indent=2) + "\n")
            (project / ".agent-harness" / "progress.md").write_text(custom_progress)
            (project / "init.sh").write_text(custom_init)
            (project / "init.sh").chmod(0o755)

            manifest_path = project / ".agent-harness" / "manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["template_version"] = "0.0.0"
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
            (project / ".agent-harness" / "Makefile").write_text("old makefile without work-fast\n")
            (project / ".agent-harness" / "scripts" / "validate-state.py").write_text("old static drift\n")
            (project / ".agent-harness" / "prompts" / "work-fast.md").unlink()
            obsolete = project / ".agent-harness" / "skills" / "ai-agent-harness" / "assets" / "template"
            obsolete.mkdir(parents=True)
            (obsolete / "stale.txt").write_text("stale nested template\n")

            check = run_initializer(project, "check")
            self.assertEqual(check.returncode, 1)
            self.assertIn("installed_version=0.0.0", check.stdout)
            self.assertIn("run upgrade", check.stdout)

            upgraded = run_initializer(project, "upgrade")
            self.assertEqual(upgraded.returncode, 0, upgraded.stdout + upgraded.stderr)
            self.assertIn("mode=upgrade", upgraded.stdout)
            self.assertIn("overwritten=", upgraded.stdout)
            self.assertIn("removed=1", upgraded.stdout)
            self.assertIn("work-fast:", (project / ".agent-harness" / "Makefile").read_text())
            self.assertTrue((project / ".agent-harness" / "prompts" / "work-fast.md").exists())
            self.assertNotIn("old static drift", (project / ".agent-harness" / "scripts" / "validate-state.py").read_text())
            self.assertEqual((project / ".agent-harness" / "SPEC.md").read_text(), custom_spec)
            self.assertEqual(json.loads((project / ".agent-harness" / "feature_list.json").read_text()), custom_features)
            self.assertEqual((project / ".agent-harness" / "progress.md").read_text(), custom_progress)
            self.assertEqual((project / "init.sh").read_text(), custom_init)
            self.assertFalse((project / ".agent-harness" / "skills" / "ai-agent-harness" / "assets").exists())
            upgraded_manifest = json.loads(manifest_path.read_text())
            self.assertEqual(upgraded_manifest["template_version"], TEMPLATE_VERSION)
            self.assertEqual(upgraded_manifest["mode"], "upgrade")
            contracts = run_installed_contract_tests(project)
            self.assertEqual(contracts.returncode, 0, contracts.stdout + contracts.stderr)

    def test_check_reports_complete_diagnostics_and_version_drift(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            project = Path(tmp_dir)
            initial = run_initializer(project, "new")
            self.assertEqual(initial.returncode, 0, initial.stderr)

            manifest_path = project / ".agent-harness" / "manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["template_version"] = "0.0.0"
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
            (project / ".agent-harness" / "scripts" / "validate-state.py").write_text("local static drift\n")
            (project / "AGENTS.md").write_text("local merge-sensitive change\n")

            check = run_initializer(project, "check")
            self.assertEqual(check.returncode, 1)
            for phrase in [
                "mode=check",
                f"template_version={TEMPLATE_VERSION}",
                "installed_version=0.0.0",
                "state_valid=false",
                "runnable_harness=false",
                "missing=0",
                "conflicts=1",
                "drift=1",
                "project_state_changed=",
                "optional_changed=0",
                "state_errors:",
                "next_action=review merge-sensitive conflicts; run upgrade",
            ]:
                self.assertIn(phrase, check.stdout)


if __name__ == "__main__":
    unittest.main()
