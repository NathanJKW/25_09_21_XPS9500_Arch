#!/usr/bin/env bash
# meta: id=50 name="Hyprland + SDDM + portals + dotfiles" desc="Install Hyprland stack, configure SDDM (Wayland), portals, fonts/cursor, and symlink repo dotfiles" needs_root=false
#
# Arch Wiki references (keep accurate in comments):
# - Hyprland: https://wiki.archlinux.org/title/Hyprland
# - Wayland: https://wiki.archlinux.org/title/Wayland
# - xdg-desktop-portal: https://wiki.archlinux.org/title/Xdg-desktop-portal
# - Display manager (SDDM): https://wiki.archlinux.org/title/SDDM
# - Fonts: https://wiki.archlinux.org/title/Fonts
#
# Style: boring, explicit, reproducible; no --noconfirm unless ASSUME_YES=true.

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================
# Minimal config
# ================
ASSUME_YES="${ASSUME_YES:-true}"

# Derived repo paths (read-only)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILES_DIR="$REPO_ROOT/files/hyprland"

# Logging
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

ensure_not_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "Run this module as a regular user (it will sudo only for system changes)."
  fi
}
ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }

# Pacman wrappers (official repos)
pac() {
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S "${extra[@]}" "$@"
}
pac_remove_if_present() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  for p in "$@"; do
    if pacman -Qi "$p" >/dev/null 2>&1; then
      sudo pacman -Rns "${extra[@]}" "$p"
    fi
  done
}
pac_update() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -Syu "${extra[@]}"
}

# yay wrapper (AUR) — only used if yay is installed already (module 30 handles yay)
yay_install() {
  command -v yay >/dev/null 2>&1 || { log "Note: yay not found — skipping AUR install for: $*"; return 0; }
  local yflags=(--needed)
  if [[ "$ASSUME_YES" == "true" ]]; then
    yflags+=(--noconfirm --answerdiff None --answerclean None --removemake)
    yay --save --answerdiff None --answerclean None --removemake >/dev/null 2>&1 || true
  fi
  yay -S "${yflags[@]}" "$@"
}

# Filesystem helpers
ensure_dir() { install -d -m "${2:-0755}" "$1"; }

symlink_dir_into_config() {
  # symlink_dir_into_config <repo_subdir> <target_subdir_name>
  local repo_sub="$1" name="$2"
  local src="$FILES_DIR/$repo_sub"
  local dest="$HOME/.config/$name"
  [[ -d "$src" ]] || { log "Note: $src not found; skipping $name"; return 0; }
  ensure_dir "$HOME/.config"
  if [[ -L "$dest" || -d "$dest" || -f "$dest" ]]; then
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
      ok "~/.config/$name already linked"
      return 0
    fi
    log "Backing up ~/.config/$name → ~/.config/${name}.bak.$(date +%s)"
    mv -f "$dest" "$HOME/.config/${name}.bak.$(date +%s)"
  fi
  ln -s "$(realpath "$src")" "$dest"
  ok "Linked $name config → $src"
}

symlink_system_file() {
  # symlink_system_file <repo_rel_path> <dest_abs_path> <mode>
  local repo_rel="$1" dest="$2" mode="${3:-0644}"
  local src="$FILES_DIR/$repo_rel"
  [[ -f "$src" ]] || { log "Note: $src not found; skipping $dest"; return 0; }
  # Create parent directory with root privileges when targeting system paths
  sudo install -d -m 0755 "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
      ok "$dest already linked"
      return 0
    fi
  fi
  if [[ -e "$dest" ]]; then
    log "Backing up $dest → ${dest}.bak.$(date +%s)"
    sudo mv -f "$dest" "${dest}.bak.$(date +%s)"
  fi
  sudo ln -s "$(realpath "$src")" "$dest"
  sudo chmod "$mode" "$dest" || true
  ok "Installed link: $dest → $src"
}

# ============================
# Step 1: Update (safe)
# ============================
update_system() {
  pac_update
  ok "System updated"
}

# ============================
# Step 2: Install Hyprland stack (official repos)
# ============================
install_wayland_stack() {
  # Replace 'clipman' with 'cliphist' + 'wl-clipboard' per Wayland best practice.
  pac hyprland waybar wofi mako wl-clipboard cliphist grim slurp swappy swaybg foot brightnessctl ttf-jetbrains-mono \
      xdg-desktop-portal xdg-desktop-portal-hyprland xdg-utils libinput qt6-wayland

  # Fonts (& symbols) from official repos only
  pac noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-nerd-fonts-symbols-mono

  # Optional: small GUI history (commented to keep deps minimal)
  # pac nwg-clipman

  # Verification
  command -v Hyprland >/dev/null 2>&1 || fail "Hyprland not on PATH"
  command -v waybar    >/dev/null 2>&1 || fail "waybar not on PATH"
  command -v cliphist  >/dev/null 2>&1 || fail "cliphist not on PATH"
  ok "Wayland/Hyprland core installed"
}

