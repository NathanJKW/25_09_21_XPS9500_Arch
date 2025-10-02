#!/usr/bin/env python3
"""
230_panels-bars — Polybar for i3 (X11)

What this module does
---------------------
- Installs Polybar and sensors tooling (for temperature modules).
- Prints non-fatal diagnostics and tips to wire Polybar into i3.
- Does NOT write user config (leave to your 4xx dotfiles).

Why this module is minimal
--------------------------
Polybar ships a default system config at /etc/polybar/config.ini that works out of the box.
Your personal config should live at ~/.config/polybar/config.ini and will override the system one.

Copy/paste: ~/.config/polybar/config.ini (basic bar with i3, battery, temps, clock)
-----------------------------------------------------------------------------------
; Minimal example. Adjust names after checking:
;   $ ls -1 /sys/class/power_supply/         # e.g. BAT0, ADP1 (or AC)
;   $ sensors                                # see which thermal zones are valid

[colors]
background = #AA1E1E2E
foreground = #D9D9D9
primary    = #89B4FA
warning    = #F9E2AF
critical   = #F38BA8

[bar/main]
width = 100%
height = 28
background = ${colors.background}
foreground = ${colors.foreground}
font-0 = JetBrainsMono Nerd Font:style=Regular:size=10;2
padding-left = 1
padding-right = 1
module-margin = 2
enable-ipc = true
cursor-click = pointer
cursor-scroll = ns-resize
; uncomment for tray support if desired:
; tray-position = right
; tray-maxsize = 20

modules-left  = i3
modules-center =
modules-right = temperature battery date

[module/i3]
type = internal/i3
format = <label-state> <label-mode>
label-focused = %name%
label-focused-foreground = ${colors.primary}
label-unfocused = %name%
label-visible = %name%
label-urgent = %name%
; show only non-empty workspaces:
index-sort = true
wrapping-scroll = false
pin-workspaces = true

[module/battery]
type = internal/battery
battery = BAT0
adapter = ADP1
full-at = 98
format-charging =   <animation-charging> <label-charging>
format-discharging =   <ramp-capacity> <label-discharging>
format-full =   <label-full>
ramp-capacity-0 = 
ramp-capacity-1 = 
ramp-capacity-2 = 
ramp-capacity-3 = 
ramp-capacity-4 = 
animation-charging-0 = 
animation-charging-1 = 
animation-charging-2 = 
animation-charging-3 = 
animation-charging-4 = 
animation-charging-framerate = 750

[module/temperature]
type = internal/temperature
; EITHER set thermal-zone OR a specific hwmon path. Start with thermal-zone:
thermal-zone = 0
warn-temperature = 80
format =   <label>
format-warn =   <label-warn>
label = %temperature-c%°C
label-warn = %temperature-c%°C
label-warn-foreground = ${colors.warning}

[module/date]
type = internal/date
interval = 1
time = %Y-%m-%d %H:%M:%S
format =   <label>
label = %time%

Copy/paste: ~/.config/polybar/launch.sh (spawn per monitor)
-----------------------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

killall -q polybar || true
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/polybar/config.ini"

if command -v polybar >/dev/null 2>&1; then
  if [ -f "$CONFIG" ]; then
    for m in $(polybar -m | cut -d: -f1); do
      MONITOR="$m" polybar -q main -c "$CONFIG" &
    done
  else
    # fallback: run with the system config so you at least get a bar
    for m in $(polybar -m | cut -d: -f1); do
      MONITOR="$m" polybar -q main -c /etc/polybar/config.ini &
    done
  fi
fi

Make executable:
  chmod +x ~/.config/polybar/launch.sh

i3 autostart (add to your i3 config)
------------------------------------
exec_always --no-startup-id ~/.config/polybar/launch.sh

Notes
-----
- If you used i3bar before, comment out any `bar { ... }` block in your i3 config.
- Temperature source can differ per hardware; use `sensors` and adjust `thermal-zone`
  or set an explicit `hwmon-path = /sys/class/hwmon/hwmonX/temp1_input`.
"""

from __future__ import annotations
from typing import Callable, Iterable
import subprocess

from utils.pacman import install_packages


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


def _diagnostics() -> None:
    """Best-effort visibility & guidance."""
    _run_user(["bash", "-lc", "polybar -vvv | sed -n '1,40p' || true"])
    _run_user(["bash", "-lc", "echo 'Detected monitors:' && polybar -m || true"])
    _run_user(["bash", "-lc", "test -f /etc/polybar/config.ini && echo '/etc/polybar/config.ini exists' || echo 'system config missing'"])
    _run_user(["bash", "-lc", "command -v sensors >/dev/null 2>&1 && sensors || echo 'Run `sudo sensors-detect` to improve temperature readings'"])


def install(run: Callable) -> bool:
    try:
        _print("▶ [230_panels-bars] Installing Polybar + sensors tooling…")

        # Core bar + sensors for temperature module
        pkgs = [
            "polybar",
            "lm_sensors",   # for `sensors` and improved temp visibility
            # Optional helper for quick battery/AC debugging (not required by Polybar):
            # "acpi",
        ]

        if not install_packages(pkgs, run):
            _print("❌ [230_panels-bars] Package installation failed.")
            return False

        _print("ℹ️  Polybar installed. Default system config: /etc/polybar/config.ini")
        _print("ℹ️  Personal config (overrides system): ~/.config/polybar/config.ini")
        _print("ℹ️  Tip: Run `sudo sensors-detect` once, then `sensors` to verify temp inputs.")

        # Non-fatal checks
        _diagnostics()

        _print("""
Tips:
  • Create ~/.config/polybar/config.ini using the snippet in this file's header (battery, temp, date).
  • Create ~/.config/polybar/launch.sh (also in header), then:
      chmod +x ~/.config/polybar/launch.sh
  • Add to i3 config:
      exec_always --no-startup-id ~/.config/polybar/launch.sh
  • If using i3bar previously: comment out any `bar { ... }` block in your i3 config.
""".rstrip())

        _print("✔ [230_panels-bars] Polybar ready (no user config written).")
        return True

    except Exception as exc:
        print(f"ERROR: 230_panels-bars.install failed: {exc}")
        return False
