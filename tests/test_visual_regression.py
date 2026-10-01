import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('visual', ROOT / 'scripts/visual_regression.py')
v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)


class PixelTests(unittest.TestCase):
    def test_identical_tolerance_mask_and_layout_change(self):
        policy = dict(v.DEFAULT_POLICY)
        a = (10, 100, bytes(3000))
        self.assertEqual(v.compare_pixels(a, a, policy)['status'], 'unchanged')
        self.assertEqual(v.compare_pixels(a, (10, 100, bytes([24]) * 3000), policy)['status'], 'unchanged')
        top = bytes([255]) * 150 + bytes(2850)
        self.assertEqual(v.compare_pixels(a, (10, 100, top), policy)['status'], 'unchanged')
        self.assertEqual(v.compare_pixels(a, (10, 100, bytes([255]) * 3000), policy)['status'], 'changed')
        self.assertEqual(v.compare_pixels(a, (20, 50, bytes(3000)), policy)['status'], 'changed')

    def test_native_bmp_shape_padding_and_orientation(self):
        # Real sips output uses BITMAPINFOHEADER, uncompressed 24bit top-down.
        header = bytearray(54); header[:2] = b'BM'; struct.pack_into('<I', header, 10, 54)
        struct.pack_into('<IiiHHI', header, 14, 40, 1, -2, 1, 24, 0)
        self.assertEqual(v.read_bmp(bytes(header) + b'abc\0def\0'), (1, 2, b'abcdef'))
        struct.pack_into('<i', header, 22, 2)
        self.assertEqual(v.read_bmp(bytes(header) + b'abc\0def\0'), (1, 2, b'defabc'))
        with self.assertRaises(ValueError):
            v.read_bmp(bytes(header))
        for p in [{**v.DEFAULT_POLICY, 'ignoreTopFraction': 1}, {**v.DEFAULT_POLICY, 'changedFraction': 1}]:
            with self.assertRaises(ValueError): v.validate_policy(p)

    def test_real_sips_decodes_repo_png(self):
        w, h, data = v.decode(ROOT / 'SwipeGo/Resources/Assets.xcassets/AppIcon.appiconset/LeafDay.png', 64)
        self.assertEqual((w, h, len(data)), (64, 64, 64 * 64 * 3))


class BaselineTests(unittest.TestCase):
    def test_explicit_acceptance_merge_and_failure_rejection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); image = root / 'a.png'; image.write_bytes(b'png')
            item = {'test': 'Suite/test()', 'name': 'screen_0_A89E0670-86BD-4F02-8F51-153DF1DDC446.png', 'path': str(image)}
            report = {'status': 'passed', 'counts': {'result': 'Passed'}, 'attachments': [item]}
            summary = root / 'summary.json'; summary.write_text(json.dumps(report))
            base = root / 'baseline'
            self.assertEqual(v.compare([item], base, root / 'out')['status'], 'not_configured')
            self.assertEqual(v.accept_baseline(summary, base), 1)
            compact = root / 'compact.json'; compact.write_text(json.dumps({**report, 'details': str(summary)}))
            self.assertEqual(v.accept_baseline(compact, base), 1)
            with patch.object(v, 'decode', return_value=(10, 100, bytes(3000))):
                self.assertEqual(v.compare([item], base, root / 'out', complete=True)['status'], 'passed')
                self.assertEqual(v.compare([], base, root / 'out', complete=True)['items'][0]['status'], 'missing')
                self.assertEqual(v.compare([], base, root / 'out')['status'], 'passed')
                self.assertEqual(v.compare([], base, root / 'out', exercised=['Suite/test()'])['status'], 'needs_review')
                new = {**item, 'name': 'new.png'}
                self.assertEqual(v.compare([new], base, root / 'out')['items'][0]['status'], 'new')
                report['attachments'] = [new]; summary.write_text(json.dumps(report)); v.accept_baseline(summary, base)
                self.assertEqual(len(json.loads((base / 'baseline.json').read_text())['images']), 2)
            report['status'] = 'failed'; summary.write_text(json.dumps(report))
            with self.assertRaises(ValueError): v.accept_baseline(summary, base)
            data = json.loads((base / 'baseline.json').read_text())
            (base / next(iter(data['images'].values()))['file']).write_bytes(b'corrupt')
            with self.assertRaises(ValueError): v.compare([item], base, root / 'out')

    def test_duplicate_semantic_names_fail(self):
        item = {'test': 'Suite/test()', 'name': 'screen.png', 'path': '/tmp/screen.png'}
        with self.assertRaises(ValueError): v.screenshots([item, item])


if __name__ == '__main__': unittest.main()
