# utils/pacman.py
#!/usr/bin/env python3
"""
Pacman install helper that uses a provided sudo session runner.
Version: 2.0.0

What the module does
--------------------
Provides a tiny, safe wrapper to install packages with the Arch `pacman`
package manager. It **expects** you to pass the `run` function returned by
`utils.sudo_session.start_sudo_session()`, so all commands are executed with
root privileges via `sudo -n`.

Key behavior
------------
- Uses: pacman -S --needed --noconfirm <packages...>
  * `--needed` makes the operation idempotent (already-installed packages are skipped).
- Prints shell-like actions before running, surfaces useful output on success/failure.
- Robust error handling: exceptions are caught, clear messages are printed,
  and the function returns `True` (success) or `False` (failure).

Public API
----------
install_packages(packages: list[str], run: Callable) -> bool
    Install one or more packages using the provided sudo runner.

Example
-------
from utils.sudo_session import start_sudo_session
from utils.pacman import install_packages

run, close = start_sudo_session()
try:
    ok = install_packages(["git", "vim"], run)
    if not ok:
        print("Failed to install required packages")
finally:
    close()
"""

from typing import List, Callable
import sys


def _print_action(cmd: str) -> None:
    print(f"$ {cmd}")


def _print_error(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)


def _join(cmd: List[str]) -> str:
    return " ".join(cmd)


def install_packages(packages: List[str], run: Callable) -> bool:
    """
    Install the given packages with pacman if not already present.

    Uses --needed and --noconfirm. Runs pacman under the provided `run`
    (which already wraps sudo).
    """
    if not packages:
        return True

    cleaned = [pkg.strip() for pkg in packages if pkg and pkg.strip()]
    if not cleaned:
        return True

    cmd = ["pacman", "-S", "--needed", "--noconfirm", *cleaned]
    _print_action(_join(cmd))

    # Capture output so we can show diagnostics if it fails.
    result = run(cmd, check=False, capture_output=True)

    if result.returncode != 0:
        _print_error("pacman failed with a non-zero exit status.")
        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            _print_error(result.stderr.rstrip())
        return False

    # On success, pacman usually prints progress bars directly; stdout/stderr
    # may be empty. We don’t spam unless something is useful.
    if result.stdout:
        print(result.stdout.rstrip())
    if result.stderr:
        # pacman sometimes warns to stderr even on success
        print(result.stderr.rstrip(), file=sys.stderr)

    return True
