#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p .build
xcrun simctl list -j > .build/compact-inventory.json
compact_id="$(python3 - <<'PY'
import json, os, runpy
from pathlib import Path
inventory=json.loads(Path('.build/compact-inventory.json').read_text())
select=runpy.run_path('scripts/select-simulator.py')['select_device']
requested=os.environ.get('SWIPE_COMPACT_SIMULATOR_UDID')
for devices in inventory['devices'].values():
    for d in devices:
        if d.get('deviceTypeIdentifier') != 'com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation': continue
        if requested and d['udid'] != requested: continue
        if not requested and not d.get('name','').startswith('SwipeGo'): continue
        try: chosen=select(inventory,d['udid'])
        except ValueError: continue
        print(chosen['udid']); raise SystemExit(0)
raise SystemExit('Need a dedicated iOS26+ iPhone SE3 simulator; see docs/verification.md compact-home matrix.')
PY
)"
xcrun simctl bootstatus "$compact_id" -b
xcodegen generate --spec project.yml
result_dir="$(mktemp -d "$PWD/.build/compact-home.XXXXXX")"
xcodebuild -project SwipeGo.xcodeproj -scheme SwipeGo -configuration Debug \
  -destination "platform=iOS Simulator,id=$compact_id" -derivedDataPath DerivedData \
  -resultBundlePath "$result_dir/Tests.xcresult" -parallel-testing-enabled NO \
  -only-testing:SwipeGoUITests/HomeTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test \
  2>&1 | tee "$result_dir/xcodebuild.log"
printf 'COMPACT_HOME_PASSED: %s\n' "$result_dir/Tests.xcresult"
