"""Contract checks on generated real media; generate it before running this suite."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Fixtures/generated'

class FixtureTests(unittest.TestCase):
    def test_manifest_integrity_and_relations(self):
        manifest = json.loads((OUT / 'manifest.json').read_text())
        self.assertEqual(len(manifest['files']), 9)
        for item in manifest['files']:
            self.assertEqual(hashlib.sha256((OUT/item['name']).read_bytes()).hexdigest(), item['sha256'])
        self.assertEqual((OUT/'landscape.jpg').read_bytes(), (OUT/'landscape-copy.jpg').read_bytes())
        self.assertNotEqual((OUT/'portrait-smile.jpg').read_bytes(), (OUT/'portrait-frown.jpg').read_bytes())
        self.assertNotEqual((OUT/'landscape.jpg').read_bytes(), (OUT/'landscape-near.jpg').read_bytes())

    def test_real_video_streams(self):
        data = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(OUT/'clip.mp4')]))
        self.assertEqual({s['codec_type'] for s in data['streams']}, {'video', 'audio'})
        self.assertAlmostEqual(float(data['format']['duration']), 2, delta=0.1)
        self.assertTrue(data['format']['tags']['creation_time'].startswith('2025-09-27T10:05:00'))
