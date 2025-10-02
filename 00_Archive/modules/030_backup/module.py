#!/usr/bin/env python3
"""
modules/030_backup/module.py

Btrfs + GRUB backup module for your provisioning framework.

Assumptions (per project README / requirements):
- Root filesystem is ALWAYS Btrfs.
- GRUB is installed.
- Off-machine backups are out-of-scope for this module.

What this module does
---------------------
1) Installs backup stack packages:
   - btrfs-progs, snapper, snap-pac (pre/post pacman snapshots)
   - grub-btrfs + inotify-tools (GRUB submenu for snapshots via daemon)
2) Ensures Snapper root config exists and is sane.
   - Creates `/.snapshots` subvolume if needed (via `snapper create-config`).
   - Enables timeline + cleanup systemd timers.
   - Tunes conservative retention limits (editable later).
3) Adds a small pacman post-transaction hook to record package lists in /var/backups.

Idempotency
-----------
- Safe re-runs: checks for existing config/timers/files before changing anything.
- Prints shell-like actions; surfaces stdout/stderr on failures.

Returns True on success, False on any failure (so the orchestrator can stop).
"""

from __future__ import annotations

from typing import Callable, Optional
import shlex

from utils.pacman import install_packages as pacman_install

# ------------------------------- helpers ------------------------------------

def _run_ok(run: Callable, cmd: list[str], *, input_text: Optional[str] = None) -> bool:
    res = run(cmd, check=False, capture_output=True, input_text=input_text)
    if res.returncode != 0:
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
        return False
    if res.stdout:
        print(res.stdout.rstrip())
    if res.stderr:
        print(res.stderr.rstrip())
    return True


def _systemd_enable_now(run: Callable, unit: str) -> bool:
    return _run_ok(run, ["systemctl", "enable", "--now", unit])


def _file_exists(run: Callable, path: str) -> bool:
    return run(["test", "-e", path], check=False).returncode == 0


def _is_enabled(run: Callable, unit: str) -> bool:
    return run(["systemctl", "is-enabled", "--quiet", unit], check=False).returncode == 0


def _write_root_file(run: Callable, path: str, content: str, mode: str = "0644") -> bool:
    # Use `install` to atomically create/update with permissions.
    cmd = [
        "bash",
        "-lc",
        f"install -D -m {shlex.quote(mode)} /dev/stdin {shlex.quote(path)}",
    ]
    return _run_ok(run, cmd, input_text=content)


def _append_root_file(run: Callable, path: str, content: str) -> bool:
    cmd = ["bash", "-lc", f"mkdir -p $(dirname {shlex.quote(path)}) && tee -a {shlex.quote(path)} >/dev/null"]
    return _run_ok(run, cmd, input_text=content)


def _detect_fs(run: Callable) -> str:
    res = run(["findmnt", "-n", "-o", "FSTYPE", "/"], check=False, capture_output=True)
    return (res.stdout or "").strip()


# ------------------------------- snapper ------------------------------------

def _ensure_snapper_root_config(run: Callable) -> bool:
    # Ensure /.snapshots exists and root config is present. We let `snapper create-config` do the right thing.
    if _file_exists(run, "/etc/snapper/configs/root"):
        print("snapper root config already present.")
        return True

    print("Creating snapper root config for '/'.")
    # This will create /.snapshots as a subvolume (if needed) and a default config.
    # It can fail if /.snapshots is a plain dir or already a separate subvolume with unexpected layout; we continue with a warning.
    if not _run_ok(run, ["snapper", "-c", "root", "create-config", "/"]):
        print("⚠️  'snapper create-config' failed. If /.snapshots already exists from installer, this can be safe to ignore.")
        # Even when it failed, it's possible the config file actually exists now. Re-check:
        if not _file_exists(run, "/etc/snapper/configs/root"):
            return False

    # Permissions as recommended (root:root 750) — tolerate errors if mount is odd; do not fail the run.
    _run_ok(run, ["bash", "-lc", "chown root:root /.snapshots 2>/dev/null || true" ])
    _run_ok(run, ["bash", "-lc", "chmod 750 /.snapshots 2>/dev/null || true" ])
    return True


def _tune_snapper_limits(run: Callable) -> bool:
    # Conservative defaults; can be edited later in /etc/snapper/configs/root
    edits = [
        r"sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE=\"yes\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP=\"yes\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY=\"8\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY=\"7\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY=\"4\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY=\"12\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY=\"0\"/' /etc/snapper/configs/root || true",
    ]
    for line in edits:
        if not _run_ok(run, ["bash", "-lc", line]):
            return False
    return True


def _enable_snapper_timers(run: Callable) -> bool:
    ok = True
    if not _is_enabled(run, "snapper-timeline.timer"):
        ok = ok and _systemd_enable_now(run, "snapper-timeline.timer")
    if not _is_enabled(run, "snapper-cleanup.timer"):
        ok = ok and _systemd_enable_now(run, "snapper-cleanup.timer")
    return ok


# ------------------------------- pacman hook --------------------------------

def _ensure_pkglist_hook(run: Callable) -> bool:
    path = "/etc/pacman.d/hooks/95-backup-pkglist.hook"
    if _file_exists(run, path):
        return True
    content = """[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Save package lists to /var/backups (explicit and foreign)
When = PostTransaction
Exec = /bin/bash -lc 'install -d -m 0755 /var/backups && pacman -Qqe > /var/backups/pkglist-explicit.txt && pacman -Qqm > /var/backups/pkglist-aur.txt || true'
"""
    return _write_root_file(run, path, content, mode="0644")


# ------------------------------- grub-btrfs ---------------------------------

def _enable_grub_btrfsd(run: Callable) -> bool:
    # Start/enabled so GRUB submenu updates when snapshots change.
    return _systemd_enable_now(run, "grub-btrfsd.service")


# --------------------------------- main -------------------------------------

def install(run: Callable) -> bool:
    try:
        print("▶ [030_backup] Setting up Btrfs snapshots (snapper) and GRUB integration…")

        # 0) Assert Btrfs root
        fstype = _detect_fs(run)
        if fstype.lower() != "btrfs":
            print(f"ERROR: Expected Btrfs root, but detected: {fstype or 'unknown'}")
            return False

        # 1) Packages
        pkgs = [
            "btrfs-progs",
            "snapper",
            "snap-pac",
            "grub-btrfs",
            "inotify-tools",
        ]
        if not pacman_install(pkgs, run):
            return False

        # 2) Snapper root config & limits
        if not _ensure_snapper_root_config(run):
            return False
        if not _tune_snapper_limits(run):
            return False
        if not _enable_snapper_timers(run):
            return False

        # 3) Pacman hook to save package lists (optional but helpful)
        if not _ensure_pkglist_hook(run):
            return False

        # 4) GRUB snapshot submenu daemon
        if not _enable_grub_btrfsd(run):
            return False

        print("✔ [030_backup] Backup stack configured: snapper + snap-pac + grub-btrfs.")
        return True

    except Exception as exc:
        print(f"ERROR: 030_backup.install failed: {exc}")
        return False
