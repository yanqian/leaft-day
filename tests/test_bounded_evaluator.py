import subprocess
import sys
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/run-bounded-evaluator.py'

class BoundedEvaluatorTests(unittest.TestCase):
    def test_preserves_prompt_output_and_exit_code(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--timeout-seconds', '5', '--', sys.executable, '-c', 'import sys; print(sys.stdin.read()); raise SystemExit(7)'], input='role prompt', text=True, capture_output=True)
        self.assertEqual(result.returncode, 7)
        self.assertIn('role prompt', result.stdout)

    def test_timeout_has_no_fabricated_verdict(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--timeout-seconds', '0.1', '--', sys.executable, '-c', 'import time; time.sleep(10)'], text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 124)
        self.assertIn('EVALUATOR_TIMEOUT', result.stderr)
        self.assertNotIn('EVAL_PASS', result.stdout)

class DescendantCleanupTests(unittest.TestCase):
    def test_exiting_leader_cannot_leave_ignoring_descendant_on_timeout_or_interrupt(self):
        import os, signal, tempfile, time
        for interrupt in (False, True):
            with self.subTest(interrupt=interrupt), tempfile.TemporaryDirectory() as tmp:
                heartbeat = Path(tmp) / 'heartbeat'
                child = f'import signal,time; from pathlib import Path; signal.signal(signal.SIGTERM,signal.SIG_IGN); print("ready",flush=True); time.sleep(2); Path({str(heartbeat)!r}).write_text("alive"); time.sleep(30)'
                leader = f'import subprocess,sys,time; p=subprocess.Popen([sys.executable,"-c",{child!r}],stdout=subprocess.PIPE,text=True); p.stdout.readline(); print(p.pid,flush=True); time.sleep(30)'
                process = subprocess.Popen([sys.executable, str(SCRIPT), '--timeout-seconds', '20' if interrupt else '1', '--', sys.executable, '-c', leader], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                pid = None
                try:
                    pid = int(process.stdout.readline().strip())
                    if interrupt: process.send_signal(signal.SIGTERM)
                    self.assertEqual(process.wait(timeout=5), 130 if interrupt else 124)
                    time.sleep(2.2)
                    self.assertFalse(heartbeat.exists(), 'descendant kept executing after wrapper exit')
                finally:
                    if pid:
                        try: os.kill(pid, signal.SIGKILL)
                        except ProcessLookupError: pass
                    if process.poll() is None: process.kill(); process.wait()
                    process.stdout.close(); process.stderr.close()

    def test_verification_runner_uses_same_descendant_cleanup(self):
        import importlib.util, os, signal, tempfile, time
        root = SCRIPT.parents[1]
        spec = importlib.util.spec_from_file_location('runner_cleanup', root / 'scripts/verification.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp); heartbeat = out / 'heartbeat'; pidfile = out / 'pid'
            child = f'import signal,time; from pathlib import Path; signal.signal(signal.SIGTERM,signal.SIG_IGN); print("ready",flush=True); time.sleep(2); Path({str(heartbeat)!r}).write_text("alive"); time.sleep(30)'
            leader = f'import subprocess,sys,time; from pathlib import Path; p=subprocess.Popen([sys.executable,"-c",{child!r}],stdout=subprocess.PIPE,text=True); p.stdout.readline(); Path({str(pidfile)!r}).write_text(str(p.pid)); time.sleep(30)'
            try:
                with self.assertRaises(subprocess.TimeoutExpired):
                    module.Runner(out, {'steps': []}).run('timeout', [sys.executable, '-c', leader], timeout=1)
                self.assertTrue(pidfile.exists(), 'probe must reach descendant readiness')
                time.sleep(2.2)
                self.assertFalse(heartbeat.exists())
            finally:
                if pidfile.exists():
                    try: os.kill(int(pidfile.read_text()), signal.SIGKILL)
                    except ProcessLookupError: pass
