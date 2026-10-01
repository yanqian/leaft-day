#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Always verify harness/Python and live app recovery. Reuse only intact matching
# full test evidence; Evaluators use SWIPE_VERIFY_FRESH=1 on their first run.
exec "$ROOT_DIR/verify.sh" --full --reuse "$@"
