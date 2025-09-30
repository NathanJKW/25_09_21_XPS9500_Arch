#!/usr/bin/env bash
# meta: id=10 name="Base system" desc="Time/locale, networking, audio, firmware" needs_root=false
# This module performs base post-install config.
# - Per Arch Wiki: Installation guide → Post-install configuration
# - Per Arch Wiki: systemd-timesyncd, Network configuration, PipeWire, Bluetooth
# Conventions: boring & safe. No --noconfirm by default. Fail fast on errors.

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

# Respect ASSUME_YES from environment, if set by the harness
pac() {
  local extra=()
  [[ "${ASSUME_YES:-false}" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S --needed "${extra[@]}" "$@"
}

main() {
  # Defaults — override by exporting before running module if desired
  local TIMEZONE="${TIMEZONE:-Europe/London}"
  local LOCALE="${LOCALE:-en_US.UTF-8}"
  local KEYMAP="${KEYMAP:-us}"

  # Update packages (no --noconfirm by default; user can answer)
  sudo pacman -Syu
  ok "System updated"

  # Time + NTP — per Arch Wiki: systemd-timesyncd
  sudo ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  sudo timedatectl set-timezone "$TIMEZONE"
  sudo timedatectl set-ntp true
  sudo hwclock --systohc
  ok "Timezone + NTP configured"
}

main "$@"
