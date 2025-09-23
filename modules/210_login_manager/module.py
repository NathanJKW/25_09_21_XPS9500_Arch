#!/usr/bin/env python3
"""
210_login_manager — SDDM (Qt6) with local dark theme (unattended + session-safe)

What this module does
---------------------
- Installs SDDM and required Qt6 packages.
- Copies local theme from ./theme/ -> /usr/share/sddm/themes/<THEME_NAME>.
- Backs up & removes old theme-related SDDM configs, then writes /etc/sddm.conf.d/10-theme.conf.
- Service changes are SAFE:
    * If a display manager is currently active, SKIP touching services (to avoid logging you out).
    * If no DM is active (e.g., running from a TTY), enable SDDM for next boot and disable/mask LightDM.

Idempotency & Safety
--------------------
- pacman installs via utils.pacman.install_packages (uses --needed).
- Config written atomically via install -D; existing theme dir backed up per run.
- No live start/stop and no target switch during the run.
"""

from __future__ import annotations

import shlex
import subprocess
from pathlib import Path
from typing import Callable, Optional

from utils.pacman import install_packages

# ----------------------------- constants -----------------------------

THEME_NAME = "simple-sddm-2"  # destination folder name under /usr/share/sddm/themes/
MODULE_DIR = Path(__file__).resolve().parent
THEME_SRC = MODULE_DIR / "theme"                       # theme files live directly here
THEME_DST = Path("/usr/share/sddm/themes") / THEME_NAME

CONF_DIR = Path("/etc/sddm.conf.d")
CONF_FILE = CONF_DIR / "10-theme.conf"
LEGACY_CONF = Path("/etc/sddm.conf")

SDDM_CONF_CONTENT = f"""# Installed by 210_login_manager
[Theme]
Current={THEME_NAME}

[General]
# Enable Qt virtual keyboard (commonly expected by Qt6 themes)
InputMethod=qtvirtualkeyboard
"""

# ----------------------------- helpers -----------------------------

def _print_action(text: str) -> None:
    print(f"$ {text}")

def _run_ok(run: Callable, cmd: list[str], *, input_text: Optional[str] = None) -> bool:
    _print_action(" ".join(shlex.quote(c) for c in cmd))
    res = run(cmd, check=False, capture_output=True, input_text=input_text)
    if res.stdout:
        print(res.stdout.rstrip())
    if res.stderr:
        print(res.stderr.rstrip())
    return res.returncode == 0

def _run_user(cmd: list[str]) -> None:
    """Run a harmless command as the invoking user (no sudo)."""
    print("$ " + " ".join(cmd))
    res = subprocess.run(cmd, check=False, text=True, capture_output=True)
    if res.stdout:
        print(res.stdout.rstrip())
    if res.stderr:
        print(res.stderr.rstrip())

def _file_contains(run: Callable, path: Path, pattern: str) -> bool:
    """True if file exists and matches pattern (extended regex)."""
    res = run(
        ["bash", "-lc", f'[[ -f {shlex.quote(str(path))} ]] && grep -Eq {shlex.quote(pattern)} {shlex.quote(str(path))}'],
        check=False
    )
    return res.returncode == 0

def _clean_old_theme_confs(run: Callable) -> bool:
    """
    Back up & remove old/conflicting SDDM theme settings:
      - /etc/sddm.conf.d/*.conf that contain [Theme] or Current=
      - legacy /etc/sddm.conf if it contains [Theme]/Current=
    """
    dropins = rf"""
set -e
dir={shlex.quote(str(CONF_DIR))}
ts=$(date +%Y%m%d-%H%M%S)
backup="$dir/.backup-$ts"
mkdir -p "$backup"
shopt -s nullglob
for f in "$dir"/*.conf; do
  if grep -Eq '^\[Theme\]|^Current=' "$f"; then
    mv "$f" "$backup"/
  fi
done
"""
    if not _run_ok(run, ["bash", "-lc", dropins]):
        return False

    if _file_contains(run, LEGACY_CONF, r'^\[Theme\]|^Current='):
        legacy = rf"""
set -e
f={shlex.quote(str(LEGACY_CONF))}
ts=$(date +%Y%m%d-%H%M%S)
backup=$(dirname "$f")/.backup-$ts
mkdir -p "$backup"
mv "$f" "$backup"/
"""
        if not _run_ok(run, ["bash", "-lc", legacy]):
            return False
    return True

def _write_conf(run: Callable) -> bool:
    return _run_ok(
        run,
        ["install", "-Dm0644", "/dev/stdin", str(CONF_FILE)],
        input_text=SDDM_CONF_CONTENT,
    )

