#!/usr/bin/env python3
from __future__ import annotations
import atexit
import getpass
import subprocess
import threading
from typing import Iterable, Optional

def _seed_sudo_timestamp() -> None:
    """Prompt once and seed sudo's timestamp cache; drop password immediately."""
    pw = getpass.getpass("sudo password: ")
    try:
        subprocess.run(
            ["sudo", "-S", "-v"],
            input=pw + "\n",
            text=True,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    finally:
        pw = None  # drop reference ASAP

def _keepalive_loop(stop_evt: threading.Event, interval: int) -> None:
    while not stop_evt.is_set():
        # Use -n to avoid blocking if the timestamp ever expires.
        subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        stop_evt.wait(interval)

def start_sudo_session(keepalive_interval_sec: int = 60):
    """
    Start a sudo session that never stores the password in memory.
    Returns (run, close).

    run(cmd, *, check=True, capture_output=False, cwd=None, env=None, input_text=None)
      -> subprocess.CompletedProcess
    """
    _seed_sudo_timestamp()

    stop_evt = threading.Event()
    t = threading.Thread(
        target=_keepalive_loop,
        args=(stop_evt, max(10, keepalive_interval_sec)),
        name="sudo-keepalive",
        daemon=True,
    )
    t.start()

    def close() -> None:
        if not stop_evt.is_set():
            stop_evt.set()
            t.join(timeout=2)
        subprocess.run(["sudo", "-K"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    atexit.register(close)

    def run(cmd: Iterable[str],
            *,
            check: bool = True,
            capture_output: bool = False,
            cwd: Optional[str] = None,
            env: Optional[dict] = None,
            input_text: Optional[str] = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["sudo", "-n", *cmd],
            check=check,
            capture_output=capture_output,
            text=True,
            cwd=cwd,
            env=env,
            input=input_text
        )

    return run, close
