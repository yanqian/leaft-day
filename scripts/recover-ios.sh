#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Compatibility entry point; all recovery logic now has one implementation.
exec "$ROOT_DIR/verify.sh" --full "$@"
