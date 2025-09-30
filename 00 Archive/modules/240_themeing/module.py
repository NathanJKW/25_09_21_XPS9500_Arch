#!/usr/bin/env python3
"""
240_themeing — Dark theme baseline (Nord-centric) — FIXED:
- Install Bibata cursor from AUR (not pacman).
- Fall back to Adwaita cursor if Bibata not present (no hard fail).
"""

from __future__ import annotations
from typing import Callable, Optional
import shlex

from utils.pacman import install_packages as pacman_install
try:
    from utils.yay import install_packages as yay_install
except Exception:
    yay_install = None  # yay optional

GTK_THEME_NAME = "Nordic"                   # AUR: nordic-theme
ICON_THEME_NAME = "Papirus-Dark"            # repo: papirus-icon-theme
CURSOR_THEME_NAME = "Bibata-Modern-Ice"     # AUR: bibata-cursor-theme
CURSOR_FALLBACK = "Adwaita"                 # safe fallback if Bibata missing
QT_STYLE = "kvantum"
KVANTUM_THEME_NAME = "Nordic-Darker"        # AUR: kvantum-theme-nordic
GTK_FALLBACK_THEME = "Adwaita-dark"         # repo fallback if Nordic missing

def _run_ok(run: Callable, cmd: list[str], *, input_text: Optional[str] = None) -> bool:
    print("$ " + " ".join(shlex.quote(c) for c in cmd))
    res = run(cmd, check=False, capture_output=True, input_text=input_text)
    if res.stdout: print(res.stdout.rstrip())
    if res.stderr: print(res.stderr.rstrip())
    return res.returncode == 0

def _write_file(run: Callable, path: str, content: str) -> bool:
    return _run_ok(run, ["install", "-Dm0644", "/dev/stdin", path], input_text=content)

def _path_exists(run: Callable, path: str) -> bool:
    return run(["test", "-e", path], check=False).returncode == 0

# ---------- config writers ----------

def _apply_gtk_defaults(run: Callable, gtk_theme_name: str) -> bool:
    gtk = f"""[Settings]
gtk-theme-name={gtk_theme_name}
gtk-icon-theme-name={ICON_THEME_NAME}
gtk-application-prefer-dark-theme=1
"""
    return _write_file(run, "/etc/gtk-3.0/settings.ini", gtk) and \
           _write_file(run, "/etc/gtk-4.0/settings.ini", gtk)

def _apply_cursor_default(run: Callable, cursor_name: str) -> bool:
    index_theme = f"""[Icon Theme]
Inherits={cursor_name}
"""
    return _write_file(run, "/usr/share/icons/default/index.theme", index_theme)

def _apply_qt_defaults(run: Callable, kvantum_available: bool) -> bool:
    style = QT_STYLE if kvantum_available else "Fusion"
    qt_common = f"""[Appearance]
style={style}
icon_theme={ICON_THEME_NAME}
"""
    return _write_file(run, "/etc/xdg/qt5ct/qt5ct.conf", qt_common) and \
           _write_file(run, "/etc/xdg/qt6ct/qt6ct.conf", qt_common)

def _apply_kvantum_theme(run: Callable, theme_name: str) -> bool:
    # Require engine AND theme presence to write config; otherwise skip silently.
    engine_present = _path_exists(run, "/usr/bin/kvantummanager") or \
                     _path_exists(run, "/usr/lib/qt/plugins/styles/libkvantum.so")
    theme_present = _path_exists(run, f"/usr/share/Kvantum/{theme_name}")
    if not (engine_present and theme_present):
        return True
    kv_cfg = f"[General]\ntheme={theme_name}\n"
    return _write_file(run, "/etc/xdg/Kvantum/kvantum.kvconfig", kv_cfg)

# ---------- installs ----------

