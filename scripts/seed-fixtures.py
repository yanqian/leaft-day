#!/usr/bin/env python3
"""Generate deterministic synthetic media; optionally import into a NEW owned simulator."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Fixtures' / 'generated'

def run(*args, capture=False):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE if capture else None).stdout

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed', type=int, default=27)
    parser.add_argument('--install', action='store_true', help='Create a fresh, isolated fixture simulator. Never import to user-selected devices.')
    args = parser.parse_args()
    if not 0 <= args.seed <= 99:
        parser.error('seed must be in 0...99')
    os.environ.setdefault('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer')
    for tool in ['swift', 'ffmpeg', 'ffprobe']:
        if not shutil.which(tool):
            raise RuntimeError(f'Missing {tool}; use full Xcode and install ffmpeg via Homebrew.')
    OUT.mkdir(parents=True, exist_ok=True)
    run('xcrun', 'swift', str(ROOT / 'scripts/draw-fixtures.swift'), str(OUT), str(args.seed))
    shutil.copyfile(OUT / 'landscape.jpg', OUT / 'landscape-copy.jpg')
    run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-loop', '1', '-i', str(OUT / 'landscape.jpg'),
        '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100', '-t', '2', '-r', '24',
        '-vf', 'scale=600:400', '-c:v', 'libx264', '-threads', '1', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-metadata', 'creation_time=2025-09-27T10:05:00Z', '-map_metadata', '-1',
        '-fflags', '+bitexact', '-flags:v', '+bitexact', '-flags:a', '+bitexact', str(OUT / 'clip.mp4'))
    files = sorted([*OUT.glob('*.jpg'), *OUT.glob('*.mp4')])
    manifest = {'version': 1, 'seed': args.seed, 'source': 'Original procedural drawings and synthesized tone, no private media',
                'files': [{'name': p.name, 'sha256': digest(p), 'bytes': p.stat().st_size} for p in files],
                'relations': {'exact': ['landscape.jpg', 'landscape-copy.jpg'],
                    'near': ['landscape.jpg', 'landscape-near.jpg'],
                    'keep_both_expression_counterexample': ['portrait-smile.jpg', 'portrait-frown.jpg']}}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if args.install:
        # New device on every explicit install prevents duplicate imports or stale receipts.
        # No existing device is erased, removed, selected, or mutated.
        inventory = json.loads(run('xcrun', 'simctl', 'list', '-j', capture=True))
        sys.path.insert(0, str(ROOT / 'scripts'))
        import importlib.util
        spec = importlib.util.spec_from_file_location('selection', ROOT / 'scripts/select-simulator.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        selected = module.select_device(inventory)
        device = next(d for d in inventory['devices'][selected['runtime']] if d['udid'] == selected['udid'])
        udid = run('xcrun', 'simctl', 'create', f'SwipeGo Fixtures seed {args.seed}', device['deviceTypeIdentifier'], selected['runtime'], capture=True).strip()
        receipt = {'udid': udid, 'seed': args.seed, 'state': 'created', 'manifest_sha256': digest(OUT / 'manifest.json')}
        receipt_path = OUT / f'install-{udid}.json'
        receipt_path.write_text(json.dumps(receipt, indent=2)+'\n')
        run('xcrun', 'simctl', 'bootstatus', udid, '-b')
        run('xcrun', 'simctl', 'addmedia', udid, *map(str, files))
        receipt['state'] = 'imported'
        receipt_path.write_text(json.dumps(receipt, indent=2)+'\n')
        print(f'IMPORTED: {len(files)} files; SWIPE_SIMULATOR_UDID={udid}')
    print('FIXTURES_READY:', OUT / 'manifest.json')

if __name__ == '__main__':
    main()
