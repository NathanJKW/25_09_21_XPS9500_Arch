# modules/00_core/module.py
#!/usr/bin/env python3
"""
Core Bootstrap Module
Version: 1.0.0

What the module does
--------------------
Sets up essentials required by other modules. Keep this minimal and safe.
Typical tasks (examples; uncomment/implement as needed):
- Ensure base packages are present.
- Create foundational directories.
- Seed configs used by subsequent modules.

This file is intentionally conservative—fill in real tasks once you define them.
"""

from __future__ import annotations
from pathlib import Path
from typing import Callable


def install(run: Callable) -> bool:
    """
    Perform core bootstrap steps.

    Arguments:
        run:
            The sudo-runner returned from `start_sudo_session()`. Call it with a
            list[str] command to run as root non-interactively.

    Returns:
        True on success, False on failure.
    """
    try:
        print("▶ [00_core] Starting core bootstrap...")

        # Example: create a common directory (idempotent).
        # We print our action like a shell command for clarity.
        target_dir = Path("/etc/dotfiles")
        print(f"$ mkdir -p {target_dir}")
        res = run(["mkdir", "-p", str(target_dir)], check=False, capture_output=True)
        if res.returncode != 0:
            print("ERROR: Failed to create /etc/dotfiles")
            if res.stdout:
                print(res.stdout.rstrip())
            if res.stderr:
                print(res.stderr.rstrip())
            return False

        # Example: you could install baseline packages (commented until you decide).
        # from utils.pacman import install_packages
        # if not install_packages(["git", "curl"], run):
        #     return False

        print("✔ [00_core] Core bootstrap complete.")
        return True
    except Exception as exc:
        print(f"ERROR: 00_core.install failed: {exc}")
        return False
