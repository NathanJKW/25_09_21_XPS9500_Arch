#!/usr/bin/env bash
# setup-audio.sh - simple PipeWire audio setup for Arch Linux

set -e

echo "[*] Updating system..."
sudo pacman -Syu --noconfirm

echo "[*] Installing PipeWire stack..."
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol

if pacman -Qq pulseaudio &>/dev/null; then
  echo "[*] Removing PulseAudio (conflicts with PipeWire)..."
  sudo pacman -Rns --noconfirm pulseaudio
fi

echo "[*] Enabling PipeWire user services..."
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

echo "[*] Verifying setup..."
systemctl --user status pipewire.service --no-pager -l | grep "Active:"
systemctl --user status pipewire-pulse.service --no-pager -l | grep "Active:"
systemctl --user status wireplumber.service --no-pager -l | grep "Active:"

echo
echo "[*] Listing audio devices (ALSA):"
aplay -l || true

echo
echo "[*] PipeWire info:"
pactl info || true

echo
echo "[*] Done! Use 'pavucontrol' to pick your output device (HDMI, speakers, etc)."
