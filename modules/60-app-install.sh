#!/usr/bin/env bash
# meta: id=60 name="Desktop apps (pkg lists + symlinks)" desc="Install pacman & AUR packages from lists; create repo→user/system symlinks" needs_root=false
#
# Arch Wiki refs:
# - Pacman: https://wiki.archlinux.org/title/Pacman
# - Makepkg/AUR helpers: https://wiki.archlinux.org/title/AUR_helpers
# - XDG utils (defaults): https://wiki.archlinux.org/title/Xdg-utils
#
# Style: boring & explicit. No --noconfirm unless ASSUME_YES=true.
# Run as a regular user (yay/makepkg must not run as root).

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================================
# Config (override via env)
# ================================
ASSUME_YES="${ASSUME_YES:-true}"

# Repo root (auto-detect based on script location, like other modules)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# 1) Official repo packages (pacman)
#    Add as many as you like (space-separated). Example includes kitty.
PACMAN_PKGS="${PACMAN_PKGS:-kitty}"

# 2) AUR packages (yay)
#    Add as many as you like (space-separated). Example includes brave-bin.
YAY_PKGS="${YAY_PKGS:-brave-bin}"

# 3) Symlink spec: repo → dest pairs.
#    Format: each entry "RELATIVE_OR_ABS_SRC :: ABS_DEST"
#    - If SRC is relative, it's resolved against $REPO_ROOT.
#    - Dest directories are created if needed.
#    Example (commented):
#      SYMLINK_SPEC+=("files/hyprland/kitty/kitty.conf :: $HOME/.config/kitty/kitty.conf")
#      SYMLINK_SPEC+=("files/hyprland/environment.d/20-cursor.conf :: $HOME/.config/environment.d/20-cursor.conf")
declare -a SYMLINK_SPEC=(
  "files/kitty/kitty.conf :: $HOME/.config/kitty/kitty.conf"
)

# Optional: set a default browser desktop ID after installs (leave empty to skip)
# e.g., "brave-browser.desktop" or "firefox.desktop"
DEFAULT_BROWSER_DESKTOP_ID="${DEFAULT_BROWSER_DESKTOP_ID:-brave-browser.desktop}"

# ================================
# Logging / helpers
# ================================
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

ensure_not_root() {
  # per Arch Wiki: makepkg must NOT run as root (yay uses makepkg)
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "Run this module as a regular user; it will sudo only for system changes."
  fi
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }

pac() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S --needed "${extra[@]}" "$@"
}

verify_pkgs_installed() {
  local missing=()
  for p in "$@"; do
    # accept either pacman-managed binaries or actual executables on PATH
    pacman -Qi "$p" >/dev/null 2>&1 || command -v "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [[ ${#missing[@]} -eq 0 ]] || fail "Packages not installed/available: ${missing[*]}"
}

ensure_dir() { install -d -m 0755 "$1"; }

symlink_overwrite() {
  # symlink_overwrite <source> <dest> ; creates parent dir of dest; replaces target
  local src="$1" dst="$2"
  [[ -e "$src" || -L "$src" ]] || fail "Symlink source missing: $src"
  ensure_dir "$(dirname -- "$dst")"
  ln -sfT -- "$src" "$dst"
}

resolve_src() {
  # Turn relative SRC into absolute path under $REPO_ROOT
  local src="$1"
  if [[ "$src" == /* ]]; then
    printf '%s\n' "$src"
  else
    printf '%s/%s\n' "$REPO_ROOT" "$src"
  fi
}

# ================================
# Package installation
# ================================
install_pacman_list() {
  [[ -n "${PACMAN_PKGS// /}" ]] || { ok "No pacman packages requested"; return 0; }
  log "Installing pacman packages: $PACMAN_PKGS"
  pac $PACMAN_PKGS
  # Verify using pacman -Qi; do not rely on PATH names (some are libraries)
  local miss=()
  for p in $PACMAN_PKGS; do pacman -Qi "$p" >/dev/null 2>&1 || miss+=("$p"); done
  [[ ${#miss[@]} -eq 0 ]] || fail "pacman packages missing after install: ${miss[*]}"
  ok "pacman packages installed"
}

install_yay_list() {
  [[ -n "${YAY_PKGS// /}" ]] || { ok "No AUR packages requested"; return 0; }
  ensure_cmd yay
  local yflags=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && yflags+=(--noconfirm)
  log "Installing AUR packages: $YAY_PKGS"
  # shellcheck disable=SC2086
  yay -S ${yflags[*]} $YAY_PKGS
  # Verify via yay -Q (falls back to pacman -Qi in case of repo transitions)
  local miss=()
  for p in $YAY_PKGS; do
    yay -Q "$p" >/dev/null 2>&1 || pacman -Qi "$p" >/dev/null 2>&1 || miss+=("$p")
  done
  [[ ${#miss[@]} -eq 0 ]] || fail "AUR packages missing after install: ${miss[*]}"
  ok "AUR packages installed"
}

# ================================
# Symlink deployment
# ================================
deploy_symlinks() {
  [[ ${#SYMLINK_SPEC[@]} -gt 0 ]] || { ok "No symlinks requested"; return 0; }

  for pair in "${SYMLINK_SPEC[@]}"; do
    # Expect "SRC :: DST"
    IFS=':' read -r a b c <<<"$pair" || true
    # Rejoin to keep any extra ':' in paths; then split on ' :: '
    local src dst
    src="$(printf '%s:%s:%s' "$a" "$b" "$c" | sed -E 's/ :: .*$//')"
    dst="$(printf '%s:%s:%s' "$a" "$b" "$c" | sed -E 's/^.* :: //')"
    [[ -n "$src" && -n "$dst" ]] || fail "Bad SYMLINK_SPEC entry (expect 'SRC :: DST'): $pair"

    local abs_src; abs_src="$(resolve_src "$src")"
    symlink_overwrite "$abs_src" "$dst"
    ok "Symlinked: $dst → $abs_src"
  done

  ok "All requested symlinks applied"
}

# ================================
# Optional: set default browser
# ================================
maybe_set_default_browser() {
  [[ -n "$DEFAULT_BROWSER_DESKTOP_ID" ]] || { ok "Skipping default browser (none requested)"; return 0; }
  if command -v xdg-settings >/dev/null 2>&1 && command -v xdg-mime >/dev/null 2>&1; then
    xdg-settings set default-web-browser "$DEFAULT_BROWSER_DESKTOP_ID" || true
    xdg-mime default "$DEFAULT_BROWSER_DESKTOP_ID" x-scheme-handler/http
    xdg-mime default "$DEFAULT_BROWSER_DESKTOP_ID" x-scheme-handler/https
    ok "Default browser set to $DEFAULT_BROWSER_DESKTOP_ID (desktop/portals may override)"
  else
    log "Note: xdg-utils not present; default browser not set"
  fi
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

  install_pacman_list
  install_yay_list
  deploy_symlinks
  maybe_set_default_browser

  ok "Desktop apps + symlinks module complete"
}

main "$@"
