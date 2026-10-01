#!/usr/bin/env bash
# Focused v8 visual checks on a dedicated simulator, never a personal device.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
feature="${1:?Usage: verify-v8-pages.sh F027 [compact]}"
case "$feature" in
 F027) suites=(HomeTests HomeCoverStateTests SettingsGlassTests WelcomeGlassTests) ;;
 F015) suites=(DeletionReviewUITests DeletionUITests DeletionResultGlassTests) ;;
 F028) suites=(DeletionHistoryGlassTests ReconciliationUITests DeletionUITests) ;;
 F029) suites=(ReviewStateGlassTests ComparisonUITests ReviewGlassTests ReviewOrientationTests ReviewTapTests ReviewContinuityUITests PendingUITests VideoTests) ;;
 *) printf 'Unsupported visual feature\n' >&2; exit 2 ;;
esac
inventory="$(mktemp "$PWD/.build/v8-inventory.XXXXXX")"
xcrun simctl list -j > "$inventory"
simulator_id="$(python3 - "$inventory" "${2:-standard}" <<'PY'
import json,sys,runpy
v=json.load(open(sys.argv[1]));select=runpy.run_path('scripts/select-simulator.py')['select_device']
if sys.argv[2]=='compact':
 for group in v['devices'].values():
  for d in group:
   if d.get('name','').startswith('SwipeGo') and d.get('deviceTypeIdentifier')=='com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation':
    try: print(select(v,d['udid'])['udid']);raise SystemExit(0)
    except ValueError: pass
 raise SystemExit('No dedicated compact iOS26 simulator')
print(select(v)['udid'])
PY
)"
xcrun simctl bootstatus "$simulator_id" -b
xcodegen generate --spec project.yml
result_dir="$(mktemp -d "$PWD/.build/v8-${feature}.XXXXXX")"
options=()
for suite in "${suites[@]}"; do options+=("-only-testing:SwipeGoUITests/$suite"); done
xcodebuild -project SwipeGo.xcodeproj -scheme SwipeGo -configuration Debug \
 -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath .build/v8-pages-build \
 -resultBundlePath "$result_dir/Tests.xcresult" -parallel-testing-enabled NO \
 "${options[@]}" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$result_dir/xcodebuild.log" 2>&1
xcrun xcresulttool export attachments --path "$result_dir/Tests.xcresult" --output-path "$result_dir/screenshots"
printf 'V8_VISUAL_TESTS_PASSED: %s\n' "$result_dir"
