# modules/120_input/module.py
#!/usr/bin/env python3
"""
Input Devices (libinput for Xorg)
Version: 1.0.0

What this module does
---------------------
- Installs input-related packages for Xorg:
  * libinput (core), xf86-input-libinput (Xorg driver)
  * utilities: xorg-xinput, xorg-xev, evtest
- Symlinks local Xorg input configs from this module's `xorg.conf.d/`
  into `/etc/X11/xorg.conf.d/` (with per-run backups via your symlinker).
- (Optional) If a local `udev/` folder exists, its rules are symlinked into
  `/etc/udev/rules.d/` (useful for gesture tooling uaccess, etc).
- Prints non-destructive verification tips at the end.

Idempotency & Safety
--------------------
- Uses pacman's `--needed --noconfirm`.
- Uses your symlinker which backs up existing targets before linking.
- Stops on first failure and returns False so the orchestrator can abort cleanly.
"""

from __future__ import annotations

from pathlib import Path
from typing import Callable

from utils.pacman import install_packages
from utils.symlinker import symlink_tree_files


def _module_dir() -> Path:
    return Path(__file__).resolve().parent


def _symlink_xorg(run: Callable) -> bool:
    """Symlink this module's xorg.conf.d/* into /etc/X11/xorg.conf.d/ if present."""
    local_xorg = _module_dir() / "xorg.conf.d"
    if not local_xorg.exists():
        print("⚠️  [120_input] No local xorg.conf.d/ directory found; skipping Xorg config symlinks.")
        return True  # Not an error—config is optional.

    if not local_xorg.is_dir():
        print("ERROR: [120_input] xorg.conf.d exists but is not a directory.")
        return False

    dest = Path("/etc/X11/xorg.conf.d")
    print(f"▶ [120_input] Linking Xorg input configs -> {dest}")
    ok = symlink_tree_files(local_xorg, dest, run=run, use_relative=False)
    if not ok:
        print("ERROR: [120_input] Failed to link Xorg input configs.")
    return ok


def _symlink_udev_rules(run: Callable) -> bool:
    """Symlink optional udev rules from ./udev/* to /etc/udev/rules.d/ if present."""
    local_udev = _module_dir() / "udev"
    if not local_udev.exists():
        # Entirely optional—skip quietly.
        return True

    if not local_udev.is_dir():
        print("ERROR: [120_input] udev exists but is not a directory.")
        return False

    dest = Path("/etc/udev/rules.d")
    print(f"▶ [120_input] Linking udev rules -> {dest}")
    ok = symlink_tree_files(local_udev, dest, run=run, use_relative=False)
    if not ok:
        print("ERROR: [120_input] Failed to link udev rules.")
        return False

    # Hint: tell the user how to reload rules (non-fatal if they don't).
    print("ℹ️  [120_input] To reload udev rules now: sudo udevadm control --reload && sudo udevadm trigger")
    return True


def install(run: Callable) -> bool:
    """
    Install input stack and apply local configs.

    Arguments:
        run: sudo runner from start_sudo_session()

    Returns:
        True on success, False otherwise.
    """
    try:
        print("▶ [120_input] Installing input device stack (libinput for Xorg)...")
        packages = [
            "libinput",
            "xf86-input-libinput",
            "xorg-xinput",
            "xorg-xev",
            "evtest",
        ]
        if not install_packages(packages, run):
            print("❌ [120_input] Package installation failed.")
            return False

        if not _symlink_xorg(run):
            return False

        if not _symlink_udev_rules(run):
            return False

        print("✔ [120_input] Input stack configured.")

        # Non-destructive verification tips
        print("\n[120_input] Verify configuration with:")
        print("  $ libinput list-devices")
        print("  $ xinput list")
        print("  $ grep \"Using input driver 'libinput'\" /var/log/Xorg.0.log || true")
        print("\n[120_input] Notes:")
        print("  - Edit modules/120_input/xorg.conf.d/90-libinput.conf in-repo to tweak touchpad/mouse defaults.")
        print("  - If you added udev rules (e.g., for gestures), you may need to replug the device or reboot.")

        return True

    except Exception as exc:
        print(f"ERROR: [120_input] install() failed: {exc}")
        return False
