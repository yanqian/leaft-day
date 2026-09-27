#!/usr/bin/env bash
# Read-only toolchain inventory. No global xcode-select switch or downloads.
set -euo pipefail

fail() { printf 'NOT_READY: %s\n' "$*" >&2; exit 1; }
printf '== Developer directory ==\n'
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  developer_dir="$DEVELOPER_DIR"
  [[ "$developer_dir" != *.app ]] || developer_dir="$developer_dir/Contents/Developer"
else
  developer_dir="$(/usr/bin/xcode-select -p)" || fail 'Cannot resolve active developer directory.'
  if [[ ! -d "$developer_dir/Platforms/iPhoneOS.platform" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    developer_dir=/Applications/Xcode.app/Contents/Developer
  fi
fi
printf '%s\n' "$developer_dir"
[[ -d "$developer_dir/Platforms/iPhoneOS.platform" ]] || fail 'Full Xcode with iPhoneOS platform is required. Install Xcode or set DEVELOPER_DIR to its Contents/Developer directory.'
export DEVELOPER_DIR="$developer_dir"
printf '== Xcode ==\n'
/usr/bin/xcodebuild -version || fail 'Xcode cannot run; check installation and first-launch setup.'
printf '== iPhoneOS SDK ==\n'
sdk_version="$(/usr/bin/xcrun --sdk iphoneos --show-sdk-version)" || fail 'iPhoneOS SDK unavailable.'
printf '%s\n' "$sdk_version"
[[ "$sdk_version" =~ ^([0-9]+)(\.[0-9]+)*$ ]] || fail 'Unrecognized SDK version; refusing to infer compatibility.'
[[ "${BASH_REMATCH[1]}" -ge 26 ]] || fail 'iOS SDK 26 or newer required.'
printf '== iPhoneSimulator SDK ==\n'
simulator_sdk="$(/usr/bin/xcrun --sdk iphonesimulator --show-sdk-version)" || fail 'iPhoneSimulator SDK unavailable.'
printf '%s\n' "$simulator_sdk"
[[ "$simulator_sdk" =~ ^([0-9]+)(\.[0-9]+)*$ ]] || fail 'Unrecognized simulator SDK version.'
[[ "${BASH_REMATCH[1]}" -ge 26 ]] || fail 'Simulator SDK 26 or newer required.'
printf '== Simulator tool ==\n'
/usr/bin/xcrun --find simctl || fail 'simctl unavailable.'
printf '== Simulator selection ==\n'
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || fail 'python3 is required for simulator inventory validation.'
/usr/bin/xcrun simctl list -j | python3 "$script_dir/select-simulator.py" || fail 'Simulator inventory unavailable or no compatible iPhone. Check runtime installation and CoreSimulator permissions.'
printf 'READY: toolchain inventory validated; App build/launch and device signing are separate checks.\n'
