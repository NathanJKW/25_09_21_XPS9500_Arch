#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# bootstrap_symlinks.sh  v1.0
#
# Create symlinks from your dotfiles repo into $HOME.
# - Creates parent directories as needed
# - Backs up any existing files to ~/.dotfiles_backup/<timestamp>/...
#
# Repo root (edit if you move the repo):
#   REPO="/home/nathan/repos/25_09_21_XPS9500_Arch"
#
# What it links:
#   REPO/i3/config      -> ~/.config/i3/config
#   REPO/X11/xprofile   -> ~/.xprofile
#   REPO/shell/bashrc   -> ~/.bashrc
#   REPO/shell/zshrc    -> ~/.zshrc
#   REPO/git/gitconfig  -> ~/.gitconfig
# -----------------------------------------------------------------------------

set -euo pipefail

REPO="/home/nathan/repos/25_09_21_XPS9500_Arch"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="${HOME}/.dotfiles_backup/${timestamp}"

# Helper: link one file, backing up any existing target
link_one() {
  src="$1"
  dst="$2"

  # make sure parent directories exist
  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
      echo "✓ already linked: $dst"
      return
    fi
    backup_path="${backup_root}/${dst#${HOME}/}"
    mkdir -p "$(dirname "$backup_path")"
    mv -f "$dst" "$backup_path"
    echo "↪ backed up: $dst -> $backup_path"
  fi

  ln -s "$src" "$dst"
  echo "→ linked: $dst -> $src"
}

# -------- dotfile links --------
link_one "$REPO/i3/config"        "${HOME}/.config/i3/config"
# link_one "$REPO/X11/xprofile"     "${HOME}/.xprofile"
# link_one "$REPO/shell/bashrc"     "${HOME}/.bashrc"
# link_one "$REPO/shell/zshrc"      "${HOME}/.zshrc"
# link_one "$REPO/git/gitconfig"    "${HOME}/.gitconfig"

echo "Done. Backups (if any) are in: $backup_root"
