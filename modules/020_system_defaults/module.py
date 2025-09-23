#!/usr/bin/env python3
"""
020_system-defaults

Applies safe, SSD-friendly system defaults:
- journald: persistent logs with size + time caps
- sysctl: zram-leaning VM knobs + higher inotify limits for dev workflows
- logrotate: ensure installed for non-journald apps
- time sync: enable systemd-timesyncd

Re-run safe (idempotent). Uses the provided sudo runner (`run`) from start_sudo_session().
"""

from __future__ import annotations
from typing import Callable

JOURNALD_DROPIN = "/etc/systemd/journald.conf.d/10-defaults.conf"
JOURNALD_CONTENT = """# Installed by 020_system-defaults (drop-in)
[Journal]
# Persist logs across boots (falls back to /run early in boot)
Storage=persistent
Compress=yes
Seal=yes

# Bound persistent and runtime usage on SSD
SystemMaxUse=200M
SystemKeepFree=50M
RuntimeMaxUse=50M

# Cap per-file duration and overall retention window
MaxFileSec=1week
MaxRetentionSec=1month
"""

SYSCTL_FILE = "/etc/sysctl.d/99-system-defaults.conf"
SYSCTL_CONTENT = """# Installed by 020_system-defaults
# With zram swap enabled, prefer swapping to compressed memory over dropping caches too eagerly.
vm.swappiness=100
# Keep inode/dentry caches around a bit longer (default is 100)
vm.vfs_cache_pressure=50

# Larger file-watch budgets for modern IDE/build tools/sync clients
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=1024
fs.inotify.max_queued_events=32768

# NOTE: If you use zram, consider leaving zswap disabled to avoid double-compression.
# That toggle (if needed) should live in the module that sets up zram.
"""

def _write_file(path: str, content: str, run: Callable) -> bool:
    """Create parent directory and write file via tee (works with sudo -n)."""
    parent = path.rsplit("/", 1)[0]
    print(f"$ mkdir -p {parent}")
    r = run(["mkdir", "-p", parent], check=False, capture_output=True)
    if r.returncode != 0:
        if r.stdout: print(r.stdout.rstrip())
        if r.stderr: print(r.stderr.rstrip())
        return False

    print(f"$ tee {path}  # write drop-in")
    r = run(["tee", path], check=False, capture_output=True, input_text=content)
    if r.returncode != 0:
        if r.stdout: print(r.stdout.rstrip())
        if r.stderr: print(r.stderr.rstrip())
        return False
    return True

def _install_packages(pkgs: list[str], run: Callable) -> bool:
    try:
        from utils.pacman import install_packages
        return install_packages(pkgs, run)
    except Exception as exc:
        print(f"ERROR: failed to install packages {pkgs}: {exc}")
        return False

def install(run: Callable) -> bool:
    try:
        print("▶ [020_system-defaults] Applying system defaults...")

        # 1) journald drop-in
        if not _write_file(JOURNALD_DROPIN, JOURNALD_CONTENT, run):
            print("❌ Failed writing journald drop-in.")
            return False

        # 2) sysctl defaults
        if not _write_file(SYSCTL_FILE, SYSCTL_CONTENT, run):
            print("❌ Failed writing sysctl defaults.")
            return False

        # 3) logrotate (for apps that still write plaintext logs)
        if not _install_packages(["logrotate"], run):
            print("❌ Failed installing logrotate.")
            return False

        # 4) Enable time sync (ok if already enabled)
        print("$ systemctl enable --now systemd-timesyncd.service")
        r = run(["systemctl", "enable", "--now", "systemd-timesyncd.service"], check=False, capture_output=True)
        if r.stdout: print(r.stdout.rstrip())
        if r.stderr: print(r.stderr.rstrip())

        # Apply changes
        print("$ systemctl restart systemd-journald")
        r = run(["systemctl", "restart", "systemd-journald"], check=False, capture_output=True)
        if r.returncode != 0:
            if r.stdout: print(r.stdout.rstrip())
            if r.stderr: print(r.stderr.rstrip())
            return False

        print("$ sysctl --system  # load /etc/sysctl.d/*")
        r = run(["sysctl", "--system"], check=False, capture_output=True)
        if r.stdout: print(r.stdout.rstrip())
        if r.stderr: print(r.stderr.rstrip())
        if r.returncode != 0:
            return False

        print("✔ [020_system-defaults] Complete.")
        return True

    except Exception as exc:
        print(f"ERROR: 020_system-defaults.install failed: {exc}")
        return False
