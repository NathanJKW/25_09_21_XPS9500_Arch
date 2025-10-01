#!/usr/bin/env bash
# meta: id=40 name="GPU setup (Intel primary + NVIDIA PRIME offload)" desc="Enable multilib, install NVIDIA+Intel stacks (incl. 32-bit), blacklist nouveau, KMS/initramfs, PRIME offload, power helpers, verification" needs_root=true
#
# Target: Dell XPS 15 9500 (Intel UHD + NVIDIA GTX 1650 Ti Mobile, muxless/Optimus).
# Arch Wiki refs in comments:
# - NVIDIA; PRIME; NVIDIA Optimus; DRM KMS; Early loading; Nouveau blacklist; Power mgmt; Official repositories/multilib

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# Minimal config: set to "true" for unattended pacman/yay
ASSUME_YES="${ASSUME_YES:-false}"

log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then exec sudo -E -- bash "$0" "$@"; fi
    fail "This module requires root."
  fi
}

pac() {
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  /usr/bin/pacman -S "${extra[@]}" "$@"
}
pac_full_sync() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  /usr/bin/pacman -Syyu "${extra[@]}"
}

backup_file() { [[ -e "$1" ]] && /usr/bin/cp -a -- "$1" "$1.bak.$(date +%s)"; }

# ---------------- Hardware sanity (non-destructive)
check_hardware() {
  /usr/bin/pacman -Qi pciutils >/dev/null 2>&1 || pac pciutils
  /usr/bin/lspci -nn | /usr/bin/grep -q 'VGA compatible controller.*Intel'  || fail "Intel iGPU not detected"
  /usr/bin/lspci -nn | /usr/bin/grep -q '3D controller.*NVIDIA'             || fail "NVIDIA dGPU not detected"
  ok "Detected Intel iGPU + NVIDIA dGPU (Optimus)"
}

# ---------------- Repo fixes: enable ONLY the intended multilib lines, disable stray custom repo
enable_multilib_repo() {
  local cfg="/etc/pacman.conf"
  backup_file "$cfg"

  # Already enabled?
  if /usr/bin/pacman-conf | /usr/bin/grep -qx '\[multilib\]'; then
    ok "[multilib] repository already enabled"
  else
    # 1) Ensure header exists and is uncommented (replace the commented header if present)
    if /usr/bin/grep -q '^[[:space:]]*#\[multilib\][[:space:]]*$' "$cfg"; then
      log "Enabling [multilib] (uncommenting header)"
      /usr/bin/sed -i 's/^[[:space:]]*#\[multilib\][[:space:]]*$/[multilib]/' "$cfg"
    elif ! /usr/bin/grep -q '^[[:space:]]*\[multilib\][[:space:]]*$' "$cfg"; then
      log "Enabling [multilib] (appending canonical block)"
      printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$cfg"
    fi

    # 2) Within the [multilib] section, ensure the Include line is present and uncommented exactly
    if /usr/bin/grep -q '^[[:space:]]*\[multilib\][[:space:]]*$' "$cfg"; then
      /usr/bin/sed -i '/^[[:space:]]*\[multilib\][[:space:]]*$/,/^[[:space:]]*\[/{
        s/^[[:space:]]*#\s*Include[[:space:]]*=[[:space:]]*\/etc\/pacman\.d\/mirrorlist[[:space:]]*$/Include = \/etc\/pacman.d\/mirrorlist/;
      }' "$cfg"

      # 3) Re-comment any other non-blank, non-comment lines in the [multilib] section that are not the Include line.
      /usr/bin/sed -i '/^[[:space:]]*\[multilib\][[:space:]]*$/,/^[[:space:]]*\[/{ 
        /^[[:space:]]*\[multilib\][[:space:]]*$/b;
        /^[[:space:]]*$/b;
        /^#.*$/b;
        /^Include[[:space:]]*=[[:space:]]*\/etc\/pacman\.d\/mirrorlist$/b;
        s/^[^#]/#&/;
      }' "$cfg"
    fi

    ok "[multilib] section normalized"
  fi

  pac_full_sync
  ok "Package databases refreshed"
}

