#!/usr/bin/env bash
# meta: id=40 name="GPU setup (Intel primary + NVIDIA PRIME offload)" desc="Install NVIDIA stack, blacklist nouveau, early KMS, PRIME offload, power mgmt, and verification" needs_root=true
#
# Hardware target: Dell XPS 15 9500 (Intel UHD + NVIDIA GTX 1650 Ti Mobile TU117, muxless/Optimus).
#  - Internal panel is wired to the Intel iGPU; NVIDIA is for compute/render offload only. :contentReference[oaicite:5]{index=5}
#
# Arch Wiki references (keep accurate):
# - NVIDIA (driver, early KMS, power mgmt): https://wiki.archlinux.org/title/NVIDIA :contentReference[oaicite:6]{index=6}
# - PRIME (render offload env): https://wiki.archlinux.org/title/PRIME :contentReference[oaicite:7]{index=7}
# - NVIDIA Optimus (hybrid): https://wiki.archlinux.org/title/NVIDIA_Optimus :contentReference[oaicite:8]{index=8}
# - KMS background: https://wiki.archlinux.org/title/Kernel_mode_setting :contentReference[oaicite:9]{index=9}
# - NVIDIA power services: nvidia-suspend/resume/hibernate, nvidia-powerd. :contentReference[oaicite:10]{index=10}
#
# Style: boring, explicit, reproducible. No --noconfirm unless ASSUME_YES=true.

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ----------------
# Config (override via env)
# ----------------
ASSUME_YES="${ASSUME_YES:-false}"                   # unattended installs if true
INSTALL_TEST_TOOLS="${INSTALL_TEST_TOOLS:-true}"    # mesa-utils, vulkan-tools
ENABLE_PM_SERVICES="${ENABLE_PM_SERVICES:-true}"    # enable NVIDIA sleep/hibernate helpers
ENABLE_NVIDIA_POWERD="${ENABLE_NVIDIA_POWERD:-auto}"# auto|true|false (auto: enable if unit exists)
HYPRLAND_CURSOR_WORKAROUND="${HYPRLAND_CURSOR_WORKAROUND:-false}" # sets WLR_NO_HARDWARE_CURSORS=1 system-wide

# Paths
MODPROBE_DIR="/etc/modprobe.d"
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
GRUB_DIR="/boot/grub"

# ----------------
# Logging
# ----------------
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

# ----------------
# Helpers
# ----------------
require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then exec sudo -E -- bash "$0" "$@"; fi
    fail "This module requires root."
  fi
}

pac() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  pacman -S --needed "${extra[@]}" "$@"
}

backup_file() { [[ -e "$1" ]] && cp -a -- "$1" "$1.bak.$(date +%s)"; }

append_once_literal() {
  local file="$1" line="$2"
  grep -Fxq -- "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >>"$file"
}

rebuild_initramfs() { mkinitcpio -P; }
rebuild_grub_if_present() { [[ -x /usr/bin/grub-mkconfig && -d "$GRUB_DIR" ]] && grub-mkconfig -o "$GRUB_DIR/grub.cfg" || true; }

verify_kernel_param() {
  local path="$1" want="$2"
  [[ -r "$path" ]] || return 0
  local got; got="$(<"$path")"
  [[ "$got" == "$want" ]] || fail "Kernel param mismatch: $path='$got' (want '$want')"
}

wait_cmd() {
  local sec="$1"; shift
  local t=0
  while ! "$@" >/dev/null 2>&1; do
    ((t++>=sec)) && return 1
    sleep 1
  done
}

# ----------------
# Hardware sanity (non-destructive)
# ----------------
check_hardware() {
  command -v lspci >/dev/null 2>&1 || pac pciutils
  lspci -nn | grep -q 'VGA compatible controller.*Intel'   || fail "Intel iGPU not detected"
  lspci -nn | grep -q '3D controller.*NVIDIA'              || fail "NVIDIA dGPU not detected"
  ok "Detected Intel iGPU + NVIDIA dGPU (Optimus)"
}

# ----------------
# Packages
# ----------------
install_packages() {
  # Intel userspace bits (display provider) + NVIDIA stack
  pac mesa vulkan-intel lib32-vulkan-intel
  pac nvidia nvidia-utils lib32-nvidia-utils

  if [[ "$INSTALL_TEST_TOOLS" == "true" ]]; then
    pac mesa-utils vulkan-tools
  fi
  ok "Driver stacks installed (Intel provider + NVIDIA dGPU)"
}

# ----------------
# Module configs (disable nouveau; NVIDIA DRM KMS)
# per Arch Wiki: NVIDIA → DRM kernel mode setting; disable nouveau to avoid races. :contentReference[oaicite:11]{index=11}
# ----------------
write_modprobe_configs() {
  install -d -m 0755 "$MODPROBE_DIR"

  backup_file "$MODPROBE_DIR/blacklist-nouveau.conf"
  cat >"$MODPROBE_DIR/blacklist-nouveau.conf" <<'EOF'
# Disable nouveau to prevent conflicts with proprietary NVIDIA driver
# per Arch Wiki: NVIDIA → Nouveau
blacklist nouveau
options nouveau modeset=0
EOF

  backup_file "$MODPROBE_DIR/nvidia-drm.conf"
  cat >"$MODPROBE_DIR/nvidia-drm.conf" <<'EOF'
# Enable DRM KMS for NVIDIA (Wayland/X11 stability)
# per Arch Wiki: NVIDIA → DRM kernel mode setting
options nvidia-drm modeset=1 fbdev=1
EOF

  ok "Modprobe configs applied (nouveau blacklisted; nvidia-drm KMS enabled)"
}

