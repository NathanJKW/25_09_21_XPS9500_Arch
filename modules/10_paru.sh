#!/bin/bash
#
# paru-install.sh - Bootstrap paru AUR helper on Arch Linux
#

set -e  # exit on error

echo "[1/5] Updating system..."
sudo pacman -Syu --noconfirm

echo "[2/5] Installing prerequisites..."
sudo pacman -S --needed --noconfirm base-devel git

echo "[3/5] Cloning paru-bin from AUR..."
cd /tmp
if [ -d paru-bin ]; then
  rm -rf paru-bin
fi
git clone https://aur.archlinux.org/paru-bin.git
cd paru-bin

echo "[4/5] Building and installing paru..."
makepkg -si --noconfirm

echo "[5/5] Cleaning up..."
cd ..
rm -rf paru-bin

echo "✅ paru has been installed successfully!"
echo "You can now install AUR packages like:"
echo "    paru -S <packagename>"