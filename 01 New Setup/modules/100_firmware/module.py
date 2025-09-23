#!/usr/bin/env python3
"""
modules/100_firmware/module.py
Firmware & Microcode Base

Scope
-----
- CPU microcode (Intel)
- Core device firmware packages
- Sound Open Firmware (SoF) stack for Intel cAVS
- Firmware update stack (fwupd) + Thunderbolt (bolt)
- NVMe tools (for visibility/updates)
- Gentle GRUB regen so microcode gets picked up
- Post-install visibility checks (non-fatal)

Idempotency & Safety
--------------------
- Package installs go through utils.pacman.install_packages (uses --needed)
- Services are enabled with systemctl --now (ok if already enabled)
- We DO NOT auto-apply firmware updates; we only surface them
- We DO NOT modify systemd-boot/UKI entries automatically; we log guidance
"""
from __future__ import annotations

from pathlib import Path
from typing import Callable, Iterable, Optional
import shutil
import subprocess

from utils.pacman import install_packages


PKGS: list[str] = [
    # Core firmware & microcode
    "linux-firmware",
    "intel-ucode",
    # Helpful tools
    "iucode-tool",
    "fwupd",
    "bolt",
    "nvme-cli",
    # Audio firmware/config for Intel cAVS/SoF devices
    "sof-firmware",
    "alsa-ucm-conf",
]


def _print_action(text: str) -> None:
    print(f"$ {text}")


def _print_warn(text: str) -> None:
    print(f"⚠️  {text}")


def _print_ok(text: str) -> None:
    print(f"✔ {text}")


def _svc(run: Callable, *args: str) -> bool:
    """Run a systemctl command via the sudo runner, capture output, never raise."""
    try:
        _print_action("systemctl " + " ".join(args))
        res = run(["systemctl", *args], check=False, capture_output=True)
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
        return res.returncode == 0
    except Exception as exc:
        _print_warn(f"systemctl failed: {exc}")
        return False


def _have(path_or_prog: str) -> bool:
    p = Path(path_or_prog)
    if p.exists():
        return True
    return shutil.which(path_or_prog) is not None


def _grub_cfg_path() -> Optional[Path]:
    # Common GRUB cfg location on Arch
    p = Path("/boot/grub/grub.cfg")
    return p if p.exists() else None


def _grub_regenerate(run: Callable) -> None:
    """Regenerate GRUB config if GRUB appears present (safe op)."""
    if not _have("grub-mkconfig"):
        _print_warn("GRUB not detected (grub-mkconfig missing); skipping GRUB regen.")
        return
    cfg_out = "/boot/grub/grub.cfg"
    _print_action(f"grub-mkconfig -o {cfg_out}")
    res = run(["grub-mkconfig", "-o", cfg_out], check=False, capture_output=True)
    if res.stdout:
        print(res.stdout.rstrip())
    if res.stderr:
        print(res.stderr.rstrip())
    if res.returncode == 0:
        _print_ok("GRUB configuration regenerated (microcode will be included if installed).")
    else:
        _print_warn("Failed to regenerate GRUB config. Microcode may not load until you fix GRUB.")


def _run_user(cmd: Iterable[str]) -> None:
    """Run a harmless, non-privileged command as the current user and print output."""
    try:
        _print_action(" ".join(cmd))
        res = subprocess.run(list(cmd), check=False, capture_output=True, text=True)
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
    except Exception as exc:
        _print_warn(f"Command failed to run: {' '.join(cmd)}: {exc}")


def _nvme_device_present() -> bool:
    # Quick heuristic: does /dev/nvme0 exist?
    return Path("/dev/nvme0").exists()


def install(run: Callable) -> bool:
    try:
        print("▶ [100_firmware] Installing firmware, microcode, and update stack…")

        # 1) Packages (idempotent)
        if not install_packages(PKGS, run):
            return False

        # 2) Enable services
        _svc(run, "enable", "--now", "fwupd.service")
        _svc(run, "enable", "--now", "bolt.service")

        # 3) GRUB regen (safe) — only if GRUB appears present
        if _grub_cfg_path() is not None or _have("grub-mkconfig"):
            _grub_regenerate(run)
        else:
            _print_warn(
                "GRUB not detected. If you use systemd-boot/UKI, ensure intel-ucode is embedded or an initrd entry exists."
            )

        # 4) Post-install visibility (non-fatal)
        # fwupd metadata + available updates (runs as user)
        if _have("fwupdmgr"):
            _run_user(["fwupdmgr", "refresh", "--force"])
            _run_user(["fwupdmgr", "get-devices"])
            _run_user(["fwupdmgr", "get-updates"])  # may list BIOS/TB/NVMe updates
        else:
            _print_warn("fwupdmgr not found in PATH — skip listing firmware updates.")

        # NVMe visibility
        if _nvme_device_present():
            # Use sudo-runner for consistent output even if some subcommands need root
            _print_action("sudo -n nvme list")
            res = run(["nvme", "list"], check=False, capture_output=True)
            if res.stdout:
                print(res.stdout.rstrip())
            if res.stderr:
                print(res.stderr.rstrip())
        else:
            _print_warn("No /dev/nvme0 detected; skipping nvme list.")

        print("ℹ️  Notes:")
        print("  - We do NOT auto-apply firmware updates. Use 'fwupdmgr upgrade' and reboot when convenient.")
        print("  - For systemd-boot/UKI setups, verify your microcode is included (e.g., in mkinitcpio or UKI build).")

        _print_ok("[100_firmware] Completed.")
        return True

    except Exception as exc:
        print(f"ERROR: 100_firmware.install failed: {exc}")
        return False
