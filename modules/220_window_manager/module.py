#!/usr/bin/env python3
"""
220_window_manager — i3 on X11 (with rofi, picom, dunst, polkit agent)

What this module does
---------------------
- Installs a standard i3 X11 stack:
  * Core: i3-wm, i3status
  * Launcher: rofi
  * Lock/idle helpers: i3lock, xss-lock, xorg-xset
  * UX: picom (compositor), dunst (notifications), feh (wallpaper), arandr (displays), xclip (clipboard)
  * QoL: playerctl, brightnessctl, flameshot, lxappearance
  * Polkit agent: polkit-gnome
- Prints post-install tips and quick tests.
- Does NOT write per-user config and does NOT touch display manager services.

Idempotency & Safety
--------------------
- Pacman installs via utils.pacman.install_packages (uses --needed).
- No service changes here (210_login_manager handles DM).
- No writes to $HOME or /etc configs for i3/rofi/picom/dunst (leave to 4xx dotfiles).

i3 config snippet (put this in your dotfiles, e.g. ~/.config/i3/config)
-----------------------------------------------------------------------
# Launcher
bindsym $mod+d exec rofi -show drun

# Idle + lock (example timings)
exec --no-startup-id xset s 300 60
exec --no-startup-id xset +dpms
exec --no-startup-id xss-lock -n /usr/share/doc/xss-lock/dim-screen.sh -- i3lock -n

# Compositor, notifications, polkit agent
exec --no-startup-id picom --experimental-backends
exec --no-startup-id dunst
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# QoL helpers (optional binds)
# bindsym XF86AudioPlay exec playerctl play-pause
# bindsym XF86MonBrightnessUp exec brightnessctl set +5%
# bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
# bindsym $mod+Print exec flameshot gui
"""

from __future__ import annotations
from typing import Callable, Iterable
import subprocess

from utils.pacman import install_packages


# ------------------------------- helpers -------------------------------------

def _print(msg: str) -> None:
    print(msg)


def _run_user(cmd: Iterable[str]) -> None:
    """Run a harmless command as the invoking user (no sudo)."""
    _print("$ " + " ".join(cmd))
    try:
        res = subprocess.run(list(cmd), check=False, text=True, capture_output=True)
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
    except Exception as exc:
        print(f"⚠️  Skipping user command {' '.join(cmd)}: {exc}")


def _check_presence() -> None:
    """Best-effort visibility: show versions and presence of key tools."""
    _run_user(["bash", "-lc", "i3 --version || true"])
    _run_user(["bash", "-lc", "rofi -v || true"])
    _run_user(["bash", "-lc", "command -v i3lock >/dev/null 2>&1 && echo 'i3lock present' || echo 'i3lock missing'"])
    _run_user(["bash", "-lc", "command -v xss-lock >/dev/null 2>&1 && echo 'xss-lock present' || echo 'xss-lock missing'"])
    _run_user(["bash", "-lc", "command -v picom >/dev/null 2>&1 && echo 'picom present' || echo 'picom missing'"])
    _run_user(["bash", "-lc", "command -v dunst >/dev/null 2>&1 && echo 'dunst present' || echo 'dunst missing'"])
    _run_user(["bash", "-lc", "command -v xset  >/dev/null 2>&1 && echo 'xset present'  || echo 'xset missing'"])
    _run_user(["bash", "-lc", "command -v playerctl >/dev/null 2>&1 && echo 'playerctl present' || echo 'playerctl missing'"])
    _run_user(["bash", "-lc", "command -v brightnessctl >/dev/null 2>&1 && echo 'brightnessctl present' || echo 'brightnessctl missing'"])
    _run_user(["bash", "-lc", "command -v flameshot >/dev/null 2>&1 && echo 'flameshot present' || echo 'flameshot missing'"])
    _run_user(["bash", "-lc", "command -v lxappearance >/dev/null 2>&1 && echo 'lxappearance present' || echo 'lxappearance missing'"])
    _run_user(["bash", "-lc", "command -v /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 && echo 'polkit-gnome agent present' || echo 'polkit-gnome agent missing'"])


# ------------------------------- main ----------------------------------------

def install(run: Callable) -> bool:
    try:
        _print("▶ [220_window_manager] Installing i3 (X11) stack + helpers…")

        pkgs = [
            # Core WM stack
            "i3-wm",
            "i3status",

            # Launcher
            "rofi",

            # Lock / idle helpers
            "i3lock",
            "xss-lock",
            "xorg-xset",

            # UX & compositor & utilities
            "picom",
            "dunst",
            "feh",
            "arandr",
            "xclip",

            # QoL
            "playerctl",
            "brightnessctl",
            "flameshot",
            "lxappearance",

            # Polkit agent for GUI auth prompts
            "polkit-gnome",
        ]

        if not install_packages(pkgs, run):
            _print("❌ [220_window_manager] Package installation failed.")
            return False

        # Session integration: i3 desktop file is provided by i3-wm under /usr/share/xsessions/i3.desktop.
        _print("ℹ️  i3 session installed. Your display manager (e.g., SDDM) should list 'i3' as a session option.")

        # Best-effort diagnostics (non-fatal)
        _check_presence()

        # Tips
        _print("""
Tips:
  • Add the autostart lines to your i3 config (~/.config/i3/config), see the snippet in this file header.
  • Test locker after starting xss-lock via your i3 autostart:
      $ xset s activate
  • i3 reload/restart:
      $ i3-msg reload
      $ i3-msg restart
  • In your display manager, select the 'i3' session at login.
""".rstrip())

        _print("✔ [220_window_manager] i3 window manager stack is ready (no user config written).")
        return True

    except Exception as exc:
        print(f"ERROR: 220_window_manager.install failed: {exc}")
        return False
