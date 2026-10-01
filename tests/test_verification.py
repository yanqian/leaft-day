"""Contracts use xcresulttool output captured from real Xcode 26 test bundles."""
import copy
import contextlib
import io
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('verification', ROOT / 'scripts/verification.py')
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
FIXTURES = ROOT / 'tests/fixtures'


def fixture(name):
    return json.loads((FIXTURES / name).read_text())


class SelectionTests(unittest.TestCase):
    def test_source_edit_during_preparation_rejected_but_generated_outputs_allowed(self):
        v.verify_preparation_inputs({'a.swift': 'one'}, {'a.swift': 'one', 'Fixtures/generated/manifest.json': 'new'})
        with self.assertRaises(RuntimeError):
            v.verify_preparation_inputs({'a.swift': 'one'}, {'a.swift': 'two'})
        with self.assertRaises(RuntimeError):
            v.verify_preparation_inputs({}, {'scripts/verification.py': 'new'})

    def test_page_mapping_always_keeps_unit_and_launch_smoke(self):
        cases, why = v.select_tests(['SwipeGo/Features/Permissions/PhotoAccessWelcomeView.swift'])
        self.assertIn('SwipeGoTests', cases)
        self.assertIn('SwipeGoUITests/LaunchTests', cases)
        self.assertIn('SwipeGoUITests/PermissionTests', cases)
        self.assertIn('SwipeGoUITests/WelcomeGlassTests', cases)
        self.assertTrue(why.startswith('changed:'))

    def test_shared_unknown_and_deleted_ui_fall_back_full(self):
        for path in ['SwipeGo/DesignSystem/RecollectionGlass.swift', 'project.yml', 'scripts/verification.py',
                     'NewConfig.json', 'SwipeGoUITests/DeletedTests.swift', 'SwipeGo/Domain/LocalState.swift']:
            self.assertEqual(v.select_tests([path])[0], [], path)

    def test_test_change_runs_that_suite_and_docs_do_not_expand(self):
        cases, _ = v.select_tests(['SwipeGoUITests/WelcomeGlassTests.swift', 'docs/verification.md'])
        self.assertEqual(set(cases), {'SwipeGoTests', 'SwipeGoUITests/LaunchTests', 'SwipeGoUITests/WelcomeGlassTests'})
        self.assertEqual(len(v.select_tests([])[0]), 2)

    def test_diff_includes_staged_unstaged_untracked_deleted_and_both_rename_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.DEVNULL)
            git('init')
            for n in ['staged', 'unstaged', 'deleted', 'renamed']:
                (root / n).write_text('before')
            git('add', '.')
            git('-c', 'user.name=Contract', '-c', 'user.email=contract@example.invalid', 'commit', '-m', 'fixture')
            (root / 'staged').write_text('after'); git('add', 'staged')
            (root / 'unstaged').write_text('after')
            (root / 'deleted').unlink()
            git('mv', 'renamed', 'new-name')
            (root / 'untracked').write_text('new')
            self.assertEqual(set(v.changed_files('HEAD', root)), {'staged', 'unstaged', 'deleted', 'renamed', 'new-name', 'untracked'})
            with self.assertRaises(subprocess.CalledProcessError):
                v.changed_files('nonexistent-ref', root)
            with self.assertRaises(subprocess.CalledProcessError):
                v.changed_files('--cached', root)


class ResultTests(unittest.TestCase):
    def test_real_success_failure_and_test_coverage(self):
        self.assertEqual(v.require_pass(fixture('xcresult-summary-passed.json'))['passedTests'], 129)
        failed = v.parse_summary(fixture('xcresult-summary-failed.json'))
        self.assertEqual(failed['failedTests'], 1)
        self.assertIn('LaunchTests/', failed['testFailures'][0]['testIdentifierString'])
        with self.assertRaises(ValueError):
            v.require_pass(fixture('xcresult-summary-failed.json'))
        cases = v.parse_tests(fixture('xcresult-tests.json'))
        self.assertEqual(len(cases), 129)
        self.assertEqual(sum(c['id'].startswith('SwipeGoTests/') for c in cases), 85)
        v.verify_coverage(cases, [])
        with self.assertRaises(ValueError):
            v.verify_coverage(cases, ['SwipeGoUITests/DoesNotExist'])

    def test_empty_malformed_inconsistent_and_skipped_fail_closed(self):
        good = fixture('xcresult-summary-passed.json')
        bads = [{}, {**good, 'passedTests': '129'}, {**good, 'totalTestCount': 0},
                {**good, 'passedTests': 128, 'skippedTests': 1},
                {**good, 'passedTests': 0, 'skippedTests': 129}, {**good, 'result': 'Unknown'}]
        for bad in bads:
            with self.assertRaises(ValueError):
                v.require_pass(bad)
        for tree in [{}, {'testNodes': []}, {'testNodes': [{'nodeType': 'Test Case', 'nodeIdentifierURL': 'unknown'}]}]:
            with self.assertRaises(ValueError):
                v.parse_tests(tree)

    def test_real_attachments_associate_test_and_validate_files(self):
        data = fixture('xcresult-attachments.json')
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(ValueError):
                v.attachments(data, root)
            for item in data[0]['attachments']:
                (root / item['exportedFileName']).write_bytes(b'fixture')
            items = v.attachments(data, root)
            self.assertEqual(len(items), 2)
            self.assertIn('LaunchTests/', items[1]['test'])
            bad = copy.deepcopy(data); bad[0]['attachments'][0]['exportedFileName'] = '../outside'
            with self.assertRaises(ValueError):
                v.attachments(bad, root)


class ReuseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.now = time.time()
        artifacts = {}
        for key in ['app', 'result', 'preflight', 'summary', 'tree', 'buildLog', 'testLog', 'permissionLog', 'attachments']:
            path = self.root / key
            value = fixture('xcresult-summary-passed.json') if key == 'summary' else fixture('xcresult-tests.json') if key == 'tree' else {'fixture': key}
            if key == 'attachments':
                path.mkdir(); (path / 'manifest.json').write_text('[]')
            else:
                path.write_text(json.dumps(value))
            artifacts[key] = {'path': str(path), 'sha256': v.tree_digest(path)}
        self.fp = {'sources': {'app.swift': 'hash'}, 'environment': {'simulator': 'one'}}
        self.receipt = {'version': v.VERSION, 'status': 'passed', 'mode': 'full', 'fingerprint': self.fp,
                        'finishedAt': self.now - 20, 'artifacts': artifacts, 'counts': v.parse_summary(fixture('xcresult-summary-passed.json')),
                        'resultBundle': str(self.root / 'result'), 'attachments': []}

    def test_only_intact_matching_recent_full_can_be_reused(self):
        self.assertTrue(v.reusable(self.receipt, self.fp, self.now))
        for field, value in [('status', 'failed'), ('mode', 'changed'), ('version', 999),
                             ('reusedFrom', 'old'), ('finishedAt', self.now - v.MAX_AGE - 1), ('finishedAt', self.now + 1)]:
            self.assertFalse(v.reusable({**self.receipt, field: value}, self.fp, self.now), field)
        for fp in [{'sources': {'app.swift': 'new'}}, {**self.fp, 'environment': {'simulator': 'two'}}]:
            self.assertFalse(v.reusable(self.receipt, fp, self.now))
        bad = copy.deepcopy(self.receipt); del bad['artifacts']['preflight']
        self.assertFalse(v.reusable(bad, self.fp, self.now))

    def test_missing_or_modified_app_result_or_logs_invalidate(self):
        for name in ['app', 'result', 'buildLog', 'attachments']:
            path = self.root / name
            if path.is_dir(): path = path / 'manifest.json'
            old = path.read_bytes(); path.write_bytes(b'changed')
            self.assertFalse(v.reusable(self.receipt, self.fp, self.now), name)
            path.write_bytes(old)
        (self.root / 'result').unlink()
        self.assertFalse(v.reusable(self.receipt, self.fp, self.now))

    def test_failure_summary_even_with_updated_digest_is_not_reused(self):
        path = self.root / 'summary'; path.write_text(json.dumps(fixture('xcresult-summary-failed.json')))
        self.receipt['artifacts']['summary']['sha256'] = v.digest(path)
        self.assertFalse(v.reusable(self.receipt, self.fp, self.now))

    def test_tree_hash_detects_extra_and_removed_files_and_modes(self):
        tree = self.root / 'bundle'; tree.mkdir(); (tree / 'a').write_text('a')
        before = v.tree_digest(tree)
        (tree / 'b').write_text('b'); self.assertNotEqual(before, v.tree_digest(tree))
        (tree / 'b').unlink(); self.assertEqual(before, v.tree_digest(tree))
        (tree / 'a').chmod(0o755); self.assertNotEqual(before, v.tree_digest(tree))


