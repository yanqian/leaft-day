import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('selector', ROOT/'scripts/select-simulator.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT/'tests/fixtures/simctl-ios26.json').read_text())

    def test_real_inventory_selects_iphone(self):
        result = m.select_device(self.data)
        self.assertTrue(result['name'].startswith('iPhone'))
        self.assertEqual(result['version'], '26.5')
        self.assertEqual(m.select_device(self.data, result['udid']), result)

    def test_no_runtime_no_device_or_unavailable_fail(self):
        variants = []
        d=copy.deepcopy(self.data);d['runtimes']=[];variants.append(d)
        d=copy.deepcopy(self.data);d['devices']={};variants.append(d)
        d=copy.deepcopy(self.data);d['runtimes'][0]['isAvailable']=False;variants.append(d)
        d=copy.deepcopy(self.data);d['runtimes'][0]['version']='18.0';variants.append(d)
        d=copy.deepcopy(self.data)
        for ds in d['devices'].values():
            for x in ds:x['isAvailable']=False
        variants.append(d)
        for d in variants:
            with self.assertRaises(ValueError):m.select_device(d)

    def test_unknown_schema_or_requested_device_fails(self):
        with self.assertRaises(ValueError):m.select_device({})
        with self.assertRaises(ValueError):m.select_device(self.data,'unknown')
        d=copy.deepcopy(self.data);d['devicetypes']=[]
        with self.assertRaises(ValueError):m.select_device(d)

    def test_invalid_explicit_xcode_is_not_silently_replaced(self):
        import os
        result=subprocess.run([str(ROOT/'scripts/doctor.sh')],env={**os.environ,'DEVELOPER_DIR':'/nonexistent/swipe-xcode'},capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('NOT_READY',result.stderr)
        self.assertNotIn('READY:',result.stdout)
