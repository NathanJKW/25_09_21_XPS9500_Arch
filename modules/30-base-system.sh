#!/usr/bin/env bash
# meta: id=30 name="Base system (utils + yay + power + audio + bluetooth)" desc="CLI utilities, yay (AUR), power management (PPD/TLP), PipeWire/WirePlumber audio, and BlueZ" needs_root=false
#
# Arch Wiki references (keep these accurate in comments):
# - Pacman: https://wiki.archlinux.org/title/Pacman
# - Makepkg (never as root): https://wiki.archlinux.org/title/Makepkg
# - AUR helpers: https://wiki.archlinux.org/title/AUR_helpers
# - Power management:
#     * Power management overview: https://wiki.archlinux.org/title/Power_management
#     * power-profiles-daemon: https://wiki.archlinux.org/title/Power_Profiles_Daemon
#     * TLP: https://wiki.archlinux.org/title/TLP
# - Audio:
#     * PipeWire: https://wiki.archlinux.org/title/PipeWire
#     * WirePlumber: https://wiki.archlinux.org/title/WirePlumber
#     * ALSA: https://wiki.archlinux.org/title/Advanced_Linux_Sound_Architecture
#     * RealtimeKit: https://wiki.archlinux.org/title/RealtimeKit
# - Bluetooth (BlueZ): https://wiki.archlinux.org/title/Bluetooth
#
# Style & conventions:
# - Run as a regular user (needs_root=false). Use sudo for system changes.
# - No --noconfirm by default; set ASSUME_YES=true for unattended runs.
# - Small functions; explicit verification after each major step.
# - Strict: any failure exits non-zero.

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================================
# Config (override via env)
# ================================
UTILS_ENABLE_CORE="${UTILS_ENABLE_CORE:-true}"
UTILS_ENABLE_NET_TOOLS="${UTILS_ENABLE_NET_TOOLS:-true}"
UTILS_ENABLE_FS_TOOLS="${UTILS_ENABLE_FS_TOOLS:-true}"
UTILS_ENABLE_SYS_TOOLS="${UTILS_ENABLE_SYS_TOOLS:-true}"
UTILS_ENABLE_DOCS="${UTILS_ENABLE_DOCS:-true}"

AUR_PACKAGES="${AUR_PACKAGES:-}"             # e.g., 'bat-extras bottom-bin'

PM_BACKEND="${PM_BACKEND:-ppd}"              # 'ppd' or 'tlp'
ENABLE_POWERTOP="${ENABLE_POWERTOP:-false}"

BT_AUTOENABLE="${BT_AUTOENABLE:-true}"
BT_POWER_ON_NOW="${BT_POWER_ON_NOW:-true}"

ASSUME_YES="${ASSUME_YES:-false}"

# ================================
# Logging / helpers
# ================================
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }

ensure_not_root() {
  # per Arch Wiki: Makepkg must NOT run as root
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "Run this module as a regular user (it will sudo only for system changes)."
  fi
}

pac() {
  # Wrapper around pacman respecting ASSUME_YES; always uses --needed
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S "${extra[@]}" "$@"
}

pac_update() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -Syu "${extra[@]}"
}

pac_remove() {
  # pac_remove <pkgs...> (respects ASSUME_YES)
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -Rns "${extra[@]}" "$@"
}

verify_pkgs_installed() {
  local missing=()
  for p in "$@"; do
    pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [[ "${#missing[@]}" -eq 0 ]] || fail "Packages not installed: ${missing[*]}"
}

wait_for_condition() {
  # usage: wait_for_condition <seconds> <cmd...>
  local timeout="$1"; shift
  local t=0
  while ! "$@" >/dev/null 2>&1; do
    ((t++))
    if (( t >= timeout )); then
      return 1
    fi
    sleep 1
  done
  return 0
}

# ================================
# yay bootstrap (AUR via makepkg as user)
# ================================
install_yay_if_needed() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay present"
    return 0
  fi

  # per Arch Wiki: makepkg prerequisites
  pac git base-devel
  ok "Prerequisites installed (git, base-devel)"

  local builddir
  builddir="$(mktemp -d -t aur-yay-XXXXXXXX)"

  git clone https://aur.archlinux.org/yay.git "$builddir/yay" >/dev/null
  pushd "$builddir/yay" >/dev/null
  local mflags=()
  [[ "$ASSUME_YES" == "true" ]] && mflags+=(--noconfirm)
  makepkg -si "${mflags[@]}"
  popd >/dev/null
  rm -rf -- "$builddir"

  command -v yay >/dev/null 2>&1 || fail "yay not found after build"
  ok "yay installed"
}

