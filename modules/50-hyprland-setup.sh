#!/usr/bin/env bash
# meta: id=50 name="Hyprland + SDDM + theming + portals" desc="Install Wayland/Hyprland stack, configure SDDM, and symlink repo dotfiles" needs_root=false
#
# Scope:
# - Installs Hyprland + essentials (Waybar, Wofi, Mako, wl-clipboard, grim/slurp/swappy, swaybg, Foot, brightnessctl, clipman)
# - Portals: xdg-desktop-portal + gtk + hyprland backend
# - Input: libinput (Wayland-native). No Xorg xf86-input-libinput (not needed).
# - Fonts/cursor/theme helpers: Noto fonts, Nerd symbols, Bibata cursor, qt6ct only.
# - Display manager: SDDM (Wayland), default session Hyprland.
# - Dotfiles: symlink from repo's files/hyprland/* to ~/.config and /etc/sddm.conf.d
#
# Arch Wiki references:
# - Hyprland: https://wiki.archlinux.org/title/Hyprland
# - XDG Desktop Portal: https://wiki.archlinux.org/title/XDG_Desktop_Portal
# - SDDM: https://wiki.archlinux.org/title/SDDM
# - libinput: https://wiki.archlinux.org/title/Libinput
#
# Style:
# - Boring & explicit. No --noconfirm unless ASSUME_YES=true.
# - Run as regular user; sudo only for system-wide changes.
# - After each major step, print an OK message; fail fast otherwise.

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================================
# Config
# ================================
ASSUME_YES="${ASSUME_YES:-false}"

# Repo layout
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FILES_ROOT="${FILES_ROOT:-$REPO_ROOT/files/hyprland}"

# Destinations (user + system)
CONF_HOME="${CONF_HOME:-$HOME/.config}"
ETC_SDDM_DIR="/etc/sddm.conf.d"
ICONS_HOME="${ICONS_HOME:-$HOME/.icons}"
WALL_HOME="${WALL_HOME:-$CONF_HOME/wallpapers}"
ENV_HOME="${ENV_HOME:-$CONF_HOME/environment.d}"

# ================================
# Logging / helpers
# ================================
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

pac() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S --needed "${extra[@]}" "$@"
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }

ensure_not_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "Run this module as a regular user; it will sudo only for system changes."
  fi
}

ensure_dir() { install -d -m 0755 "$1"; }

symlink_overwrite() {
  # symlink_overwrite <source> <dest>
  local src="$1" dst="$2"
  ensure_dir "$(dirname -- "$dst")"
  ln -sfT -- "$src" "$dst"
}

verify_file() { [[ -e "$1" ]] || fail "Missing expected file: $1"; }
verify_cmd_active() { systemctl is-active --quiet "$1" || fail "Service not active: $1"; }
verify_cmd_enabled() { systemctl is-enabled --quiet "$1" || fail "Service not enabled: $1"; }

# ================================
# Package installation
# ================================
install_packages() {
  # Core Wayland/Hyprland stack
  local pkgs=(
    hyprland waybar wofi mako foot
    wl-clipboard grim slurp swappy swaybg
    brightnessctl clipman
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    polkit-gnome xdg-user-dirs xdg-utils
    libinput
    qt6-wayland qt6ct
    noto-fonts noto-fonts-emoji ttf-nerd-fonts-symbols
    bibata-cursor-theme
  )

  pac "${pkgs[@]}"
  ok "Packages installed (Hyprland stack + helpers)"
}

# ================================
# SDDM configuration (system)
# ================================
configure_sddm() {
  pac sddm
  ensure_dir "$ETC_SDDM_DIR"

  # Symlink repo snippets into /etc/sddm.conf.d
  local src_way="$FILES_ROOT/sddm/10-wayland.conf"
  local src_sess="$FILES_ROOT/sddm/20-session.conf"
  [[ -f "$src_way" && -f "$src_sess" ]] || fail "Repo SDDM snippets not found under $FILES_ROOT/sddm"

  sudo ln -sfT -- "$src_way" "$ETC_SDDM_DIR/10-wayland.conf"
  sudo ln -sfT -- "$src_sess" "$ETC_SDDM_DIR/20-session.conf"

  # Enable + start SDDM
  sudo systemctl enable --now sddm.service

  # Verify
  verify_cmd_enabled sddm.service
  verify_cmd_active sddm.service
  verify_file /usr/share/wayland-sessions/hyprland.desktop
  ok "SDDM configured (Wayland) and Hyprland session available"
}

