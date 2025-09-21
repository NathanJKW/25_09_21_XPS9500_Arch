#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install_sddm.sh  v1.0
#
# Minimal installer for SDDM on Arch Linux.
#
# - Installs the `sddm` package
# - Disables LightDM if present
# - Enables SDDM service
#
# Intended for use on a brand new minimal install where checks are unnecessary.
# -----------------------------------------------------------------------------

set -euo pipefail

# Install SDDM
sudo pacman -S --noconfirm --needed sddm

# Disable LightDM if present (harmless if not installed)
sudo systemctl disable lightdm.service --now || true

# Enable SDDM
sudo systemctl enable sddm.service --now

echo "✓ SDDM installed and enabled."
