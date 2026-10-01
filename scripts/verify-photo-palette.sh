#!/usr/bin/env bash
# Native palette tests on the dedicated generated-fixture simulator only.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
simulator_id="$(xcrun simctl list -j | python3 scripts/select-simulator.py | python3 -c 'import sys,json;print(json.load(sys.stdin)["udid"])')"
xcrun simctl bootstatus "$simulator_id" -b
xcodegen generate --spec project.yml
result_dir="$(mktemp -d "$PWD/.build/palette-check.XXXXXX")"
xcodebuild -project SwipeGo.xcodeproj -scheme SwipeGo -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath .build/v8-palette-build \
  -resultBundlePath "$result_dir/Tests.xcresult" -parallel-testing-enabled NO \
  -only-testing:SwipeGoTests/PhotoPaletteTests -only-testing:SwipeGoUITests/PhotoPaletteUITests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > "$result_dir/xcodebuild.log" 2>&1
xcrun xcresulttool export attachments --path "$result_dir/Tests.xcresult" --output-path "$result_dir/screenshots"
printf 'PALETTE_TESTS_PASSED: %s\n' "$result_dir"
