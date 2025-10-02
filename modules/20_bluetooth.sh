#!/usr/bin/env bash
# Bluetooth probe & setup for Arch (Intel/Killer AX1650s)
# Usage: chmod +x bt_probe.sh && ./bt_probe.sh

# figure out where the script itself lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="${SCRIPT_DIR}/bt_fix_probe.log"

# 1) ensure required packages
sudo pacman -S --needed --noconfirm bluez bluez-utils usbutils linux-firmware

# 2) enable & start bluetooth service
sudo systemctl enable --now bluetooth.service || true

# 3) collect diagnostics
{
  echo "=== Kernel (this boot): bluetooth/iwl ==="
  sudo journalctl -b -k | grep -Ei 'bluetooth|hci0|btusb|iwl' || true

  echo -e "\n=== Modules ==="
  lsmod | grep -Ei '(^bt|btusb|iwl)' || true

  echo -e "\n=== PCI: Network controller ==="
  lspci -nnk | grep -A4 -i 'Network controller' || true

  echo -e "\n=== USB enumeration (Bluetooth/Intel) ==="
  lsusb | grep -Ei 'bluetooth|intel|8087' || true

  echo -e "\n=== rfkill (blocks) ==="
  rfkill list || true

  echo -e "\n=== bluetoothctl (controller) ==="
  bluetoothctl list || true
  bluetoothctl show || true
} > "$LOG"

echo "→ Diagnostics saved to $LOG"
