#!/usr/bin/env bash
# Generate Hyprland dotfiles into the repo's /files directory
# Style: boring, explicit, idempotent. No clever tricks.
#
# This script ONLY writes into the repository under: $REPO_ROOT/files/hyprland/*
# The installer module (50-hyprland-setup.sh) will later deploy these into $HOME.
#
# Per Arch Wiki references (for later deployment/usage, not for this generator):
# - Hyprland
# - XDG Desktop Portal
# - SDDM
# - PipeWire / WirePlumber
# - libinput
#
# Conventions:
# - set -Eeuo pipefail, IFS=$nt
# - Variables at top; small functions; simple main
# - Creates files/directories if missing; overwrites only when FORCE_OVERWRITE=true
# - Emits explicit OK messages

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================================
# Config (override via env)
# ================================
REPO_ROOT="${REPO_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/files/hyprland}"     # base output tree under repo
FORCE_OVERWRITE="${FORCE_OVERWRITE:-false}"         # set true to clobber existing template files

# Defaults for generated themes/settings
GTK_THEME="${GTK_THEME:-Adwaita-dark}"
CURSOR_THEME="${CURSOR_THEME:-Bibata-Modern-Classic}"
CURSOR_SIZE="${CURSOR_SIZE:-24}"
FONT_MONO="${FONT_MONO:-JetBrains Mono,monospace}"
FONT_SIZE_PT="${FONT_SIZE_PT:-11}"

