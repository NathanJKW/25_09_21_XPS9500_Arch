#!/usr/bin/env bash
# meta: id=40 name="GPU setup (Intel primary + NVIDIA PRIME offload)" desc="Enable multilib, install NVIDIA+Intel stacks (incl. 32-bit), blacklist nouveau, KMS/initramfs, PRIME offload, power helpers, verification" needs_root=true
#
# Hardware target: Dell XPS 15 9500 (Intel UHD + NVIDIA GTX 1650 Ti Mobile, muxless/Optimus).
#
# Arch Wiki references used in this script (keep these up to date in comments):
# - NVIDIA: https://wiki.archlinux.org/title/NVIDIA
# - PRIME render offload: https://wiki.archlinux.org/title/PRIME
# - NVIDIA Optimus: https://wiki.archlinux.org/title/NVIDIA_Optimus
# - DRM KMS (nvidia-drm modeset=1): https://wiki.archlinux.org/title/NVIDIA#DRM_kernel_mode_setting
# - Early module loading (mkinitcpio MODULES): https://wiki.archlinux.org/title/NVIDIA#Early_loading
# - nouveau blacklist: https://wiki.archlinux.org/title/Nouveau#Blacklisting
# - Power services (nvidia-suspend/resume/hibernate, nvidia-powerd): https://wiki.archlinux.org/title/NVIDIA#Power_management
# - Pacman repositories / multilib: https://wiki.archlinux.org/title/Official_repositories#multilib

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================
# Config (minimal)
# ================
# Only variable we allow: set to "true" for unattended operation (adds --noconfirm to pacman).
ASSUME_YES="${ASSUME_YES:-false}"

# ================
# Logging / guard
# ================
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

require_root() {
  # per our convention, this module runs as root; exec sudo if needed
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then exec sudo -E -- bash "$0" "$@"; fi
    fail "This module requires root."
  fi
}

# Pacman helpers
pac() {
  # per Arch Wiki: Pacman — always use --needed; keep interactivity unless ASSUME_YES=true
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  /usr/bin/pacman -S "${extra[@]}" "$@"
}

pac_full_sync() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  /usr/bin/pacman -Syyu "${extra[@]}"
}

# Small utility
backup_file() { [[ -e "$1" ]] && /usr/bin/cp -a -- "$1" "$1.bak.$(date +%s)"; }

# ==================================================
# Step 1: Ensure hardware is what we expect (non-destructive)
# ==================================================
check_hardware() {
  /usr/bin/pacman -Qi pciutils >/dev/null 2>&1 || pac pciutils
  /usr/bin/lspci -nn | /usr/bin/grep -q 'VGA compatible controller.*Intel'  || fail "Intel iGPU not detected"
  /usr/bin/lspci -nn | /usr/bin/grep -q '3D controller.*NVIDIA'             || fail "NVIDIA dGPU not detected"
  ok "Detected Intel iGPU + NVIDIA dGPU (Optimus)"
}

# ==================================================
# Step 2: Enable [multilib] (idempotent)
# per Arch Wiki: Official repositories → multilib
# ==================================================
enable_multilib_repo() {
  local cfg="/etc/pacman.conf"

  # Already enabled? Nothing to do.
  if /usr/bin/pacman-conf | /usr/bin/grep -qx '\[multilib\]'; then
    ok "[multilib] repository already enabled"
    return 0
  fi

  # If a commented canonical block exists, uncomment it. Else append a canonical block.
  if /usr/bin/grep -q '^#\[multilib\]' "$cfg"; then
    log "Enabling [multilib] (uncommenting existing block) — per Arch Wiki: Official repositories → multilib"
    /usr/bin/awk '
      BEGIN { in=0 }
      /^\#\[multilib\]/ { sub(/^\#/,""); print; in=1; next }
      in==1 && /^\#?Include[[:space:]]*=/ { sub(/^\#/,""); print; in=0; next }
      { print }
    ' "$cfg" > "$cfg.tmp"
    /usr/bin/mv -f "$cfg.tmp" "$cfg"
  else
    log "Enabling [multilib] (appending canonical block) — per Arch Wiki: Official repositories → multilib"
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$cfg"
  fi

  pac_full_sync
  ok "[multilib] enabled and package databases refreshed"
}

# ==================================================
# Step 3: Install drivers and tools
# - Intel userspace provider (mesa, vulkan-intel)
# - NVIDIA proprietary stack
# - 32-bit userspace (lib32-*) for Steam/Proton
# - Test tools (mesa-utils, vulkan-tools)
# ==================================================
install_packages() {
  # per Arch Wiki: NVIDIA / PRIME / Vulkan
  pac mesa vulkan-intel
  pac nvidia nvidia-utils
  pac lib32-vulkan-intel lib32-nvidia-utils
  # Optional test tools (harmless, useful for verification)
  pac mesa-utils vulkan-tools
  ok "Driver stacks installed (Intel provider + NVIDIA dGPU; 32-bit userspace present)"
}

