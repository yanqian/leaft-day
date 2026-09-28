#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# User-approved simulator-only development while the phone is disconnected.
SWIPE_VERIFICATION_MODE="${SWIPE_VERIFICATION_MODE:-simulator}"
case "$SWIPE_VERIFICATION_MODE" in
  simulator|device) ;;
  *) printf 'Invalid SWIPE_VERIFICATION_MODE: use simulator or device\n' >&2; exit 2 ;;
esac
export HARNESS_EVALUATOR_EVIDENCE_BASELINE=F001
printf '== Harness verification ==\n'
"$ROOT_DIR/.agent-harness/scripts/init.sh" "$@"
python3 "$ROOT_DIR/scripts/seed-fixtures.py" --seed 27
python3 -m unittest discover -s "$ROOT_DIR/tests" -v
"$ROOT_DIR/scripts/recover-ios.sh"
if [[ "$SWIPE_VERIFICATION_MODE" == device ]]; then
  printf '== Physical Vision quality gate (bundled images only) ==\n'
  "$ROOT_DIR/scripts/verify-device-vision.sh"
else
  printf 'DEVICE_VERIFICATION_DEFERRED: user disconnected phone; physical/iCloud acceptance remains F018\n'
fi