# ================================
# User dotfiles (symlink from repo)
# ================================
deploy_user_dotfiles() {
  # Hyprland configs
  symlink_overwrite "$FILES_ROOT/hypr/hyprland.conf" "$CONF_HOME/hypr/hyprland.conf"
  symlink_overwrite "$FILES_ROOT/hypr/env.conf"       "$CONF_HOME/hypr/env.conf"
  symlink_overwrite "$FILES_ROOT/hypr/startup.conf"   "$CONF_HOME/hypr/startup.conf"
  symlink_overwrite "$FILES_ROOT/hypr/monitors.conf"  "$CONF_HOME/hypr/monitors.conf"

  # Waybar, Wofi, Mako, Foot
  symlink_overwrite "$FILES_ROOT/waybar/config.jsonc" "$CONF_HOME/waybar/config.jsonc"
  symlink_overwrite "$FILES_ROOT/waybar/style.css"    "$CONF_HOME/waybar/style.css"

  symlink_overwrite "$FILES_ROOT/wofi/config"         "$CONF_HOME/wofi/config"
  symlink_overwrite "$FILES_ROOT/wofi/style.css"      "$CONF_HOME/wofi/style.css"

  symlink_overwrite "$FILES_ROOT/mako/config"         "$CONF_HOME/mako/config"
  symlink_overwrite "$FILES_ROOT/foot/foot.ini"       "$CONF_HOME/foot/foot.ini"

  # GTK settings
  symlink_overwrite "$FILES_ROOT/gtk/gtk-3.0/settings.ini" "$CONF_HOME/gtk-3.0/settings.ini"
  symlink_overwrite "$FILES_ROOT/gtk/gtk-4.0/settings.ini" "$CONF_HOME/gtk-4.0/settings.ini"

  # environment.d
  ensure_dir "$ENV_HOME"
  symlink_overwrite "$FILES_ROOT/environment.d/10-qtct.conf"            "$ENV_HOME/10-qtct.conf"
  symlink_overwrite "$FILES_ROOT/environment.d/20-cursor.conf"           "$ENV_HOME/20-cursor.conf"
  symlink_overwrite "$FILES_ROOT/environment.d/30-hypr-nvidia-safe.conf" "$ENV_HOME/30-hypr-nvidia-safe.conf"

  # Cursor theme selection
  symlink_overwrite "$FILES_ROOT/icons/default/index.theme" "$ICONS_HOME/default/index.theme"

  # Wallpapers (leave as a directory; user supplies default.jpg)
  ensure_dir "$WALL_HOME"
  [[ -f "$FILES_ROOT/wallpapers/README.txt" ]] && symlink_overwrite "$FILES_ROOT/wallpapers/README.txt" "$WALL_HOME/README.txt"

  # Verify key ones
  verify_file "$CONF_HOME/hypr/hyprland.conf"
  verify_file "$CONF_HOME/waybar/config.jsonc"
  verify_file "$CONF_HOME/gtk-3.0/settings.ini"
  ok "Dotfiles symlinked from repo → $HOME"
}

# ================================
# Post-setup (user)
# ================================
post_setup_user() {
  # Create standard XDG dirs (no sudo)
  xdg-user-dirs-update || true

  ok "User environment prepared"
}

# ================================
# Verification
# ================================
verify_stack() {
  # Portal backend present
  verify_file /usr/lib/xdg-desktop-portal-hyprland
  # Greeter should be up; user can switch session to Hyprland
  systemctl status sddm.service >/dev/null 2>&1 || fail "sddm.service not healthy"
  ok "Portal backend present and SDDM healthy"
}

# ================================
# Main
# ================================
main() {
  ensure_not_root
  ensure_cmd sudo

  # Keep system fresh (user confirms unless ASSUME_YES=true)
  sudo pacman -Syu
  ok "System updated"

  # Install packages
  install_packages

  # Deploy user config symlinks (no backups; overwrite)
  deploy_user_dotfiles
  post_setup_user

  # System DM setup (sudo where needed)
  configure_sddm

  # Final verification
  verify_stack

  log "Hyprland setup complete. Log out to SDDM and select 'Hyprland'."
  ok "Module finished"
}

main "$@"
