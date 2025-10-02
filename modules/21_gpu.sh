#!/usr/bin/env bash
# Arch + Hyprland hybrid graphics setup (Intel default, NVIDIA PRIME offload)
# - Works on laptops like your XPS 9500 (i7-10750H + GTX 1650 Ti)
# - Installs stack, enables multilib, sets early KMS, writes Hyprland env
# - Idempotent; preserves custom mkinitcpio options; avoids /root writes

set -euo pipefail

# ---------------- sanity ----------------
if ! command -v pacman >/dev/null; then
  echo "This script targets Arch Linux." >&2; exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "Run as root:  sudo $0" >&2; exit 1
fi

USR="${SUDO_USER:-$(logname 2>/dev/null || true)}"
[[ -n "${USR:-}" ]] || { echo "Cannot determine invoking user." >&2; exit 1; }
USER_HOME="$(getent passwd "$USR" | cut -d: -f6)"
[[ -d "$USER_HOME" ]] || { echo "Home for $USR not found." >&2; exit 1; }

# ---------------- multilib ----------------
PACCONF="/etc/pacman.conf"
if ! grep -q '^\[multilib\]' "$PACCONF"; then
  # Un-comment the stock multilib block if present
  sed -i -e 's/^[[:space:]]*#\[multilib\]/[multilib]/' \
         -e 's|^[[:space:]]*#Include = /etc/pacman.d/mirrorlist|Include = /etc/pacman.d/mirrorlist|' \
         "$PACCONF" || true
fi

echo "[*] Refreshing databases (inc. multilib) and aligning system..."
pacman -Syuu --noconfirm

# ---------------- kernel headers ----------------
KVER="$(uname -r)"
PKGBASE_FILE="/usr/lib/modules/$KVER/pkgbase"
[[ -f "$PKGBASE_FILE" ]] || { echo "Missing $PKGBASE_FILE; kernel install looks odd." >&2; exit 1; }
KHDRS="$(<"$PKGBASE_FILE")-headers"
pacman -S --needed --noconfirm "$KHDRS"

# ---------------- packages ----------------
echo "[*] Installing graphics stack (Intel default + NVIDIA offload)..."
pacman -S --needed --noconfirm \
  nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland nvidia-prime \
  mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver \
  vulkan-icd-loader lib32-vulkan-icd-loader mesa-demos vulkan-tools \
  xorg-xwayland

# Remove legacy Xorg DDX drivers (unneeded for Wayland/GLVND)
for p in xf86-video-intel xf86-video-nouveau; do
  pacman -Qq "$p" &>/dev/null && pacman -Rns --noconfirm "$p" || true
done

# ---------------- modprobe & initramfs ----------------
echo "[*] Blacklisting nouveau and enabling nvidia_drm modeset..."
mkdir -p /etc/modprobe.d
cat >/etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
echo 'options nvidia_drm modeset=1' >/etc/modprobe.d/nvidia.conf

# Carefully ensure MODULES & HOOKS in mkinitcpio (keep your other settings)
MKCONF="/etc/mkinitcpio.conf"
cp -a "$MKCONF" "${MKCONF}.bak.$(date +%F-%H%M)"

# 1) MODULES: merge desired (i915 first) with existing
declare -a DESIRED_MODS=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
if grep -q '^[[:space:]]*MODULES=' "$MKCONF"; then
  mapfile -t CURR < <(sed -n 's/^[[:space:]]*MODULES=(\(.*\))$/\1/p' "$MKCONF")
  # shellcheck disable=SC2206
  CURR_ARR=(${CURR[*]})
  NEW=("${DESIRED_MODS[@]}")
  for m in "${CURR_ARR[@]}"; do
    [[ " ${NEW[*]} " =~ " $m " ]] || NEW+=("$m")
  done
  # de-dup preserving first occurrences
  DEDUP=()
  for m in "${NEW[@]}"; do
    [[ " ${DEDUP[*]} " =~ " $m " ]] || DEDUP+=("$m")
  done
  sed -i "s|^[[:space:]]*MODULES=.*$|MODULES=(${DEDUP[*]})|" "$MKCONF"