def _backup_then_replace_theme(run: Callable) -> bool:
    """
    Copy ./theme -> /usr/share/sddm/themes/<THEME_NAME>
    If destination exists, back it up under /usr/share/sddm/themes/.backup-<timestamp>/
    """
    if not THEME_SRC.exists() or not THEME_SRC.is_dir():
        print(f"ERROR: Missing theme source directory: {THEME_SRC}")
        print("       Put your theme files directly under modules/210_login_manager/theme/")
        return False

    script = rf"""
set -e
src={shlex.quote(str(THEME_SRC))}
dst={shlex.quote(str(THEME_DST))}
parent=$(dirname "$dst")
mkdir -p "$parent"
if [ -e "$dst" ] || [ -L "$dst" ]; then
  ts=$(date +%Y%m%d-%H%M%S)
  mkdir -p "$parent/.backup-$ts"
  mv "$dst" "$parent/.backup-$ts"/ 2>/dev/null || true
fi
cp -a "$src" "$dst"
"""
    return _run_ok(run, ["bash", "-lc", script])

def _display_manager_active(run: Callable) -> bool:
    """
    Detect if any display manager is currently active.
    We check the generic display-manager.service and common DMs.
    """
    checks = [
        ["systemctl", "is-active", "--quiet", "display-manager.service"],
        ["systemctl", "is-active", "--quiet", "sddm.service"],
        ["systemctl", "is-active", "--quiet", "lightdm.service"],
        ["systemctl", "is-active", "--quiet", "gdm.service"],
        ["systemctl", "is-active", "--quiet", "ly.service"],
    ]
    for cmd in checks:
        res = run(cmd, check=False)
        if res.returncode == 0:
            return True
    return False

def _configure_services_safely(run: Callable) -> bool:
    """
    Safe service configuration:
      - If a display manager is currently active, SKIP touching services to avoid logout.
      - Otherwise (TTY/new install), disable LightDM, enable SDDM for next boot.
    """
    if _display_manager_active(run):
        print("ℹ️  A display manager is currently active; skipping service changes to avoid logging you out.")
        print("    SDDM + theme are installed. After provisioning, you can switch with:")
        print("      sudo systemctl disable lightdm.service && sudo systemctl mask lightdm.service")
        print("      sudo systemctl unmask sddm.service && sudo systemctl enable sddm.service")
        print("      sudo reboot")
        return True

    ok = True
    _run_ok(run, ["systemctl", "disable", "lightdm.service"])
    _run_ok(run, ["systemctl", "mask", "lightdm.service"])
    _run_ok(run, ["systemctl", "unmask", "sddm.service"])
    if not _run_ok(run, ["systemctl", "enable", "sddm.service"]):
        ok = False
    return ok

# ----------------------------- main entry -----------------------------

def install(run: Callable) -> bool:
    try:
        print("▶ [210_login_manager] Installing SDDM + dark theme (session-safe)…")

        # 1) Packages
        pkgs = [
            "sddm",
            "qt6-svg",
            "qt6-virtualkeyboard",
            "qt6-multimedia-ffmpeg",
            "qt6-declarative",
        ]
        if not install_packages(pkgs, run):
            print("ERROR: Failed to install required packages.")
            return False

        # 2) Ensure drop-in dir, clean old theme configs
        if not _run_ok(run, ["mkdir", "-p", str(CONF_DIR)]):
            return False
        if not _clean_old_theme_confs(run):
            print("ERROR: Failed to clean old SDDM theme configs.")
            return False

        # 3) Deploy theme
        if not _backup_then_replace_theme(run):
            print("ERROR: Failed to deploy theme to /usr/share/sddm/themes/")
            return False

        # 4) Write authoritative theme drop-in
        if not _write_conf(run):
            print("ERROR: Failed to write SDDM theme drop-in.")
            return False

        # 5) Configure services safely (no live switch; skip if a DM is active)
        if not _configure_services_safely(run):
            print("ERROR: Failed to configure display manager services.")
            return False

        # 6) Best-effort visibility (non-fatal; run as user to avoid sudo hang)
        _run_user(["bash", "-lc", "pacman -Q sddm || true"])
        _run_user(["bash", "-lc", "command -v sddm >/dev/null 2>&1 && sddm --version || true"])

        print("✔ [210_login_manager] Ready. Reboot (or switch later) to use SDDM with your dark theme.")
        print(f"   Theme: {THEME_DST}")
        print(f"   Config: {CONF_FILE}")
        return True

    except Exception as exc:
        print(f"ERROR: 210_login_manager.install failed: {exc}")
        return False
