#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
trap 'printf "Recovery failed at line %s (exit %s)\n" "$LINENO" "$?" >&2' ERR
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  export DEVELOPER_DIR="$(xcode-select -p)"
  if [[ ! -d "$DEVELOPER_DIR/Platforms/iPhoneOS.platform" ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
fi
[[ "$DEVELOPER_DIR" != *.app ]] || export DEVELOPER_DIR="$DEVELOPER_DIR/Contents/Developer"
printf '== iOS dependencies ==\n'
./scripts/doctor.sh
if ! command -v xcodegen >/dev/null; then
  printf 'XcodeGen 2.46+ required. Install with: HOMEBREW_NO_INSTALL_CLEANUP=1 brew install xcodegen\n' >&2
  exit 1
fi
xcodegen --version
printf '== Generate project ==\n'
xcodegen generate --spec project.yml
printf '== Boot selected simulator ==\n'
selection="$(xcrun simctl list -j | python3 scripts/select-simulator.py)"
simulator_id="$(printf '%s' "$selection" | python3 -c 'import sys,json; print(json.load(sys.stdin)["udid"])')"
# Aborted XCTest sessions can leave the simulator ignoring orientation events.
# Restart only this selected test destination; preserve its app/library data.
if [[ "$(printf '%s' "$selection" | python3 -c 'import sys,json; print(json.load(sys.stdin)["state"])')" == Booted ]]; then
  xcrun simctl shutdown "$simulator_id"
fi
xcrun simctl bootstatus "$simulator_id" -b
mkdir -p .build
printf '== Build and run app tests ==\n'
# Unsigned test runners can be cached by CoreSimulator after test code changes.
# Remove only our runner; preserve the app, its state and Photos library.
xcrun simctl uninstall "$simulator_id" dev.armstrong.swipego.uitests.xctrunner
# A unique result bundle preserves each invocation, including failed tests.
result_dir="$(mktemp -d "$ROOT_DIR/.build/test-run.XXXXXX")"
test_options=(-project SwipeGo.xcodeproj -scheme SwipeGo -configuration Debug
  -destination "platform=iOS Simulator,id=$simulator_id"
  -derivedDataPath "$ROOT_DIR/DerivedData"
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-)
# Unit integration tests need the generated fixture library even when the last
# UI test left authorization denied. Use the real native permission path first:
# simctl's grant alone did not update PhotoKit readWrite status on iOS 26.5.
xcodebuild "${test_options[@]}" build-for-testing 2>&1 | tee "$result_dir/build.log"
xcodebuild "${test_options[@]}" -resultBundlePath "$result_dir/PermissionSetup.xcresult" \
  '-only-testing:SwipeGoUITests/PermissionTests/testFullAccessQueriesRealLibrary' \
  test-without-building 2>&1 | tee "$result_dir/permission-setup.log"
printf 'SIMULATOR_FIXTURE_ACCESS_READY: native full-access preflight passed; full UI matrix still resets and requests natively.\n'
xcodebuild "${test_options[@]}" -resultBundlePath "$result_dir/Tests.xcresult" test-without-building 2>&1 | tee "$result_dir/xcodebuild.log"
if grep -q "SwiftData.ModelContext: Unbinding" "$result_dir/xcodebuild.log"; then
  printf "FAILED: SwiftData ModelContext crossed its creation queue; see %s\n" "$result_dir/xcodebuild.log" >&2
  exit 1
fi
printf '== Install and launch reviewable app ==\n'
xcrun simctl install "$simulator_id" "$ROOT_DIR/DerivedData/Build/Products/Debug-iphonesimulator/SwipeGo.app"
xcrun simctl launch --terminate-running-process "$simulator_id" dev.armstrong.swipego
printf 'APP_READY: tests passed and app launched on %s; results: %s\n' "$simulator_id" "$result_dir/Tests.xcresult"