# ================================
# Utilities (official repos)
# ================================
collect_util_packages() {
  PKGS=()

  if [[ "$UTILS_ENABLE_CORE" == "true" ]]; then
    PKGS+=(vim nano less which tree ripgrep fd jq rsync)
  fi
  if [[ "$UTILS_ENABLE_NET_TOOLS" == "true" ]]; then
    PKGS+=(curl wget aria2 openssh openbsd-netcat iperf3 mtr)
  fi
  if [[ "$UTILS_ENABLE_FS_TOOLS" == "true" ]]; then
    PKGS+=(exfatprogs ntfs-3g dosfstools mtools)
  fi
  if [[ "$UTILS_ENABLE_SYS_TOOLS" == "true" ]]; then
    PKGS+=(htop iotop lsof strace pciutils usbutils dmidecode lm_sensors smartmontools nvme-cli)
  fi
  if [[ "$UTILS_ENABLE_DOCS" == "true" ]]; then
    PKGS+=(man-db man-pages texinfo)
  fi
}

install_official_utils() {
  collect_util_packages
  if [[ "${#PKGS[@]}" -gt 0 ]]; then
    pac "${PKGS[@]}"
    verify_pkgs_installed "${PKGS[@]}"
    ok "CLI utilities installed"
  else
    ok "No utility categories enabled"
  fi
}

# ================================
# AUR optional installs
# ================================
install_aur_optional() {
  [[ -z "$AUR_PACKAGES" ]] && { ok "No AUR packages requested"; return 0; }
  ensure_cmd yay
  local yflags=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && yflags+=(--noconfirm)
  # shellcheck disable=SC2086
  yay -S ${yflags[*]} $AUR_PACKAGES

  local missing=()
  for p in $AUR_PACKAGES; do
    pacman -Qi "$p" >/dev/null 2>&1 || yay -Q "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [[ "${#missing[@]}" -eq 0 ]] || fail "AUR packages not installed: ${missing[*]}"
  ok "AUR packages installed"
}

# ================================
# Power management
# ================================
setup_power_profiles_daemon() {
  # per Arch Wiki: PPD — disable TLP to avoid conflicts
  pac power-profiles-daemon
  sudo systemctl disable --now tlp.service tlp-sleep.service 2>/dev/null || true
  sudo systemctl enable --now power-profiles-daemon.service
  systemctl is-active --quiet power-profiles-daemon || fail "power-profiles-daemon not active"
  ok "power-profiles-daemon active"
  if [[ "$ENABLE_POWERTOP" == "true" ]]; then
    pac powertop
    verify_pkgs_installed powertop
    ok "powertop available"
  fi
}

setup_tlp() {
  # per Arch Wiki: TLP — disable PPD to avoid conflicts
  pac tlp
  sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
  sudo systemctl enable --now tlp.service
  sudo systemctl enable --now tlp-sleep.service 2>/dev/null || true
  systemctl is-active --quiet tlp || fail "TLP not active"
  ok "TLP active"
  if [[ "$ENABLE_POWERTOP" == "true" ]]; then
    pac powertop
    verify_pkgs_installed powertop
    ok "powertop available"
  fi
}

configure_power_management() {
  case "$PM_BACKEND" in
    ppd) setup_power_profiles_daemon ;;
    tlp) setup_tlp ;;
    *)   fail "Unknown PM_BACKEND='$PM_BACKEND' (use 'ppd' or 'tlp')" ;;
  esac
  ok "Power management configured (${PM_BACKEND})"
}

# ================================
# Audio (PipeWire + WirePlumber, strict)
# per Arch Wiki: PipeWire / WirePlumber / ALSA / RealtimeKit
# ================================
remove_conflicting_jack2_if_needed() {
  # PipeWire's jack shim (pipewire-jack) conflicts with jack2 (virtual "jack").
  if pacman -Qi jack2 >/dev/null 2>&1; then
    log "Removing jack2 (conflicts with pipewire-jack)"
    pac_remove jack2
  fi
}

