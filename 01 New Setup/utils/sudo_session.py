# utils/sudo_session.py
#!/usr/bin/env python3
"""
Sudo Session Manager (Keep-Alive)
Version: 2.0.0

What the module does
--------------------
Creates a safe, short-lived sudo "session" without holding your password in
memory. It:

1) Prompts once for your password and seeds sudo's timestamp cache (`sudo -S -v`).
2) Starts a background thread to refresh the timestamp (`sudo -n -v`) periodically.
3) Exposes a `run(cmd, ...)` callable that executes commands as root using `sudo -n`.
4) Exposes a `close()` callable that stops the keep-alive and clears credentials.

Design notes
------------
- The password is only passed to `sudo -S -v` and then discarded immediately.
- All subsequent calls use `-n` (non-interactive). If the timestamp expires,
  commands will fail instead of blocking for a password.
"""

from __future__ import annotations

import atexit
import getpass
import subprocess
import threading
from typing import Iterable, Optional


def _print_action(text: str) -> None:
    """Print a shell-like action description."""
    print(f"$ {text}")


def _seed_sudo_timestamp() -> bool:
    """
    Prompt once and seed sudo's timestamp cache; drop password immediately.

    Returns:
        True if seeding succeeded, False otherwise.
    """
    try:
        # Ask for the password once. This is the only place we accept input.
        pw = getpass.getpass("sudo password: ")
        _print_action("sudo -S -v  # seed sudo timestamp")
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
            # Ensure we drop the reference, even if run() raises.
            pw = None
        return True
    except Exception as exc:
        print(f"ERROR: Failed to seed sudo timestamp: {exc}")
        return False


def _keepalive_loop(stop_evt: threading.Event, interval: int) -> None:
    """Background loop to refresh sudo's timestamp non-interactively."""
    while not stop_evt.is_set():
        # Use -n to avoid blocking if the timestamp ever expires.
        subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        stop_evt.wait(interval)


def start_sudo_session(keepalive_interval_sec: int = 60):
    """
    Start a sudo session that never stores the password in memory.

    Arguments:
        keepalive_interval_sec:
            Seconds between timestamp refreshes. Minimum enforced to 10 seconds.

    Returns:
        (run, close) where:

        - run(cmd, *, check=True, capture_output=False, cwd=None, env=None, input_text=None)
            -> subprocess.CompletedProcess
          Executes `sudo -n <cmd...>` so it never prompts. If the sudo timestamp
          is invalid, the command will fail quickly (non-zero return code).

        - close() -> None
          Stops keep-alive and clears sudo credentials (`sudo -K`).

    Behavior:
        - Prints shell-style actions for visibility.
    """
    if not _seed_sudo_timestamp():
        # We still return a run/close pair, but `run` will fail if sudo is unusable.
        print("⚠️  Continuing without a valid sudo timestamp. Commands may fail (-n).")

    stop_evt = threading.Event()
    interval = max(10, int(keepalive_interval_sec))
    _print_action(f"(keepalive) sudo -n -v every {interval}s")
    t = threading.Thread(
        target=_keepalive_loop,
        args=(stop_evt, interval),
        name="sudo-keepalive",
        daemon=True,
    )
    t.start()

    def close() -> None:
        """Stop keep-alive thread and clear sudo credentials."""
        try:
            if not stop_evt.is_set():
                stop_evt.set()
                t.join(timeout=2)
            _print_action("sudo -K  # clear cached credentials")
            subprocess.run(["sudo", "-K"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as exc:
            print(f"ERROR: Failed to close sudo session cleanly: {exc}")

    atexit.register(close)

    def run(
        cmd: Iterable[str],
        *,
        check: bool = True,
        capture_output: bool = False,
        cwd: Optional[str] = None,
        env: Optional[dict] = None,
        input_text: Optional[str] = None,
    ) -> subprocess.CompletedProcess:
        """
        Execute a command as root using non-interactive sudo.

        Arguments:
            cmd: The command as an iterable of strings, e.g., ["ls", "/root"].
            check: If True, raises CalledProcessError on non-zero exit status.
            capture_output: If True, captures stdout/stderr as text.
            cwd: Working directory for the command.
            env: Environment variables to provide.
            input_text: Optional text to pass to the process's stdin.

        Returns:
            subprocess.CompletedProcess with `returncode`, `stdout`, and `stderr`.

        Notes:
            - Uses `sudo -n` to ensure no interactive prompts occur.
            - If the sudo timestamp is invalid, return code will be non-zero.
        """
        try:
            _print_action("sudo -n " + " ".join(cmd))
            return subprocess.run(
                ["sudo", "-n", *cmd],
                check=check,
                capture_output=capture_output,
                text=True,
                cwd=cwd,
                env=env,
                input=input_text,
            )
        except Exception:
            # Let callers see stack in their try/except if they opted `check=True`.
            # We still re-raise to preserve expected subprocess semantics.
            raise

    return run, close