class ExecutionTests(unittest.TestCase):
    def test_command_failure_and_timeout_retain_diagnostics(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = {'steps': []}; runner = v.Runner(Path(tmp), report)
            with self.assertRaises(RuntimeError):
                runner.run('fail', ['python3', '-c', 'print("failure detail"); raise SystemExit(7)'])
            self.assertEqual(report['steps'][0]['exitCode'], 7)
            self.assertIn('failure detail', Path(report['steps'][0]['log']).read_text())
            with self.assertRaises(subprocess.TimeoutExpired):
                runner.run('timeout', ['python3', '-c', 'import time; time.sleep(10)'], timeout=0.05)
            self.assertLess(report['steps'][1]['exitCode'], 0)

    def test_invalid_environment_still_writes_failed_summary(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(v, 'ROOT', Path(tmp)), patch.dict(os.environ, {'SWIPE_VERIFICATION_MODE': 'invalid'}):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(v.main(['--full']), 1)
            pointer = json.loads((Path(tmp) / '.build/verification/latest.json').read_text())
            summary = json.loads(Path(pointer['report']).read_text())
            self.assertEqual(summary['status'], 'failed')
            self.assertTrue(Path(pointer['report']).with_name('report.md').exists())

    def test_lock_rejects_concurrent_execution_without_mutating_receipt(self):
        import fcntl
        with tempfile.TemporaryDirectory() as tmp, patch.object(v, 'ROOT', Path(tmp)):
            directory = Path(tmp) / '.build/verification'; directory.mkdir(parents=True)
            pointer = directory / 'latest-full.json'; pointer.write_text('preserve')
            with (directory / 'run.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(v.main(['--full']), 1)
            self.assertEqual(pointer.read_text(), 'preserve')
            reports = list(directory.glob('*/summary.json'))
            self.assertIn('lock', json.loads(reports[0].read_text())['error'])



class CompactReportTests(unittest.TestCase):
    def test_default_report_is_compact_and_details_are_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report = {'version': 1, 'status': 'passed', 'mode': 'full', 'seconds': 10,
                      'steps': [], 'counts': v.parse_summary(fixture('xcresult-summary-passed.json')),
                      'fingerprint': {'sources': {'big': 'hash'}}, 'cases': ['details'],
                      'attachments': [], 'visual': {'status': 'not_configured'}}
            v.write_report(root, report)
            compact = json.loads((root / 'summary.json').read_text())
            self.assertNotIn('fingerprint', compact)
            self.assertNotIn('cases', compact)
            self.assertEqual(compact['counts']['passedTests'], 129)
            details = json.loads(Path(compact['details']).read_text())
            self.assertEqual(details['fingerprint'], report['fingerprint'])
            self.assertLess((root / 'summary.json').stat().st_size, 2500)
            self.assertTrue((root / 'evidence.md').exists())

    def test_fresh_evaluator_and_custom_toolchains_never_reuse(self):
        from types import SimpleNamespace
        args = SimpleNamespace(reuse=True, fresh=False)
        self.assertTrue(v.reuse_allowed(args, {}))
        for key, value in [('SWIPE_VERIFY_FRESH', '1'), ('SWIPE_VERIFICATION_MODE', 'device'),
                           ('XCODE_XCCONFIG_FILE', 'external.xcconfig'), ('SWIFT_EXEC', '/external/swift')]:
            self.assertFalse(v.reuse_allowed(args, {key: value}))
        args.fresh = True
        self.assertFalse(v.reuse_allowed(args, {}))


class RepairContracts(unittest.TestCase):
    def test_irrelevant_path_prefix_does_not_change_tool_identity_but_shadow_does(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); tools = root / 'tools'; alias = root / 'provider-alias'; tools.mkdir(); alias.mkdir()
            executable = tools / 'python3'; executable.write_text('#!/bin/sh\nexit 0\n'); executable.chmod(0o755)
            expected = v.tool_identities(str(tools))
            self.assertEqual(expected, v.tool_identities(str(alias) + os.pathsep + str(tools)))
            shadow = alias / 'python3'; shadow.write_text('#!/bin/sh\nexit 1\n'); shadow.chmod(0o755)
            self.assertNotEqual(expected, v.tool_identities(str(alias) + os.pathsep + str(tools)))
            executable.write_text('#!/bin/sh\nexit 2\n')
            self.assertNotEqual(expected, v.tool_identities(str(tools)))

    def test_all_failed_preflight_keeps_counts_and_exports_before_rejection(self):
        raw = fixture('xcresult-summary-failed.json')
        raw.update(totalTestCount=1, passedTests=0, failedTests=1)
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp); calls = []
            class FakeRunner:
                def run(self, phase, argv):
                    calls.append(phase)
                    out = Path(argv[argv.index('--output-path') + 1]); out.mkdir()
                    (out / 'failure.png').write_bytes(b'fixture')
                    (out / 'manifest.json').write_text(json.dumps([{'testIdentifier': 'PermissionTests/failure()', 'attachments': [{'exportedFileName': 'failure.png'}]}]))
                def capture(self, phase, argv):
                    calls.append(phase); return json.dumps(raw)
            report = {'version': 1, 'status': 'failed', 'steps': [], 'seconds': 0}
            result, _ = v.collect_result(FakeRunner(), 'permission', directory / 'test.xcresult', directory, report)
            self.assertEqual(report['preflightCounts']['failedTests'], 1)
            self.assertEqual(len(report['attachments']), 1)
            self.assertEqual(calls, ['permission-attachments', 'permission-summary'])
            with self.assertRaises(ValueError): v.require_pass(result)
            v.write_report(directory, report)
            self.assertIn('Permission preflight: 0 passed / 1 failed', (directory / 'report.md').read_text())
            self.assertIn('XCTAssertTrue failed', (directory / 'report.md').read_text())


if __name__ == '__main__':
    unittest.main()
