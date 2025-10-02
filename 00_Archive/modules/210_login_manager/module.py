"""
210_login_manager/module.py

Set up SDDM as the display/login manager.

- Installs sddm (Qt6 build).
- Enables it as a system service.
- Deploys a custom theme if present under modules/210_login_manager/theme/
- Configures /etc/sddm.conf.d/10-theme.conf to point at that theme if deployed.

Notes:
- Enabling the service is safe while you're in a running session; it just takes effect on next boot.
"""

import shutil
from pathlib import Path
from typing import Callable

from utils.pacman import install_packages

THEME_SRC = Path(__file__).parent / "theme"
THEME_DST = Path("/usr/share/sddm/themes")
CONF_DIR = Path("/etc/sddm.conf.d")
CONF_FILE = CONF_DIR / "10-theme.conf"

SDDM_CONF_CONTENT = """[Theme]
Current=arch-bootstrap
"""

def _print_action(msg: str) -> None:
    print(f"$ {msg}")

def _run_ok(run: Callable, cmd: list[str], input_text: str | None = None) -> bool:
    """
    Run a command via the sudo runner. The sudo runner expects 'input_text'
    and already sets text=True internally.
    """
    try:
        result = run(cmd, check=False, capture_output=True, input_text=input_text)
        if result.returncode != 0:
            # Prefer stderr if available, otherwise a generic failure line.
            print(result.stderr or f"Command failed: {' '.join(cmd)}")
            return False
        # Surface stdout/stderr for visibility on success too (they may contain useful info).
        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            print(result.stderr.rstrip())
        return True
    except Exception as e:
        print(f"ERROR running {' '.join(cmd)}: {e}")
        return False

def _backup_then_replace_theme(run: Callable) -> bool:
    if not THEME_SRC.exists() or not THEME_SRC.is_dir():
        print(f"ℹ️  Theme source not found: {THEME_SRC}")
        print("    Skipping theme deployment; SDDM will use its default theme.")
        return True

    dst = THEME_DST / "arch-bootstrap"
    if dst.exists():
        backup = dst.with_suffix(".bak")
        _print_action(f"Backing up existing theme at {dst} -> {backup}")
        run(["cp", "-a", str(dst), str(backup)], check=False)

    _print_action(f"Installing custom theme -> {dst}")
    try:
        run(["mkdir", "-p", str(THEME_DST)], check=False)
        run(["cp", "-a", str(THEME_SRC), str(dst)], check=False)
        return True
    except Exception as e:
        print(f"ERROR copying theme: {e}")
        return False

def _write_conf(run: Callable) -> bool:
    _print_action(f"install -Dm0644 /dev/stdin {CONF_FILE}")
    return _run_ok(
        run,
        ["install", "-Dm0644", "/dev/stdin", str(CONF_FILE)],
        input_text=SDDM_CONF_CONTENT,
    )

def install(run: Callable) -> bool:
    # 1) Install sddm
    if not install_packages(["sddm"], run):
        return False

    # 2) Enable service (safe to do while a session is running; it activates on next boot)
    _print_action("systemctl enable sddm.service")
    run(["systemctl", "enable", "sddm.service"], check=False)

    # 3) Deploy theme (optional)
    if not _backup_then_replace_theme(run):
        print("ERROR: Failed during theme deployment step.")
        return False

    # 4) Write authoritative theme drop-in only if theme was actually deployed
    theme_installed = (THEME_DST / "arch-bootstrap").exists()
    if theme_installed:
        if not _write_conf(run):
            print("ERROR: Failed to write SDDM theme drop-in.")
            return False
    else:
        print("ℹ️  No custom theme present; skipping /etc/sddm.conf.d/10-theme.conf write.")

    return True