# ----------------
# Initramfs: early loading of NVIDIA modules
# per Arch Wiki: NVIDIA → Early loading with mkinitcpio MODULES. :contentReference[oaicite:12]{index=12}
# ----------------
configure_initramfs() {
  [[ -r "$MKINITCPIO_CONF" ]] || fail "Missing $MKINITCPIO_CONF"
  backup_file "$MKINITCPIO_CONF"
  if ! grep -q 'BEGIN nvidia modules' "$MKINITCPIO_CONF"; then
    cat >>"$MKINITCPIO_CONF" <<'EOF'

# BEGIN nvidia modules (per Arch Wiki: NVIDIA → Early loading)
# Intel remains the display/KMS provider; these are loaded early for PRIME stability.
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
# END nvidia modules
EOF
  fi
  rebuild_initramfs
  ok "Initramfs rebuilt with NVIDIA modules"
}

# ----------------
# PRIME render offload wrapper (GL & Vulkan)
# per Arch Wiki: PRIME → Render offload env. :contentReference[oaicite:13]{index=13}
# ----------------
install_prime_run() {
  install -D -m 0755 /dev/null /usr/local/bin/prime-run
  cat >/usr/local/bin/prime-run <<'EOF'
#!/usr/bin/env bash
# PRIME render offload wrapper (OpenGL + Vulkan)
set -Eeuo pipefail
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
exec "$@"
EOF
  ok "prime-run installed"
}

# ----------------
# Power management helpers
# per Arch Wiki: NVIDIA/Tips and tricks → necessary services; NVIDIA README. :contentReference[oaicite:14]{index=14}
# ----------------
enable_power_services() {
  if [[ "$ENABLE_PM_SERVICES" == "true" ]]; then
    systemctl enable --now nvidia-suspend.service nvidia-resume.service 2>/dev/null || true
    systemctl enable --now nvidia-hibernate.service 2>/dev/null || true
  fi

  case "$ENABLE_NVIDIA_POWERD" in
    true)  systemctl enable --now nvidia-powerd.service 2>/dev/null || true ;;
    auto)  systemctl list-unit-files | grep -q '^nvidia-powerd.service' && systemctl enable --now nvidia-powerd.service || true ;;
    false) : ;;
    *)     : ;;
  esac

  ok "NVIDIA power helpers configured (where available)"
}

# ----------------
# Optional: Hyprland cursor workaround (off by default)
# (We’ll do Hyprland proper in 50-hyperland; this only sets an env var globally if enabled.)
# ----------------
maybe_enable_hypr_cursor_workaround() {
  if [[ "$HYPRLAND_CURSOR_WORKAROUND" != "true" ]]; then
    ok "Hyprland cursor workaround not enabled (default)"
    return 0
  fi
  install -d -m 0755 /etc/environment.d
  printf 'WLR_NO_HARDWARE_CURSORS=1\n' >/etc/environment.d/99-hyprland-nvidia-cursor.conf
  ok "WLR_NO_HARDWARE_CURSORS=1 set via /etc/environment.d (can remove if unnecessary)"
}

# ----------------
# Verification
# ----------------
verify_stack() {
  # nouveau must not be loaded (if it is, a reboot is required)
  if lsmod | grep -q '^nouveau'; then
    fail "nouveau module loaded. Reboot to apply blacklist and early KMS."
  fi

  # nvidia_drm modeset Y after driver loads (post-reboot this will exist)
  [[ -r /sys/module/nvidia_drm/parameters/modeset ]] && verify_kernel_param /sys/module/nvidia_drm/parameters/modeset "Y" || log "Note: nvidia_drm not loaded yet (OK before reboot)."

  # PRIME offload sanity (if XWayland/GL present)
  if command -v glxinfo >/dev/null 2>&1; then
    if prime-run glxinfo 2>/dev/null | grep -q 'OpenGL renderer.*NVIDIA'; then
      ok "OpenGL offload works (renderer is NVIDIA)"
    else
      log "Warning: glxinfo did not confirm NVIDIA via prime-run (check from a graphical session)."
    fi
  fi

  if command -v vkcube >/dev/null 2>&1; then
    prime-run vkcube --version >/dev/null 2>&1 || log "Warning: vkcube via prime-run failed (try after reboot/in-session)."
  fi

  ok "Verification complete"
}

# ----------------
# Main
# ----------------
main() {
  require_root "$@"
  check_hardware
  install_packages
  write_modprobe_configs
  configure_initramfs
  install_prime_run
  enable_power_services
  maybe_enable_hypr_cursor_workaround
  rebuild_grub_if_present
  log "Reboot recommended to load nvidia_drm from initramfs and keep nouveau out."
  verify_stack
  ok "GPU setup complete"
}

main "$@"
