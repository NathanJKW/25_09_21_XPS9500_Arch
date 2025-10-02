#!/usr/bin/env bash
#
# setup-jetbrains-nerd-font.sh
#
# Install JetBrainsMono Nerd Font system-wide and set it as the default monospace font.
#

set -euo pipefail

FONT_PKG="ttf-jetbrains-mono-nerd"
FONTCONF="/etc/fonts/local.conf"

echo "[*] Installing JetBrainsMono Nerd Font..."
sudo pacman -S --needed --noconfirm "$FONT_PKG"

echo "[*] Refreshing font cache..."
sudo fc-cache -f -v

echo "[*] Detecting JetBrains Nerd Font family name..."
FAMILY=$(fc-list | grep -m1 "JetBrainsMono Nerd Font" | sed -E 's/.*: "([^"]+)".*/\1/')

if [[ -z "$FAMILY" ]]; then
  echo "[!] Could not detect JetBrainsMono Nerd Font in fc-list!"
  exit 1
fi

echo "[*] Detected family: $FAMILY"

echo "[*] Writing fontconfig rule to $FONTCONF..."
sudo tee "$FONTCONF" >/dev/null <<EOF
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <!-- Default monospace font -->
  <match target="pattern">
    <test qual="any" name="family">
      <string>monospace</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FAMILY</string>
    </edit>
  </match>
</fontconfig>
EOF

echo "[*] Rebuilding font cache..."
sudo fc-cache -f -v

echo "[*] Verifying default monospace font..."
fc-match monospace

echo "[✓] JetBrainsMono Nerd Font is now the default monospace font system-wide."
