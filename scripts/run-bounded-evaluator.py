#!/usr/bin/env python3
"""Bound a configured evaluator command without interpreting its role verdict."""
import argparse
import os
import signal
import subprocess
import sys
import time
from process_cleanup import stop_process_group


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--timeout-seconds', type=float, default=2400)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or not 0 < args.timeout_seconds <= 7200:
        parser.error('provide a command and a positive timeout no greater than 7200 seconds')
    # Inherit stdin, stdout and stderr, including the harness-rendered prompt.
    process = subprocess.Popen(command, start_new_session=True)
    def interrupted(*_):
        stop_process_group(process)
        raise SystemExit(130)
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    deadline = time.time() + args.timeout_seconds
    while True:
        remaining = deadline - time.time()
        if remaining <= 0:
            stop_process_group(process)
            print(f'EVALUATOR_TIMEOUT: stopped owned process group after {args.timeout_seconds:g}s; no verdict inferred', file=sys.stderr)
            return 124
        try:
            return process.wait(timeout=min(30, remaining))
        except subprocess.TimeoutExpired:
            continue


if __name__ == '__main__':
    sys.exit(main())
