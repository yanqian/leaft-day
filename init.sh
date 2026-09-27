#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Pre-minspec state: verify the harness is installed and runnable.
# After minspec acceptance, project work should adapt this root entrypoint
# into the project recovery contract described in
# .agent-harness/docs/project-recovery-init.md.
exec "$ROOT_DIR/.agent-harness/scripts/init.sh" "$@"
