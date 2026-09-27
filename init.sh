#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARNESS_EVALUATOR_EVIDENCE_BASELINE=F001
printf '== Harness verification ==\n'
"$ROOT_DIR/.agent-harness/scripts/init.sh" "$@"
python3 -m unittest discover -s "$ROOT_DIR/tests" -v
"$ROOT_DIR/scripts/recover-ios.sh"
