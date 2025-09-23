# modules/020_security/module.py
#!/usr/bin/env python3
"""
020_security (minimal baseline)
- Ensure polkit is installed (needed for GUI/system services to escalate privileges)
- Does NOT modify sudoers or sudo configuration

NOTE:
    Arch by default does not grant sudo access to the `wheel` group.
    If you ever hit a situation where your user cannot run `sudo` (scripts, SSH, tools),
    you may want to add a snippet like:

        %wheel ALL=(ALL:ALL) ALL

    in /etc/sudoers.d/10-wheel (validated with visudo).
    For now, this module deliberately skips it to avoid unexpected changes.
"""

from __future__ import annotations
from typing import Callable


def install(run: Callable) -> bool:
    """
    Ensure baseline security packages are present.
    """
    try:
        print("▶ [020_security] Starting minimal security setup…")

        # Install polkit (idempotent, safe for desktop apps needing privilege escalation)
        from utils.pacman import install_packages
        if not install_packages(["polkit"], run):
            return False

        print("✔ [020_security] Security baseline complete.")
        return True

    except Exception as exc:
        print(f"ERROR: 020_security.install failed: {exc}")
        return False
