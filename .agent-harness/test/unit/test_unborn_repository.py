import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('startup_orchestrator', ROOT / 'orchestrator.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class StartupHistoryTests(unittest.TestCase):
    def check_startup(self, initialize):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            if initialize:
                subprocess.run(['git', 'init', '-q', td], check=True)
            progress = root / 'progress.md'
            progress.write_text('planning')
            features = root / 'feature_list.json'
            features.write_text('{"features": []}')
            previous = os.getcwd()
            try:
                os.chdir(root)
                with patch.object(m, 'PROGRESS_PATH', progress), patch.object(m, 'FEATURES_PATH', features), patch.object(m, 'sh') as run:
                    if initialize:
                        m.startup_protocol()
                        run.assert_called_once_with(['./init.sh'])
                    else:
                        with self.assertRaises(m.OrchestratorError):
                            m.startup_protocol()
                        run.assert_not_called()
            finally:
                os.chdir(previous)

    def test_unborn_repository_still_runs_init(self):
        self.check_startup(True)

    def test_nonrepository_is_rejected(self):
        self.check_startup(False)
