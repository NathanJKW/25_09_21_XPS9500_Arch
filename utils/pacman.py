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

from __future__ import annotations

from typing import Callable, Iterable, List
import sys


def _print_action(command_like: str) -> None:
    """Print a shell-like command to the terminal to show what is happening."""
    print(f"$ {command_like}")


def _print_error(message: str) -> None:
    """Print a clear error message to stderr so it stands out in logs."""
    print(f"ERROR: {message}", file=sys.stderr)


def _join(cmd: Iterable[str]) -> str:
    """Join a command list into a readable shell-like string (for logging only)."""
    return " ".join(str(part) for part in cmd)


def install_packages(packages: List[str], run: Callable) -> bool:
    """
    Install one or more packages using pacman in an idempotent way.

    Arguments:
        packages:
            A list of package names (strings), e.g., ["vim", "git", "curl"].
        run:
            The sudo runner callable returned by `start_sudo_session()`.
            It must accept a list[str] command and execute it with sudo.

    Returns:
        True if the installation command completed successfully, False otherwise.

    Behavior:
        - Treats empty input as a successful no-op.
        - Uses 'pacman -S --needed --noconfirm' to avoid reinstalling present packages.
        - Prints actions, captures and prints output on errors.
    """
    try:
        # Sanitize input first: drop non-strings/empties; allow empty list as no-op.
        cleaned = [p.strip() for p in packages if isinstance(p, str) and p.strip()]
        if not cleaned:
            _print_action("pacman -S --needed --noconfirm  # (no packages provided; nothing to do)")
            return True

        cmd = ["pacman", "-S", "--needed", "--noconfirm", *cleaned]
        _print_action(_join(cmd))

        # Use the sudo-session runner (executes `sudo -n <cmd>` under the hood).
        result = run(cmd, check=False, capture_output=False)

        if result.returncode != 0:
            _print_error("pacman failed with a non-zero exit status.")
            if result.stdout:
                print(result.stdout.rstrip())
            if result.stderr:
                _print_error(result.stderr.rstrip())
            return False

        # On success, print any stdout (pacman can be chatty).
        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            # pacman may warn to stderr even on success.
            print(result.stderr.rstrip(), file=sys.stderr)

        return True

    except Exception as exc:
        _print_error(f"Unexpected error running pacman: {exc}")
        return False


# Backward-compat alias for code that imported the old name.
installpackage = install_packages


if __name__ == "__main__":
    # Demonstration of usage with the sudo session.
    from utils.sudo_session import start_sudo_session

    run, close = start_sudo_session()
    try:
        print("👟 Demo: installing 'htop' (idempotent).")
        success = install_packages(["htop"], run)
        print(f"Result: {'success' if success else 'failure'}")
    finally:
        close()
