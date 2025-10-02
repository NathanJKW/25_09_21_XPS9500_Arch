#!/usr/bin/env bash
# meta: id=10 name="Base system" desc="Time/locale, vconsole keymap, basic update" needs_root=false
# per Arch Wiki: Installation guide → Post-install configuration; systemd-timesyncd; Locale; Console keymap

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

ASSUME_YES="${ASSUME_YES:-false}"

pac() {
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S "${extra[@]}" "$@"
}
pac_update() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -Syu "${extra[@]}"
}

main() {
  # Defaults — safe, UK-centric; override by exporting before running the module.
  # LOCALE must exist in /etc/locale.gen (we uncomment it below).
  local TIMEZONE="${TIMEZONE:-Europe/London}"
  local LOCALE="${LOCALE:-en_GB.UTF-8}"
  local KEYMAP="${KEYMAP:-uk}"   # NOTE: Arch uses "uk", not "gb"

  # Update packages (honors ASSUME_YES)
  pac_update
  ok "System updated"

  # Time + NTP — per Arch Wiki: systemd-timesyncd
  sudo ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  sudo timedatectl set-timezone "$TIMEZONE"
  sudo timedatectl set-ntp true
  sudo hwclock --systohc
  ok "Timezone + NTP configured ($TIMEZONE)"

  # Locale — per Arch Wiki: Locale
  # 1) Ensure LOCALE is uncommented in /etc/locale.gen
  sudo sed -i "s/^#\s*${LOCALE//\//\\/}[[:space:]]\+UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
  # 2) Write /etc/locale.conf
  printf 'LANG=%s\n' "$LOCALE" | sudo tee /etc/locale.conf >/dev/null
  # 3) Generate
  sudo locale-gen
  ok "Locale generated and set (LANG=$LOCALE)"

  # Console keymap — per Arch Wiki: Linux console/Keyboard configuration
  printf 'KEYMAP=%s\n' "$KEYMAP" | sudo tee /etc/vconsole.conf >/dev/null
  ok "Console keymap set (KEYMAP=$KEYMAP)"

  # Optional: rebuild initramfs so keymap is baked into the keymap hook
  if command -v mkinitcpio >/dev/null 2>&1; then
    sudo mkinitcpio -P
    ok "Initramfs rebuilt (to include keymap)"
  fi
}

main "$@"
