#!/usr/bin/env python3
"""
110_power — Laptop power & thermal baseline (driver-agnostic)

What it does
------------
- Installs and enables: TLP + thermald (powertop optional for diagnostics)
- Masks power-profiles-daemon to avoid conflicts with TLP
- Applies a small TLP drop-in with conservative, safe defaults
- No GPU/driver-specific settings here (those live in 130_gpu)

Idempotent and safe to run on fresh systems before graphics drivers are present.
"""

from __future__ import annotations
from pathlib import Path
from typing import Callable
from utils.pacman import install_packages

TLP_DROPIN = "/etc/tlp.d/10-laptop-baseline.conf"


def _write_file(run: Callable, path: str, content: str) -> bool:
    """Create parent dir, back up existing file, then write content via tee."""
    try:
        parent = Path(path).parent
        # mkdir -p
        res = run(["mkdir", "-p", str(parent)], check=False, capture_output=True)
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False

        # backup if present
        res = run(
            ["bash", "-lc", f"if [ -f '{path}' ]; then cp -a '{path}' '{path}.bak.$(date +%Y%m%d-%H%M%S)'; fi"],
            check=False,
            capture_output=True,
        )
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False

        # write
        res = run(["tee", path], check=False, capture_output=True, input_text=content)
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False

        return True
    except Exception as exc:
        print(f"ERROR: writing {path} failed: {exc}")
        return False


def install(run: Callable) -> bool:
    try:
        print("▶ [110_power] Installing baseline power/thermal tools...")

        # Packages: tlp, thermald, powertop (diagnostics only)
        if not install_packages(["tlp", "tlp-rdw", "thermald", "powertop"], run):
            return False

        # Avoid conflicts: mask power-profiles-daemon if it exists
        run(["systemctl", "mask", "--now", "power-profiles-daemon.service"], check=False)

        # Recommended by TLP when using RDW: mask rfkill units (harmless if absent)
        run(["systemctl", "mask", "--now", "systemd-rfkill.service", "systemd-rfkill.socket"], check=False)

        # Conservative, driver-agnostic TLP overrides
        tlp_dropin = """# /etc/tlp.d/10-laptop-baseline.conf — safe defaults (driver-agnostic)

# CPU energy/perf (Intel HWP capable CPUs use EPP underneath)
CPU_DRIVER_OPMODE_ON_AC=active
CPU_DRIVER_OPMODE_ON_BAT=active
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# Runtime PM: allow autosuspend on both AC and battery for general devices
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

# USB autosuspend: leave default (kernel/TLP decide); uncomment to force
# USB_AUTOSUSPEND=1

# SATA link power management: keep defaults; uncomment to experiment
# SATA_LINKPWR_ON_AC=max_performance
# SATA_LINKPWR_ON_BAT=med_power_with_dipm

# Notes:
# - GPU-specific settings (NVIDIA DynamicPowerManagement, i915 PSR/FBC, etc.)
#   are intentionally NOT set here. Apply them in modules/130_gpu after drivers.
"""
        if not _write_file(run, TLP_DROPIN, tlp_dropin):
            return False

        # Enable services
        for args in (["enable", "--now", "tlp.service"],
                     ["enable", "--now", "thermald.service"]):
            res = run(["systemctl", *args], check=False, capture_output=True)
            if res.returncode != 0:
                if res.stdout: print(res.stdout.rstrip())
                if res.stderr: print(res.stderr.rstrip())
                return False

        # Helpful (optional) dispatcher for TLP RDW features if you use them later
        run(["systemctl", "enable", "--now", "NetworkManager-dispatcher.service"], check=False)

        print("✔ [110_power] Baseline applied: TLP + thermald active, conflicts masked.")
        print("   GPU/driver-specific power tuning will be handled in 130_gpu.")
        return True

    except Exception as exc:
        print(f"ERROR: 110_power.install failed: {exc}")
        return False
