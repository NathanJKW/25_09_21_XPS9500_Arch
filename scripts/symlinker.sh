#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# bootstrap_symlinks.sh  v1.5
#
# Create symlinks from your dotfiles repo into the correct locations.
# - Creates parent directories as needed
# - Backs up existing targets (user files to ~/.dotfiles_backup/<ts>/…,
#   system files to "<dest>.bak.<ts>" alongside the file)
# - Automatically uses sudo for non-writable/system paths (e.g. /etc/*)
#
# Repo root (edit if you move the repo):
#   REPO="/home/nathan/repos/25_09_21_XPS9500_Arch"
#
# What it links (adjust to taste):
#   $REPO/i3/config                      ->  ~/.config/i3/config
#   $REPO/git/gitconfig                  ->  ~/.gitconfig
#   $REPO/X11/xorg.conf.d/90-libinput.conf  ->  ~/.config/xorg.conf.d/90-libinput.conf
#   (optional system path)
#   $REPO/X11/xorg.conf.d/90-libinput.conf  ->  /etc/X11/xorg.conf.d/90-libinput.conf
# -----------------------------------------------------------------------------

set -euo pipefail

REPO="/home/nathan/repos/25_09_21_XPS9500_Arch"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="${HOME}/.dotfiles_backup/${timestamp}"

# ----- helpers ---------------------------------------------------------------

need_sudo() {
  # return 0 if we need sudo to write the DEST's parent dir
  local dest="$1"
  local parent; parent="$(dirname "$dest")"
  [ -w "$parent" ] || { [ -e "$parent" ] && [ ! -w "$parent" ]; } && return 0
  # parent not existing? test writability of its nearest existing ancestor
  while [ ! -d "$parent" ]; do parent="$(dirname "$parent")"; done
  [ -w "$parent" ] || return 0
  return 1
}

ensure_parent() {
  local dest="$1"
  local parent; parent="$(dirname "$dest")"
  if need_sudo "$dest"; then
    sudo mkdir -p "$parent"
  else
    mkdir -p "$parent"
  fi
}

backup_target() {
  # create a backup of existing dest (file/dir/link)
  local dest="$1"
  if need_sudo "$dest"; then
    local bk="${dest}.bak.${timestamp}"
    echo "↪ backing up (root): $dest -> $bk"
    sudo cp -a --no-preserve=ownership "$dest" "$bk" 2>/dev/null || sudo mv -f "$dest" "$bk"
  else
    local rel="${dest#${HOME}/}"
    local bk="${backup_root}/${rel}"
    echo "↪ backing up: $dest -> $bk"
    mkdir -p "$(dirname "$bk")"
    mv -f "$dest" "$bk"
  fi
}

same_symlink_target() {
  # returns 0 if dest is a symlink pointing to src
  local src="$1" dest="$2"
  [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]
}

link_one() {
  local src="$1" dest="$2"

  # sanity
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    echo "⚠  missing source: $src"
    return 0
  fi

  ensure_parent "$dest"

  # if exists and not already the same link, back it up
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if same_symlink_target "$src" "$dest"; then
      echo "✓ already linked: $dest → $(readlink -f "$dest")"
      return 0
    fi
    backup_target "$dest"
  fi

  if need_sudo "$dest"; then
    echo "→ linking (root): $dest -> $src"
    sudo ln -sfn "$src" "$dest"
  else
    echo "→ linking: $dest -> $src"
    ln -sfn "$src" "$dest"
  fi
}

# ----- user-scope links (no sudo) -------------------------------------------

link_one "$REPO/i3/config"                          "${HOME}/.config/i3/config"
link_one "$REPO/git/gitconfig"                      "${HOME}/.gitconfig"
link_one "$REPO/X11/xorg.conf.d/90-libinput.conf"   "/etc/X11/xorg.conf.d/90-libinput.conf"

# Uncomment if/when you want these managed too:
# link_one "$REPO/X11/xprofile"                      "${HOME}/.xprofile"
# link_one "$REPO/shell/bashrc"                       "${HOME}/.bashrc"
# link_one "$REPO/shell/zshrc"                        "${HOME}/.zshrc"

# ----- wrap up ---------------------------------------------------------------

# Show where user backups (if any) landed
[ -d "$backup_root" ] && echo "User backups (if any) are in: $backup_root"
echo "Done."
