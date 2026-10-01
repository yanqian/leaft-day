"""Terminate an owned POSIX process group, including a leader that exits first."""
import os
import signal
import subprocess


def stop_process_group(process, grace=1):
    # Popen must have been created with start_new_session=True by the caller.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait()
        return
    try:
        process.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        pass
    # The leader's exit does NOT prove its descendants have exited. Always
    # signal the group again; a surviving group member keeps this PGID alive.
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()