# ==================================================
# Step 4: Kernel modules and initramfs
# - Blacklist nouveau (per NVIDIA page)
# - Enable nvidia-drm KMS (modeset=1)
# - Early load NVIDIA modules in mkinitcpio (per NVIDIA → Early loading)
# ==================================================
apply_kernel_module_configs() {
  /usr/bin/install -d -m 0755 /etc/modprobe.d

  backup_file /etc/modprobe.d/blacklist-nouveau.conf
  cat >/etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
# per Arch Wiki: Nouveau → Blacklisting
blacklist nouveau
options nouveau modeset=0
EOF

  backup_file /etc/modprobe.d/nvidia-drm.conf
  cat >/etc/modprobe.d/nvidia-drm.conf <<'EOF'
# per Arch Wiki: NVIDIA → DRM kernel mode setting
options nvidia-drm modeset=1 fbdev=1
EOF

  # mkinitcpio: append a clearly delimited block once
  local mkc="/etc/mkinitcpio.conf"
  [[ -r "$mkc" ]] || fail "Missing $mkc"
  backup_file "$mkc"
  if ! /usr/bin/grep -q 'BEGIN nvidia modules' "$mkc"; then
    cat >>"$mkc" <<'EOF'

# BEGIN nvidia modules (per Arch Wiki: NVIDIA → Early loading)
# Intel remains the display/KMS provider; these are loaded early for PRIME stability.
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
# END nvidia modules
EOF
  fi

  /usr/bin/mkinitcpio -P
  ok "Initramfs rebuilt with NVIDIA modules"
}

# ==================================================
# Step 5: PRIME render offload helper (simple wrapper)
# per Arch Wiki: PRIME → Render offload (OpenGL + Vulkan)
# ==================================================
install_prime_run() {
  /usr/bin/install -D -m 0755 /dev/null /usr/local/bin/prime-run
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

# ==================================================
# Step 6: NVIDIA power helpers
# - Enable suspend/resume/hibernate units if present
# - Enable nvidia-powerd when available (TGP control on some laptops)
# ==================================================
enable_power_services() {
  /usr/bin/systemctl enable --now nvidia-suspend.service nvidia-resume.service 2>/dev/null || true
  /usr/bin/systemctl enable --now nvidia-hibernate.service 2>/dev/null || true

  if /usr/bin/systemctl list-unit-files | /usr/bin/grep -q '^nvidia-powerd.service'; then
    /usr/bin/systemctl enable --now nvidia-powerd.service 2>/dev/null || true
  fi

  ok "NVIDIA power helpers configured (where available)"
}

# ==================================================
# Step 7: Bootloader refresh (if GRUB present)
# ==================================================
rebuild_grub_if_present() {
  if [[ -x /usr/bin/grub-mkconfig && -d /boot/grub ]]; then
    /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
    ok "GRUB configuration rebuilt"
  else
    log "Note: GRUB not detected; skipping grub-mkconfig"
  fi
}

# ==================================================
# Step 8: Verification (non-destructive)
# ==================================================
verify_stack() {
  # nouveau must not be loaded; if it is, we need a reboot to apply blacklist+initramfs
  if /usr/bin/lsmod | /usr/bin/grep -q '^nouveau'; then
    fail "nouveau module is loaded. Reboot required to apply blacklist and early KMS."
  fi

  # After reboot, this file should exist and be 'Y'. Before reboot it may be absent; warn, not fail.
  if [[ -r /sys/module/nvidia_drm/parameters/modeset ]]; then
    local val; val="$(</sys/module/nvidia_drm/parameters/modeset)"
    [[ "$val" == "Y" ]] || fail "nvidia_drm modeset is '$val' (expected 'Y')."
  else
    log "Note: nvidia_drm not loaded yet (normal before reboot)."
  fi

  # Quick user-space checks (only fully meaningful inside a GUI session)
  if command -v glxinfo >/dev/null 2>&1; then
    if /usr/local/bin/prime-run glxinfo 2>/dev/null | /usr/bin/grep -q 'OpenGL renderer.*NVIDIA'; then
      ok "OpenGL offload works (renderer is NVIDIA)"
    else
      log "Warning: glxinfo via prime-run did not report NVIDIA (try from a running session)."
    fi
  fi
  if command -v vkcube >/dev/null 2>&1; then
    /usr/local/bin/prime-run vkcube --version >/dev/null 2>&1 || log "Warning: vkcube via prime-run failed (OK before full GUI)."
  fi

  ok "Verification complete"
}

# ================
# Main
# ================
main() {
  require_root "$@"

  # 1) Sanity check hardware first
  check_hardware

  # 2) Ensure multilib is on (needed for 32-bit graphics userspace)
  enable_multilib_repo

  # 3) Install stacks
  install_packages

  # 4) Kernel modules + initramfs
  apply_kernel_module_configs

  # 5) PRIME helper
  install_prime_run

  # 6) Power helpers
  enable_power_services

  # 7) Bootloader refresh (if GRUB present)
  rebuild_grub_if_present

  log "Reboot recommended to load nvidia_drm from initramfs and ensure nouveau stays out."
  verify_stack
  ok "GPU setup complete"
}

main "$@"
