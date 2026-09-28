#!/usr/bin/env bash
# Run only the bundled, non-private Vision control images on an explicitly selected phone.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Optional ignored local destination config; never commit a user's device/team identity.
if [[ -f .build/device-test.json ]]; then
  read -r configured_device configured_team < <(python3 -c 'import json; c=json.load(open(".build/device-test.json")); print(c["udid"], c["team"])')
  export SWIPE_DEVICE_UDID="${SWIPE_DEVICE_UDID:-$configured_device}"
  export SWIPE_DEVELOPMENT_TEAM="${SWIPE_DEVELOPMENT_TEAM:-$configured_team}"
fi
: "${SWIPE_DEVICE_UDID:?Set the physical device UDID reported by xcodebuild -showdestinations}"
: "${SWIPE_DEVELOPMENT_TEAM:?Set the development team selected in Xcode}"
if [[ ! "$SWIPE_DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
  printf 'Invalid development team identifier\n' >&2; exit 2
fi
# Let xcodebuild validate the identity/profile: security -v can report no valid
# identities before Xcode resolves the certificate chain, even when signing works.
python3 scripts/seed-fixtures.py --seed 27
xcodegen generate --spec project.yml
mkdir -p .build
result_dir="$(mktemp -d "$ROOT_DIR/.build/device-vision.XXXXXX")"
# Do not run the simulator-oriented full suite on a personal device.
# The free Personal Team must already be configured in Xcode.
xcodebuild -project SwipeGo.xcodeproj -scheme SwipeGo -configuration Debug \
  -destination "platform=iOS,id=$SWIPE_DEVICE_UDID" \
  -derivedDataPath "$ROOT_DIR/.build/device-derived" \
  -resultBundlePath "$result_dir/Tests.xcresult" \
  -parallel-testing-enabled NO \
  DEVELOPMENT_TEAM="$SWIPE_DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  '-only-testing:SwipeGoTests/SimilarityTests/testBundledVisionNegativeControl' \
  '-only-testing:SwipeGoTests/SimilarityTests/testBundledProductionVisionPipeline' \
  test 2>&1 | tee "$result_dir/xcodebuild.log"
printf 'DEVICE_VISION_PASS: %s\n' "$result_dir/Tests.xcresult"
