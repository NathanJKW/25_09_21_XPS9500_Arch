#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# Arch + sway (wlroots) graphics provisioning for Intel iGPU + NVIDIA offload
# - Enable [multilib]
# - Install NVIDIA proprietary + Intel pieces (+ Xwayland for glxinfo)
# - Disable nouveau; enable KMS + runtime PM
# - Safe mkinitcpio MODULES update (no fragile sed braces)
# - Add udev rule for runtime PM; clean unused drivers; rebuild initramfs
# =============================================================================

# ------------------------------- helpers -------------------------------------
fail() { echo "ERROR: $*" >&2; exit 1; }
backup_file() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  local ts; ts="$(date +%Y%m%d-%H%M%S)"
  cp -a -- "$f" "${f}.bak.${ts}"
}
is_installed() { pacman -Qq "$1" &>/dev/null; }

# ---------------------------- pre-flight checks ------------------------------
echo "==> Pre-flight checks..."
command -v pacman >/dev/null       || fail "pacman is required."
command -v pacman-conf >/dev/null  || fail "pacman-conf is required (part of pacman)."
command -v lspci >/dev/null        || fail "pciutils is required (install: pacman -S pciutils)."
command -v mkinitcpio >/dev/null   || fail "mkinitcpio is required."

lspci | grep -q "Intel Corporation CometLake-H GT2" || fail "Intel iGPU (CometLake-H) not detected."
lspci | grep -q "NVIDIA Corporation TU117M"          || fail "NVIDIA dGPU (TU117M) not detected."

# =============================== STEP 0: MULTILIB =============================
echo "==> Ensuring [multilib] repository is enabled..."
if pacman-conf --repo-list | grep -qx multilib; then
  echo "    [multilib] already enabled."
else
  PACCONF="/etc/pacman.conf"
  backup_file "$PACCONF"

  # Try to uncomment a standard commented block.
  sed -i -E 's/^\s*#\s*\[multilib\]\s*$/[multilib]/' "$PACCONF"
  sed -i -E '/^\s*\[multilib\]\s*$/,/^$/{s/^\s*#\s*(Include\s*=\s*\/etc\/pacman\.d\/mirrorlist)\s*$/\1/}' "$PACCONF"

  # Append a correct block if still missing.
  if ! pacman-conf --repo-list | grep -qx multilib; then
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$PACCONF"
  fi

  pacman-conf --repo-list | grep -qx multilib || fail "Failed to enable [multilib]."
  echo "==> Refreshing package databases..."
  pacman -Syy
fi

# ---------------------------- package install --------------------------------
echo "==> Installing required graphics packages (Intel + NVIDIA offload)..."
pacman -Syu --needed --noconfirm \
  nvidia nvidia-utils lib32-nvidia-utils nvidia-prime nvidia-settings \
  vulkan-tools mesa-demos intel-media-driver xorg-xwayland

# ---------------------------- disable nouveau --------------------------------
echo "==> Disabling nouveau (so proprietary NVIDIA binds the dGPU)..."
install -d /etc/modprobe.d
backup_file /etc/modprobe.d/blacklist-nouveau.conf
cat >/etc/modprobe.d/blacklist-nouveau.conf <<'__EOF_BLACKLIST_NOUVEAU__'
# Use proprietary NVIDIA driver for PRIME offload on wlroots/sway; disable nouveau.
blacklist nouveau
options nouveau modeset=0
__EOF_BLACKLIST_NOUVEAU__

# ----------------------- nvidia module options (KMS/PM) ----------------------
echo "==> Writing NVIDIA module options (KMS + runtime PM)..."
backup_file /etc/modprobe.d/nvidia.conf
cat >/etc/modprobe.d/nvidia.conf <<'__EOF_NVIDIA_CONF__'
# Enable DRM KMS for Wayland friendliness.
options nvidia_drm modeset=1
# Enable runtime power management so the dGPU powers down when idle.
options nvidia NVreg_DynamicPowerManagement=0x02
# Optional (uncomment if suspend issues with VRAM):
# options nvidia NVreg_PreserveVideoMemoryAllocations=1
__EOF_NVIDIA_CONF__

# ---------------------------- mkinitcpio modules -----------------------------
echo "==> Ensuring early KMS modules are present in /etc/mkinitcpio.conf..."
MKCFG=/etc/mkinitcpio.conf
backup_file "$MKCFG"
declare -a want_modules=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)

existing_modules_line="$(sed -n 's/^MODULES=(\(.*\))$/\1/p' "$MKCFG")"
declare -a merged_modules=()
if [[ -n "$existing_modules_line" ]]; then
  # shellcheck disable=SC2206
  merged_modules=($existing_modules_line)
fi
for m in "${want_modules[@]}"; do
  if ! printf '%s\n' "${merged_modules[@]}" | grep -qx "$m"; then
    merged_modules+=("$m")
  fi
done

tmp="$(mktemp)"
{
  echo "MODULES=(${merged_modules[*]})"
  grep -vE '^MODULES=\(' "$MKCFG" || true
} > "$tmp"
mv -- "$tmp" "$MKCFG"