configure_audio() {
  remove_conflicting_jack2_if_needed

  # Install PipeWire core, shims, session manager, ALSA tooling, firmware/UCM, RTKit
  pac pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rtkit alsa-utils alsa-ucm-conf sof-firmware
  verify_pkgs_installed pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rtkit alsa-utils alsa-ucm-conf sof-firmware

  # Enable RTKit system service (recommended)
  sudo systemctl enable --now rtkit-daemon.service
  systemctl is-active --quiet rtkit-daemon || fail "rtkit-daemon not active"

  # Ensure user services are enabled and running
  systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

  # Wait briefly for the graph to settle
  wait_for_condition 5 systemctl --user is-active pipewire    || fail "pipewire (user) not active"
  wait_for_condition 5 systemctl --user is-active wireplumber || fail "wireplumber (user) not active"

  # ALSA devices present
  aplay -l >/dev/null 2>&1 || fail "ALSA: no playback devices (aplay -l failed)"
  arecord -l >/dev/null 2>&1 || fail "ALSA: no capture devices (arecord -l failed)"

  # Pulse shim should be PipeWire's (accept versioned strings)
  command -v pactl >/dev/null 2>&1 || fail "pactl not available"
  local server
  server="$(pactl info 2>/dev/null | awk -F': ' '/Server Name/ {print $2}')"
  if [[ "${server:-}" != PulseAudio\ \(on\ PipeWire* ]]; then
    fail "Pulse shim not active (got: '${server:-none}')"
  fi

  # Basic sink/source presence via wpctl (if present)
  if command -v wpctl >/dev/null 2>&1; then
    wpctl status | grep -q 'Sinks:'   || fail "PipeWire: no sinks detected"
    wpctl status | grep -q 'Sources:' || fail "PipeWire: no sources detected"
  fi

  ok "Audio stack ready (PipeWire/WirePlumber + Pulse/JACK shims, RTKit, ALSA)"
}

# ================================
# Bluetooth (BlueZ)
# ================================
bluetooth_requirements() {
  pac linux-firmware bluez bluez-utils util-linux
  verify_pkgs_installed linux-firmware bluez bluez-utils util-linux

  # Load btusb (typical for Intel CNVi)
  sudo modprobe btusb || true

  # Unblock via rfkill (non-interactive)
  if rfkill list 2>/dev/null | grep -A2 -i bluetooth | grep -qi 'Soft blocked: yes'; then
    sudo rfkill unblock bluetooth || fail "rfkill unblock failed"
  fi
}

configure_bluetooth() {
  bluetooth_requirements

  # Configure AutoEnable to power on adapters on availability (policy)
  if [[ "$BT_AUTOENABLE" == "true" ]]; then
    sudo install -D -m 0644 /dev/null /etc/bluetooth/main.conf
    if ! grep -q '^AutoEnable=' /etc/bluetooth/main.conf 2>/dev/null; then
      printf '[Policy]\nAutoEnable=true\n' | sudo tee /etc/bluetooth/main.conf >/dev/null
    else
      sudo sed -i 's/^AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
    fi
  fi

  sudo systemctl enable --now bluetooth.service
  systemctl is-active --quiet bluetooth || fail "bluetooth.service not active"

  # Wait briefly for controller enumeration after service start
  wait_for_condition 5 bash -c "bluetoothctl list | grep -q '^Controller'" || fail "No Bluetooth controller detected"

  if [[ "$BT_POWER_ON_NOW" == "true" ]]; then
    if ! bluetoothctl show | grep -q 'Powered: yes'; then
      printf 'power on\nquit\n' | bluetoothctl >/dev/null 2>&1 || true
      wait_for_condition 5 bash -c "bluetoothctl show | grep -q 'Powered: yes'" || fail "Bluetooth controller not powered"
    fi
  fi

  ok "Bluetooth controller present and powered"
}

# ================================
# Main
# ================================
main() {
  ensure_not_root
  ensure_cmd sudo

  # Keep system fresh; honors ASSUME_YES
  pac_update
  ok "System updated"

  install_yay_if_needed
  ok "yay available"

  install_official_utils
  install_aur_optional

  configure_power_management
  configure_audio
  configure_bluetooth

  ok "Base system module complete"
}

main "$@"