def _install_repo_packages(run: Callable) -> bool:
    pkgs = [
        "papirus-icon-theme",    # icons (repo)
        # cursor moved to AUR
        "qt5ct", "qt6ct", "kvantum",
        "gtk-engine-murrine",
    ]
    return pacman_install(pkgs, run)

def _install_aur_packages() -> bool:
    if yay_install is None:
        print("⚠️  'yay' not available; skipping AUR themes (Nordic, Bibata, Kvantum Nordic).")
        return True  # non-fatal; we’ll fall back where needed
    pkgs = [
        "nordic-theme",            # GTK Nord
        "bibata-cursor-theme",     # Bibata cursor (AUR)
        "kvantum-theme-nordic",    # Kvantum Nord
    ]
    return yay_install(pkgs)

def install(run: Callable) -> bool:
    try:
        print("▶ [240_themeing] Applying system dark theme defaults (Nord-centric)…")

        if not _install_repo_packages(run):
            print("❌ Failed installing base theming packages from repos.")
            return False

        if not _install_aur_packages():
            print("⚠️  AUR theming packages failed to install. Continuing with fallbacks.")

        kvantum_available = _path_exists(run, "/usr/share/Kvantum") or \
                            _path_exists(run, "/usr/lib/qt/plugins/styles/libkvantum.so")

        # Choose GTK theme based on presence; fallback to repo theme if AUR Nordic missing
        nordic_present = _path_exists(run, "/usr/share/themes/Nordic")
        gtk_to_set = GTK_THEME_NAME if nordic_present else GTK_FALLBACK_THEME
        if not _apply_gtk_defaults(run, gtk_theme_name=gtk_to_set):
            print("❌ Failed writing GTK defaults.")
            return False

        # Cursor: prefer Bibata if installed, otherwise fallback to Adwaita
        bibata_present = _path_exists(run, f"/usr/share/icons/{CURSOR_THEME_NAME}")
        cursor_to_set = CURSOR_THEME_NAME if bibata_present else CURSOR_FALLBACK
        if not bibata_present:
            print(f"⚠️  Bibata cursor not found in /usr/share/icons; using fallback cursor: {CURSOR_FALLBACK}")
        if not _apply_cursor_default(run, cursor_to_set):
            print("❌ Failed setting system cursor default.")
            return False

        # Qt defaults + optional Kvantum theme
        if not _apply_qt_defaults(run, kvantum_available=kvantum_available):
            print("❌ Failed writing Qt defaults.")
            return False
        _apply_kvantum_theme(run, KVANTUM_THEME_NAME)

        # Visibility (non-fatal)
        _run_ok(run, ["bash", "-lc", "echo GTK3 -> && cat /etc/gtk-3.0/settings.ini || true"])
        _run_ok(run, ["bash", "-lc", "echo GTK4 -> && cat /etc/gtk-4.0/settings.ini || true"])
        _run_ok(run, ["bash", "-lc", "echo Cursor -> && cat /usr/share/icons/default/index.theme || true"])
        _run_ok(run, ["bash", "-lc", "echo qt5ct -> && cat /etc/xdg/qt5ct/qt5ct.conf || true"])
        _run_ok(run, ["bash", "-lc", "echo qt6ct -> && cat /etc/xdg/qt6ct/qt6ct.conf || true"])

        print("""
Tips:
  • If Bibata didn’t install, run:  yay -S bibata-cursor-theme
    Then re-run this module to switch system cursor to Bibata.
  • Papirus icons & Kvantum engine are from official repos.
  • Per-user fine-tuning (recommended):
      ~/.config/gtk-3.0/settings.ini, ~/.config/gtk-4.0/settings.ini
      ~/.config/qt5ct/qt5ct.conf, ~/.config/qt6ct/qt6ct.conf
      ~/.config/Kvantum/kvantum.kvconfig
""".rstrip())

        print("✔ [240_themeing] Dark theme defaults applied (with safe fallbacks).")
        return True

    except Exception as exc:
        print(f"ERROR: 240_themeing.install failed: {exc}")
        return False