# ============================
# Step 3: Portals (ensure hyprland backend; remove conflicts)
# ============================
configure_portals() {
  # Remove backends that can hijack default selection on Hyprland sessions
  pac_remove_if_present xdg-desktop-portal-wlr xdg-desktop-portal-gnome xdg-desktop-portal-kde

  # Ensure hyprland backend is present (installed above) and base portal present
  pac xdg-desktop-portal xdg-desktop-portal-hyprland

  # Basic runtime verification (the backend binary presence)
  [[ -x /usr/lib/xdg-desktop-portal-hyprland ]] || log "Note: portal backend binary not found at expected path; it will be socket-activated in-session"
  ok "xdg-desktop-portal configured for Hyprland"
}

# ============================
# Step 4: SDDM (Wayland) → Hyprland session
# ============================
configure_sddm() {
  pac sddm qt6-wayland

  # Use repo-provided SDDM snippets if present
  symlink_system_file "sddm/10-wayland.conf" "/etc/sddm.conf.d/10-wayland.conf" 0644
  symlink_system_file "sddm/20-session.conf" "/etc/sddm.conf.d/20-session.conf" 0644

  # Minimal fallback if repo files are missing: set Session=hyprland
  if [[ ! -e /etc/sddm.conf.d/20-session.conf ]]; then
    sudo install -d -m 0755 /etc/sddm.conf.d
    printf '[Autologin]\n\n[Theme]\n\n[Users]\n\n[Wayland]\nSession=hyprland\n' \
      | sudo tee /etc/sddm.conf.d/20-session.conf >/dev/null
  fi

  # Enable SDDM
  sudo systemctl enable --now sddm.service
  systemctl is-active --quiet sddm || fail "sddm not active"
  ok "SDDM enabled for Wayland (Hyprland session)"
}

# ============================
# Step 5: Cursor theme (AUR: Bibata) — optional if yay is missing
# ============================
install_cursor_theme() {
  # Prefer the prebuilt binary AUR package for speed/reproducibility
  yay_install bibata-cursor-theme-bin || true

  # Install default index.theme from repo if provided (system-wide)
  symlink_system_file "icons/default/index.theme" "/usr/share/icons/default/index.theme" 0644
  ok "Cursor theme configured (Bibata if AUR available)"
}

# ============================
# Step 6: System environment snippets (Wayland-friendly)
# ============================
install_environment_snippets() {
  # Per Hyprland & Qt/GTK on Wayland guidance; repo provides environment.d files
  if [[ -d "$FILES_DIR/environment.d" ]]; then
    for f in "$FILES_DIR"/environment.d/*; do
      [[ -f "$f" ]] || continue
      local base; base="$(basename "$f")"
      symlink_system_file "environment.d/$base" "/etc/environment.d/$base" 0644
    done
    ok "System environment.d snippets installed"
  else
    log "Note: $FILES_DIR/environment.d not found — skipping environment snippets"
  fi
}

# ============================
# Step 7: User dotfiles (Hyprland, Waybar, etc.)
# ============================
install_user_dotfiles() {
  symlink_dir_into_config "hypr" "hypr"
  symlink_dir_into_config "waybar" "waybar"
  symlink_dir_into_config "wofi" "wofi"
  symlink_dir_into_config "mako" "mako"
  symlink_dir_into_config "foot" "foot"
  # Optional kitty config if you use it
  if [[ -d "$REPO_ROOT/files/kitty" ]]; then
    ensure_dir "$HOME/.config"
    if [[ -e "$HOME/.config/kitty" && ! -L "$HOME/.config/kitty" ]]; then
      log "Backing up ~/.config/kitty → ~/.config/kitty.bak.$(date +%s)"
      mv -f "$HOME/.config/kitty" "$HOME/.config/kitty.bak.$(date +%s)"
    fi
    ln -snf "$(realpath "$REPO_ROOT/files/kitty")" "$HOME/.config/kitty"
    ok "Linked kitty config"
  fi

  # Clipboard history — ensure Hyprland autostart stores history (if included in your startup.conf)
  # Verify cliphist exists:
  command -v cliphist >/dev/null 2>&1 || fail "cliphist missing (unexpected)"
  ok "Dotfiles linked under ~/.config"
}

# ============================
# Step 8: Verification (non-destructive)
# ============================
verify_end_to_end() {
  # Hyprland session file (from package) should exist
  [[ -f /usr/share/wayland-sessions/hyprland.desktop ]] || fail "Hyprland session .desktop missing"
  # Portal service files
  systemctl status xdg-desktop-portal.service >/dev/null 2>&1 || true
  ok "Basic verification complete (Hyprland session present; portals installed)"
}

# ================
# Main
# ================
main() {
  ensure_not_root
  ensure_cmd sudo

  update_system
  install_wayland_stack
  configure_portals
  configure_sddm
  install_cursor_theme
  install_environment_snippets
  install_user_dotfiles
  verify_end_to_end

  ok "Hyprland + SDDM setup complete"
}

main "$@"