disable_custom_repo_if_broken() {
  local cfg="/etc/pacman.conf"
  # If a [custom] repo is enabled but points to /home/custompkgs (the common example),
  # comment the whole section to avoid sync failures.
  if /usr/bin/pacman-conf | /usr/bin/grep -qx '\[custom\]'; then
    # Peek at its Server lines
    local servers
    servers="$(/usr/bin/grep -A3 '^[[:space:]]*\[custom\][[:space:]]*$' "$cfg" | /usr/bin/grep -E '^[[:space:]]*Server[[:space:]]*=')"
    if grep -q '/home/custompkgs' <<<"$servers"; then
      log "Disabling stray [custom] repo (example path detected)"
      backup_file "$cfg"
      /usr/bin/sed -i '/^[[:space:]]*\[custom\][[:space:]]*$/,/^[[:space:]]*\[/{ s/^[^#]/#&/ }' "$cfg"
      pac_full_sync
      ok "[custom] repo disabled and databases refreshed"
    fi
  fi
}

# ---------------- Packages (Intel + NVIDIA + 32-bit, plus test tools)
install_packages() {
  pac mesa vulkan-intel
  pac nvidia nvidia-utils
  pac lib32-vulkan-intel lib32-nvidia-utils
  pac mesa-utils vulkan-tools
  ok "Driver stacks installed (Intel provider + NVIDIA dGPU; 32-bit userspace present)"
}

# ---------------- Kernel modules + initramfs
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

# ---------------- PRIME render offload helper
install_prime_run() {
  /usr/bin/install -D -m 0755 /dev/null /usr/local/bin/prime-run
  cat >/usr/local/bin/prime-run <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
exec "$@"
EOF
  ok "prime-run installed"
}

# ---------------- NVIDIA power helpers
enable_power_services() {
  /usr/bin/systemctl enable --now nvidia-suspend.service nvidia-resume.service 2>/dev/null || true
  /usr/bin/systemctl enable --now nvidia-hibernate.service 2>/dev/null || true
  if /usr/bin/systemctl list-unit-files | /usr/bin/grep -q '^nvidia-powerd\.service'; then
    /usr/bin/systemctl enable --now nvidia-powerd.service 2>/dev/null || true
  fi
  ok "NVIDIA power helpers configured (where available)"
}

# ---------------- Rebuild GRUB if present
rebuild_grub_if_present() {
  if [[ -x /usr/bin/grub-mkconfig && -d /boot/grub ]]; then
    /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
    ok "GRUB configuration rebuilt"
  else
    log "Note: GRUB not detected; skipping grub-mkconfig"
  fi
}

# ---------------- Verification (non-destructive)
verify_stack() {
  if /usr/bin/lsmod | /usr/bin/grep -q '^nouveau'; then
    fail "nouveau module is loaded. Reboot required to apply blacklist and early KMS."
  fi
  if [[ -r /sys/module/nvidia_drm/parameters/modeset ]]; then
    local val; val="$(</sys/module/nvidia_drm/parameters/modeset)"
    [[ "$val" == "Y" ]] || fail "nvidia_drm modeset is '$val' (expected 'Y')."
  else
    log "Note: nvidia_drm not loaded yet (normal before reboot)."
  fi
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

main() {
  require_root "$@"
  check_hardware
  enable_multilib_repo
  disable_custom_repo_if_broken
  install_packages
  apply_kernel_module_configs
  install_prime_run
  enable_power_services
  rebuild_grub_if_present
  log "Reboot recommended to load nvidia_drm from initramfs and ensure nouveau stays out."
  verify_stack
  ok "GPU setup complete"
}

main "$@"
