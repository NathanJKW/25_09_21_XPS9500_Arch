# utils/yay.py
#!/usr/bin/env python3
"""
Yay install helper (AUR) that is compatible with your sudo session flow.
Version: 2.0.0

What the module does
--------------------
Installs packages via the AUR helper `yay` in an idempotent way.

Sudo-session compatibility
--------------------------
This function accepts a `run` parameter for API symmetry with `pacman`, but
**intentionally ignores it** and runs `yay` as the **current normal user**.
That's because `yay` should *not* be invoked with sudo; it elevates internally
when necessary. If your process has an active sudo timestamp (seeded by your
`sudo_session`), yay's internal `sudo` calls will be non-interactive.

Key behavior
------------
- Uses: yay -S --needed --noconfirm <packages...>
  * `--needed` makes the operation idempotent (already-installed packages are skipped).
- Prints shell-like actions before running.
- Catches exceptions, prints clear errors, returns True/False.
- Preflight note: we warn if non-interactive sudo is not yet available, so the user
  understands a prompt might occur (useful outside your main flow).

Public API
----------
install_packages(packages: list[str], run=None) -> bool
    Install one or more packages using yay as the current user.

Example
-------
# Normal usage (yay runs as your user; sudo timestamp seeded elsewhere)
from utils.yay import install_packages
ok = install_packages(["google-chrome", "visual-studio-code-bin"])
"""

from __future__ import annotations

from typing import Iterable, List
import shutil
import subprocess
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


def _check_yay_available() -> bool:
    """
    Verify that the 'yay' binary is available in PATH.

    Returns:
        True if yay is found; False otherwise (with an error printed).
    """
    yay_path = shutil.which("yay")
    if yay_path is None:
        _print_error("The 'yay' command was not found in PATH. Install yay before using this module.")
        return False
    return True


def _noninteractive_sudo_available() -> bool:
    """
    Return True if sudo can be used without prompting (timestamp valid or NOPASSWD).
    We probe with a harmless no-op: `sudo -n true`.
    """
    try:
        res = subprocess.run(["sudo", "-n", "true"], check=False, capture_output=False, text=True)
        return res.returncode == 0
    except Exception:
        return False


def install_packages(packages: List[str], run=None) -> bool:
    """
    Install one or more packages using yay (AUR helper) in an idempotent way.

    Arguments:
        packages:
            A list of package names (strings), e.g., ["google-chrome", "visual-studio-code-bin"].
        run:
            Ignored (accepted for API symmetry with pacman). yay must run as a normal user.

    Returns:
        True on success (including no-op for empty list), False on failure.

    Behavior:
        - Treats empty input as a successful no-op.
        - Uses 'yay -S --needed --noconfirm' to avoid reinstalling present packages.
        - Prints actions and surfaces diagnostics on failure.
    """
    try:
        if not _check_yay_available():
            return False

        cleaned = [p.strip() for p in packages if isinstance(p, str) and p.strip()]
        if not cleaned:
            _print_action("yay -S --needed --noconfirm  # (no packages provided; nothing to do)")
            return True

        # Helpful heads-up when running outside your main seeded flow.
        if not _noninteractive_sudo_available():
            print(
                "ℹ️  Non-interactive sudo is not active yet. "
                "If yay needs elevation, it may prompt unless a sudo timestamp is seeded."
            )

        cmd = ["yay", "-S", "--needed", "--noconfirm", *cleaned]
        _print_action(_join(cmd))

        # Run as the current user (NOT via sudo). yay will escalate internally if needed.
        result = subprocess.run(cmd, check=False, text=True, capture_output=False)

        if result.returncode != 0:
            _print_error("yay failed with a non-zero exit status.")
            if result.stdout:
                print(result.stdout.rstrip())
            if result.stderr:
                _print_error(result.stderr.rstrip())
            return False

        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)

        return True

    except Exception as exc:
        _print_error(f"Unexpected error running yay: {exc}")
        return False


# Backward-compat alias for code that imported the old name.
installpackage = install_packages


if __name__ == "__main__":
    # Demonstration (runs as your normal user).
    print("👟 Demo: installing 'bat' via yay (idempotent).")
    ok = install_packages(["bat"])
    print(f"Result: {'success' if ok else 'failure'}")