else
  echo "MODULES=(${DESIRED_MODS[*]})" >> "$MKCONF"
fi

# 2) HOOKS: ensure present; add sane default if missing; ensure 'kms' exists
if ! grep -q '^[[:space:]]*HOOKS=' "$MKCONF"; then
  cat >>"$MKCONF" <<'EOF'
# Standard udev-based hooks with early KMS (recommended for Wayland/NVIDIA)
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
EOF
else
  # If kms not present as a standalone token, append it at the end
  if ! grep -Eq '^[[:space:]]*HOOKS=.*([[:space:]]|^)kms([[:space:]]|[)])' "$MKCONF"; then
    sed -i 's/^\([[:space:]]*HOOKS=(.*\))$/\1 kms)/' "$MKCONF" || \
    sed -i 's/^\([[:space:]]*HOOKS=(.*\)\)$/\1 kms)/' "$MKCONF"
    # fallback path above in case of weird spacing
  fi
fi

echo "[*] Rebuilding initramfs..."
mkinitcpio -P

# ---------------- Hyprland env (for invoking user) ----------------
echo "[*] Writing Hyprland env for hybrid graphics to ${USER_HOME}/.config/hypr/hyprland.conf ..."
sudo -u "$USR" mkdir -p "${USER_HOME}/.config/hypr"
HYPR="${USER_HOME}/.config/hypr/hyprland.conf"
sudo -u "$USR" touch "$HYPR"

# Detect DRM cards (Intel first, NVIDIA second). Fall back to card0:card1.
INTEL="/dev/dri/card0"; NVIDIA="/dev/dri/card1"
if ls /dev/dri/card* >/dev/null 2>&1; then
  for c in /dev/dri/card*; do
    vp="/sys/class/drm/$(basename "$c")/device/vendor"
    [[ -f "$vp" ]] || continue
    v="$(<"$vp")"
    [[ "$v" == "0x8086" ]] && INTEL="$c"
    [[ "$v" == "0x10de" ]] && NVIDIA="$c"
  done
fi

add_or_set() {
  local key="$1" val="$2"
  if sudo -u "$USR" grep -qE "^[[:space:]]*env[[:space:]]*=[[:space:]]*$key," "$HYPR"; then
    sudo -u "$USR" sed -i -E "s|^[[:space:]]*env[[:space:]]*=[[:space:]]*$key,.*$|env = $key,$val|" "$HYPR"
  else
    echo "env = $key,$val" | sudo -u "$USR" tee -a "$HYPR" >/dev/null
  fi
}

# Hyprland (2025 docs): AQ_DRM_DEVICES for GPU order; NVIDIA envs for GL/VA interop.
add_or_set "AQ_DRM_DEVICES" "${INTEL}:${NVIDIA}"     # iGPU scanout, dGPU secondary
add_or_set "__GLX_VENDOR_LIBRARY_NAME" "nvidia"      # Xwayland GLVND routing
# OPTIONAL: NVDEC/VA-API through NVIDIA; comment out if you prefer Intel VA by default
add_or_set "LIBVA_DRIVER_NAME" "nvidia"
# QoL for Electron/Chromium on Wayland
add_or_set "ELECTRON_OZONE_PLATFORM_HINT" "auto"

# ---------------- final info ----------------
cat <<EOF

[✔] Done. Reboot to load the new driver + initramfs.

Post-reboot checks (in Hyprland):
  glxinfo -B | grep 'OpenGL renderer'              # Intel by default
  prime-run glxinfo -B | grep 'OpenGL renderer'    # GeForce GTX 1650 Ti
  prime-run vulkaninfo --summary | head -n 60
  nvidia-smi   # run while an offloaded app is active

If anything goes sideways: backup of mkinitcpio is at ${MKCONF}.bak.*.
EOF