# --------------------------- kernel command line -----------------------------
echo "==> Ensuring kernel parameter: nvidia_drm.modeset=1 ..."
add_param="nvidia_drm.modeset=1"

# systemd-boot
sdboot_dir=/boot/loader/entries
if [[ -d "$sdboot_dir" ]]; then
  shopt -s nullglob
  for entry in "$sdboot_dir"/*.conf; do
    backup_file "$entry"
    if grep -q '^options ' "$entry"; then
      grep -q "$add_param" "$entry" || sed -i "s|^options \(.*\)|options \1 ${add_param}|" "$entry"
    else
      echo "options ${add_param}" >>"$entry"
    fi
  done
  shopt -u nullglob
fi

# GRUB
if [[ -f /etc/default/grub ]]; then
  backup_file /etc/default/grub
  if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
    grep -q "$add_param" /etc/default/grub || \
      sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${add_param}\"|" /etc/default/grub
  else
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${add_param}\"" >> /etc/default/grub
  fi
  if command -v grub-mkconfig >/dev/null; then
    if [[ -d /boot/grub ]]; then
      grub-mkconfig -o /boot/grub/grub.cfg
    elif [[ -d /efi/GRUB || -d /efi/grub ]]; then
      grub-mkconfig -o /efi/grub/grub.cfg
    fi
  fi
fi

# ---------------------- Runtime PM via udev (power/control=auto) -------------
echo "==> Installing udev rule for NVIDIA runtime PM (power/control=auto)..."
install -d /etc/udev/rules.d
backup_file /etc/udev/rules.d/80-nvidia-runtime-pm.rules
cat >/etc/udev/rules.d/80-nvidia-runtime-pm.rules <<'__EOF_NVIDIA_UDEV__'
# Set runtime PM to 'auto' for NVIDIA GPUs on driver bind.
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", TEST=="power/control", ATTR{power/control}="auto"
__EOF_NVIDIA_UDEV__
udevadm control --reload
udevadm trigger -s pci || true

# ------------------------------ initramfs build ------------------------------
echo "==> Rebuilding initramfs..."
mkinitcpio -P

# --------------------------- enable nvidia-powerd ----------------------------
if systemctl list-unit-files | grep -q '^nvidia-powerd\.service'; then
  echo "==> Enabling nvidia-powerd.service ..."
  systemctl enable --now nvidia-powerd.service || true
fi

# =============================== CLEAN-UP ====================================
echo "==> Cleaning up unused GPU drivers and ICDs..."
to_remove=()
for p in \
  vulkan-nouveau \
  vulkan-radeon \
  xf86-video-nouveau \
  xf86-video-ati \
  xf86-video-amdgpu \
; do
  is_installed "$p" && to_remove+=("$p")
done

if ((${#to_remove[@]})); then
  echo "==> Removing: ${to_remove[*]}"
  pacman -Rns --noconfirm "${to_remove[@]}"
else
  echo "==> No unneeded vendor drivers found to remove."
fi

echo "==> Removing orphaned packages (if any)..."
orphans="$(pacman -Qtdq || true)"
if [[ -n "${orphans}" ]]; then
  # shellcheck disable=SC2086
  pacman -Rns --noconfirm ${orphans}
else
  echo "==> No orphaned packages."
fi

echo "==> Rebuilding initramfs after cleanup..."
mkinitcpio -P

# ------------------------------ summary/help ---------------------------------
XHOLD="$(ps -eo comm | grep -E '^(Xorg|Xorg.bin)$' || true)'"
cat <<'__EOF_SUMMARY_1__'

===============================================================================
Graphics setup complete (Intel primary + NVIDIA offload) and cleanup done.

NEXT (after reboot):
  nvidia-smi
  glxinfo -B | grep -E 'OpenGL (vendor|renderer|version)'
  prime-run glxinfo -B | grep -E 'OpenGL (vendor|renderer|version)'
  vulkaninfo --summary | sed -n '1,60p'

Use the dGPU on demand:
  prime-run <command>   # e.g., prime-run blender

Note:
  - A background X server (e.g., some greeters) can keep the dGPU awake and
    prevent runtime PM from suspending it.
__EOF_SUMMARY_1__

if [[ -n "${XHOLD}" ]]; then
  cat <<'__EOF_SUMMARY_X__'
Detected an Xorg server running right now. If this is your greeter (e.g., SDDM),
consider a Wayland-native greeter (greetd+tuigreet) or configure SDDM for Wayland.
__EOF_SUMMARY_X__
fi

cat <<'__EOF_SUMMARY_2__'

Troubleshooting:
  - Temporary cursor glitches in some setups:
      export WLR_NO_HARDWARE_CURSORS=1
  - Revert:
      rm -f /etc/modprobe.d/blacklist-nouveau.conf \
            /etc/modprobe.d/nvidia.conf \
            /etc/udev/rules.d/80-nvidia-runtime-pm.rules
      # Remove "nvidia_drm.modeset=1" from boot entry or GRUB default
      mkinitcpio -P ; reboot

We intentionally kept Mesa core, vulkan-icd-loader, vulkan-intel, and
intel-media-driver; these are required for Intel on sway.
===============================================================================
__EOF_SUMMARY_2__
