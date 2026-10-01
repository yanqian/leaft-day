#!/usr/bin/env bash
# Explicit physical-device fixture flow. Never run the general UI suite on a personal phone.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [[ -f .build/device-test.json ]]; then
  read -r configured_device configured_team < <(python3 -c 'import json; c=json.load(open(".build/device-test.json")); print(c["udid"], c["team"])')
  export SWIPE_DEVICE_UDID="${SWIPE_DEVICE_UDID:-$configured_device}"
  export SWIPE_DEVELOPMENT_TEAM="${SWIPE_DEVELOPMENT_TEAM:-$configured_team}"
fi
: "${SWIPE_DEVICE_UDID:?Set physical device UDID}"
: "${SWIPE_DEVELOPMENT_TEAM:?Set existing Personal Team}"
[[ "$SWIPE_DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]] || exit 2
python3 scripts/seed-fixtures.py --seed 27
xcodegen generate --spec project.yml
mkdir -p .build
result_dir="$(mktemp -d "$ROOT_DIR/.build/device-acceptance.XXXXXX")"
xcodebuild -project SwipeGo.xcodeproj -scheme SwipeGo -configuration Debug \
  -destination "platform=iOS,id=$SWIPE_DEVICE_UDID" \
  -derivedDataPath "$ROOT_DIR/.build/device-derived" \
  -resultBundlePath "$result_dir/Tests.xcresult" -parallel-testing-enabled NO \
  DEVELOPMENT_TEAM="$SWIPE_DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  '-only-testing:SwipeGoUITests/DeviceAcceptanceTests' test 2>&1 | tee "$result_dir/xcodebuild.log"
if grep -q 'SwiftData.ModelContext: Unbinding' "$result_dir/xcodebuild.log"; then exit 1; fi
printf 'DEVICE_LOCAL_FLOW_PASS: %s; iCloud/LivePhoto/performance remain separately required\n' "$result_dir/Tests.xcresult"