# ================================
# Logging / helpers
# ================================
log()   { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()    { log "OK: $*"; }
fail()  { log "FAIL: $*"; exit 1; }

ensure_dir() { install -d -m 0755 "$1"; }

write_file() {
  # write_file <path> <<'EOF' ... EOF
  local path="$1"
  shift || true
  local dir; dir="$(dirname -- "$path")"
  ensure_dir "$dir"
  if [[ -e "$path" && "$FORCE_OVERWRITE" != "true" ]]; then
    log "Skip (exists): $path  (set FORCE_OVERWRITE=true to overwrite)"
    return 0
  fi
  # shellcheck disable=SC2094
  cat >"$path"
  ok "Wrote: $path"
}

append_file_once() {
  # append_file_once <path> <literal_line>
  local path="$1" line="$2"
  ensure_dir "$(dirname -- "$path")"
  touch "$path"
  grep -Fxq -- "$line" "$path" 2>/dev/null || { printf '%s\n' "$line" >>"$path"; ok "Appended line to: $path"; }
}

# ================================
# Generators
# ================================
gen_tree_overview() {
  cat <<'EOF'
Planned output tree (under files/hyprland/):

  hypr/
    hyprland.conf
    monitors.conf            (optional, commented example)
    env.conf                 (session env that Hyprland can source)
    startup.conf             (exec-once entries)
  waybar/
    config.jsonc
    style.css
  wofi/
    config
    style.css
  mako/
    config
  foot/
    foot.ini
  gtk/
    gtk-3.0/settings.ini
    gtk-4.0/settings.ini
  environment.d/
    10-qtct.conf
    20-cursor.conf
    30-hypr-nvidia-safe.conf (commented off by default)
  icons/
    default/index.theme      (cursor theme selection)
  wallpapers/
    default.jpg              (placeholder note file)

These are templates to be deployed later into ~/.config, ~/.icons, etc.
EOF
}

gen_hyprland_conf() {
  write_file "$OUT_DIR/hypr/hyprland.conf" <<EOF
# Hyprland minimal, safe-by-default config
# - Dark theme, Waybar, Wofi, Mako, Foot
# - Input via libinput (Wayland-native)
# - No NVIDIA hacks by default (see env.conf / environment.d)
#
# Key notation: SUPER = Mod key
# Per Arch Wiki: Hyprland (configuration basics)

# === Appearance ===
general {
  gaps_in = 8
  gaps_out = 16
  border_size = 2
  col.active_border = rgba(88aaffee)
  col.inactive_border = rgba(222222aa)
  layout = dwindle
}

decoration {
  active_opacity = 1.0
  inactive_opacity = 0.95
  rounding = 8
  blur = yes
  blur_size = 6
  blur_passes = 1
}

animations {
  enabled = yes
  # keep defaults; nothing fancy
}

# === Input (libinput via Hyprland) ===
input {
  kb_layout = us
  follow_mouse = 1
  touchpad {
    natural_scroll = true
    tap = true
    tap_button_map = lrm
    scroll_factor = 0.9
  }
}

# === Monitors ===
# See files/hyprland/hypr/monitors.conf for examples
source = ~/.config/hypr/monitors.conf

# === Environment (per-user session) ===
# Place toggles (e.g., NVIDIA safe mode) in env.conf; we source it here.
source = ~/.config/hypr/env.conf

# === Autostart ===
# Lightweight Wayland stack: wallpaper, bar, notif daemon, portal compat if needed
source = ~/.config/hypr/startup.conf

# === Keybinds ===
\$mod = SUPER

# Launchers
bind = \$mod, Return, exec, foot
bind = \$mod, D, exec, wofi --show drun

# Session controls
bind = \$mod, Q, killactive,
bind = \$mod SHIFT, E, exit,

# Tiling
bind = \$mod, H, movefocus, l
bind = \$mod, L, movefocus, r
bind = \$mod, K, movefocus, u
bind = \$mod, J, movefocus, d

# Workspaces
bind = \$mod, 1, workspace, 1
bind = \$mod, 2, workspace, 2
bind = \$mod, 3, workspace, 3
bind = \$mod, 4, workspace, 4
bind = \$mod, 5, workspace, 5
bind = \$mod SHIFT, 1, movetoworkspace, 1
bind = \$mod SHIFT, 2, movetoworkspace, 2
bind = \$mod SHIFT, 3, movetoworkspace, 3
bind = \$mod SHIFT, 4, movetoworkspace, 4
bind = \$mod SHIFT, 5, movetoworkspace, 5

# Screenshots (grim + slurp + swappy)
bind = , Print, exec, grim -g "\$(slurp)" - | swappy -f -

# Volume (PipeWire/Pulse via wpctl)
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# Brightness (intel_backlight via brightnessctl, to be installed later if desired)
# bind = , XF86MonBrightnessUp,   exec, brightnessctl set +5%
# bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

EOF
}

gen_hypr_env() {
  write_file "$OUT_DIR/hypr/env.conf" <<'EOF'
# Session environment for Hyprland (sourced by hyprland.conf)
# Keep minimal; prefer /etc/environment.d or ~/.config/environment.d for globals.

# XDG portal: prefer hyprland backend (socket-activated)
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export GTK_THEME=Adwaita-dark

# NVIDIA "safe mode" (commented by default):
# export WLR_NO_HARDWARE_CURSORS=1
# export __GLX_VENDOR_LIBRARY_NAME=nvidia
# export __NV_PRIME_RENDER_OFFLOAD=1
# export __VK_LAYER_NV_optimus=NVIDIA_only
EOF
}

gen_hypr_startup() {
  write_file "$OUT_DIR/hypr/startup.conf" <<'EOF'
# Autostart for Hyprland (exec-once is recommended)
# Wallpaper
exec-once = swaybg -m fill -i ~/.config/wallpapers/default.jpg

# Bar + notifications
exec-once = waybar
exec-once = mako

# Clipboard
exec-once = wl-paste --type text --watch clipman store
exec-once = wl-paste --type image --watch clipman store
EOF
}

gen_hypr_monitors_example() {
  write_file "$OUT_DIR/hypr/monitors.conf" <<'EOF'
# Example monitor layout (leave empty to let Hyprland auto-detect)
# monitor=name, resolution@hz, position, scale
# To list names: hyprctl monitors
# monitor=eDP-1,1920x1200@60,0x0,1
EOF
}

gen_waybar() {
  write_file "$OUT_DIR/waybar/config.jsonc" <<'EOF'
// Minimal dark Waybar config (JSONC)
{
  "layer": "top",
  "position": "top",
  "height": 28,
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network", "battery"],
  "clock": { "format": "{:%a %d %b  %H:%M}" },
  "pulseaudio": { "tooltip": true, "scroll-step": 5 },
  "network": { "format-wifi": "  {essid}", "format-ethernet": "  {ipaddr}", "format-disconnected": "" },
  "battery": { "format": "{capacity}% {icon}", "format-icons": ["","","","",""] }
}
EOF

  write_file "$OUT_DIR/waybar/style.css" <<'EOF'
/* Dark, no external theme */
* { border: none; border-radius: 0; font-family: JetBrains Mono, monospace; font-size: 12pt; min-height: 0; }
window { background: #1e1e2e; color: #cdd6f4; }
#workspaces button { padding: 0 8px; color: #a6adc8; }
#workspaces button.active { color: #cdd6f4; border-bottom: 2px solid #89b4fa; }
#clock, #battery, #network, #pulseaudio { padding: 0 10px; }
EOF
}

gen_wofi() {
  write_file "$OUT_DIR/wofi/config" <<'EOF'
show=drun
prompt=Run:
allow_images=true
matching=fuzzy
insensitive=true
term=foot
hide_scroll=true
width=40%
height=40%
EOF

  write_file "$OUT_DIR/wofi/style.css" <<'EOF'
window { margin: 0px; background-color: #1e1e2e; color: #cdd6f4; }
#input { margin: 8px; border: none; padding: 8px; background-color: #313244; }
#inner-box { margin: 8px; }
#entry { padding: 6px; }
#entry:selected { background-color: #45475a; }
EOF
}

gen_mako() {
  write_file "$OUT_DIR/mako/config" <<'EOF'
# Dark mako notifications
font=JetBrains Mono 11
background-color=#1e1e2e
text-color=#cdd6f4
border-color=#89b4fa
width=350
height=140
default-timeout=5000
anchor=top-right
margin=10,10,0,0
EOF
}

gen_foot() {
  write_file "$OUT_DIR/foot/foot.ini" <<EOF
# Minimal Foot terminal config
font=${FONT_MONO} ${FONT_SIZE_PT}
dpi-aware=yes
pad=8x8
[cursor]
style=beam
blink=yes
[colors]
# Keep defaults; dark-friendly
EOF
}

gen_gtk() {
  write_file "$OUT_DIR/gtk/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=${GTK_THEME}
gtk-font-name=${FONT_MONO} ${FONT_SIZE_PT}
gtk-cursor-theme-name=${CURSOR_THEME}
gtk-cursor-theme-size=${CURSOR_SIZE}
gtk-application-prefer-dark-theme=1
EOF

  write_file "$OUT_DIR/gtk/gtk-4.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=${GTK_THEME}
gtk-font-name=${FONT_MONO} ${FONT_SIZE_PT}
gtk-cursor-theme-name=${CURSOR_THEME}
gtk-cursor-theme-size=${CURSOR_SIZE}
gtk-application-prefer-dark-theme=1
EOF
}

gen_envd() {
  write_file "$OUT_DIR/environment.d/10-qtct.conf" <<'EOF'
# Make Qt apps respect qt6ct in Wayland sessions
QT_QPA_PLATFORMTHEME=qt6ct
EOF

  write_file "$OUT_DIR/environment.d/20-cursor.conf" <<EOF
# Cursor theme for Wayland/XWayland apps
XCURSOR_THEME=${CURSOR_THEME}
XCURSOR_SIZE=${CURSOR_SIZE}
EOF

  write_file "$OUT_DIR/environment.d/30-hypr-nvidia-safe.conf" <<'EOF'
# NVIDIA "safe mode" for Wayland (disabled by default)
# Uncomment if you see cursor glitches/tearing:
# WLR_NO_HARDWARE_CURSORS=1
# __GLX_VENDOR_LIBRARY_NAME=nvidia
# __NV_PRIME_RENDER_OFFLOAD=1
# __VK_LAYER_NV_optimus=NVIDIA_only
EOF
}

gen_icons_cursor() {
  write_file "$OUT_DIR/icons/default/index.theme" <<EOF
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=${CURSOR_THEME}
EOF
}

gen_wallpaper_placeholder() {
  ensure_dir "$OUT_DIR/wallpapers"
  # Place a tiny placeholder note instead of bundling binaries
  write_file "$OUT_DIR/wallpapers/README.txt" <<'EOF'
Put your wallpaper here as "default.jpg".
The setup module will reference: ~/.config/wallpapers/default.jpg
EOF
}

gen_sddm_snippets() {
  # These are *templates* that the install module can place under /etc/sddm.conf.d
  write_file "$OUT_DIR/sddm/10-wayland.conf" <<'EOF'
[General]
# Per Arch Wiki: SDDM → Wayland
DisplayServer=wayland
EOF

  write_file "$OUT_DIR/sddm/20-session.conf" <<'EOF'
[Autologin]
# Optional: AutologinUser=
# Optional: AutologinSession=hyprland.desktop

[General]
# Default session shown in greeter
Session=hyprland.desktop
EOF
}

# ================================
# Main
# ================================
main() {
  log "Output root: $OUT_DIR"
  gen_tree_overview

  gen_hyprland_conf
  gen_hypr_env
  gen_hypr_startup
  gen_hypr_monitors_example

  gen_waybar
  gen_wofi
  gen_mako
  gen_foot

  gen_gtk
  gen_envd
  gen_icons_cursor
  gen_wallpaper_placeholder
  gen_sddm_snippets

  ok "All template files generated under: $OUT_DIR"
}

main "$@"
