#!/usr/bin/env bash
# sys_prompt.sh — generate a concise, ChatGPT-friendly summary of this Linux system

set -euo pipefail

# Helpers
has() { command -v "$1" >/dev/null 2>&1; }
line() { printf '%*s\n' "${1:-60}" '' | tr ' ' '-'; }
kv() { printf "%s: %s\n" "$1" "${2:-N/A}"; }
run() { # run if available; trim trailing spaces/newlines
  if has "$1"; then shift; "$@" 2>/dev/null | sed -e 's/[[:space:]]*$//' || true
  fi
}

header() { echo; line 80; echo "# $*"; line 80; }

# Basic
HOSTNAME="$(hostname 2>/dev/null || echo N/A)"
KERNEL="$(uname -r 2>/dev/null || echo N/A)"
UNAME="$(uname -a 2>/dev/null || echo N/A)"
UPTIME="$(awk -v s="$(cut -d. -f1 /proc/uptime 2>/dev/null)" 'BEGIN{
d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60);
printf("%dd %dh %dm", d,h,m)}' 2>/dev/null || echo N/A)"

# OS info
if [ -r /etc/os-release ]; then
  . /etc/os-release
  OS_NAME="${PRETTY_NAME:-$NAME $VERSION_ID}"
else
  OS_NAME="$(run lsb_release lsb_release -d | cut -f2)"
fi

# CPU
CPU_MODEL="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')"
CPU_CORES="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo N/A)"
CPU_ARCH="$(uname -m 2>/dev/null || echo N/A)"
CPU_FLAGS="$(grep -m1 ^flags /proc/cpuinfo 2>/dev/null | cut -d: -f2- | tr ' ' ' ' | sed -e 's/^ //' )"

# Memory
MEM_TOTAL="$(grep -m1 MemTotal /proc/meminfo 2>/dev/null | awk '{printf "%.1f GiB",$2/1024/1024}')"
MEM_FREE="$(free -h 2>/dev/null | awk '/Mem:/ {print $7" (available)"}')"

# Disks & FS
DISK_LAYOUT="$(lsblk -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT -r 2>/dev/null | sed -e 's/^/  /')"
DISK_USAGE="$(df -hT -x tmpfs -x devtmpfs 2>/dev/null | sed -e 's/^/  /')"

# GPU / Graphics
GPU_LSPCI="$(lspci 2>/dev/null | grep -E 'VGA|3D|Display' || true)"
GPU_RENDERER="$(run glxinfo glxinfo | awk -F': ' '/OpenGL renderer string/ {print $2; exit}')"
DISPLAY_SERVER="$(printf '%s' "${XDG_SESSION_TYPE:-$(loginctl show-session $XDG_SESSION_ID 2>/dev/null | awk -F= '/Type=/{print $2}')}")"

# Network
IP_BRIEF="$(run ip ip -br a | sed -e 's/^/  /')"
DNS_RESOLV="$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | paste -sd, -)"
DEFAULT_ROUTE="$(run ip ip route | awk '/default/ {print $3; exit}')"

# Userspace / DE-WM / Shell
SHELL_NAME="${SHELL:-$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)}"
DESKTOP="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-$(echo "${GDMSESSION:-}" )}}"
WINDOW_MANAGER="$(run wmctrl wmctrl -m | awk -F': ' '/Name:/ {print $2}')"
if [ -z "${WINDOW_MANAGER:-}" ]; then
  WINDOW_MANAGER="$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | awk '{print $5}' | xargs -r -I{} xprop -id {} _NET_WM_NAME 2>/dev/null | awk -F\" '{print $2}' )"
fi

# Kernel modules of interest (graphics/network)
KMODS="$(run lsmod lsmod | awk 'NR==1 || /(^i915|^amdgpu|^nouveau|^nvidia|^iwlwifi|^ath9k|^rtw|^r8169|^e1000|^tg3|^ax2|^mt76)/' 2>/dev/null | sed -e 's/^/  /')"

# Package management (Arch-aware with fallbacks)
PKG_MGR=""
PKG_COUNT=""
PKG_EXPLICIT=""
PKG_AUR=""
if has pacman; then
  PKG_MGR="pacman"
  PKG_COUNT="$(pacman -Q 2>/dev/null | wc -l | tr -d ' ')"
  PKG_EXPLICIT="$(pacman -Qe 2>/dev/null | head -n 60 | awk '{print $1}' | paste -sd' ' -)"
  [ "$(pacman -Qe 2>/dev/null | wc -l)" -gt 60 ] && PKG_EXPLICIT="$PKG_EXPLICIT …"
  PKG_AUR="$(pacman -Qm 2>/dev/null | head -n 40 | awk '{print $1}' | paste -sd' ' -)"
  [ "$(pacman -Qm 2>/dev/null | wc -l)" -gt 40 ] && PKG_AUR="$PKG_AUR …"
elif has dpkg; then
  PKG_MGR="dpkg/apt"
  PKG_COUNT="$(dpkg -l 2>/dev/null | awk '/^ii/ {c++} END{print c+0}')"
elif has rpm; then
  PKG_MGR="rpm"
  PKG_COUNT="$(rpm -qa 2>/dev/null | wc -l | tr -d ' ')"
fi

# Kernel params (useful for GPU, virtualization, etc.)
KCMDLINE="$(cat /proc/cmdline 2>/dev/null | sed -e 's/initramfs\.img[^ ]*//g')"

# Virtualization / Firmware
VIRT="$(systemd-detect-virt 2>/dev/null || true)"
FW="$(run fwupdmgr fwupdmgr get-devices | awk -F': ' '/^├─|^└─/ {print $2}' | paste -sd', ' -)"

# Audio
AUDIO="$(run pactl pactl info | awk -F': ' '/Server Name|Default Sink|Default Source/ {print $1": "$2}')"
if [ -z "$AUDIO" ]; then
  AUDIO="$(run aplay aplay -l | sed -e 's/^/  /')"
fi

# Compose Output
header "SYSTEM CONTEXT (for ChatGPT)"
kv "Hostname" "$HOSTNAME"
kv "OS" "$OS_NAME"
kv "Kernel" "$KERNEL"
kv "Uptime" "$UPTIME"
kv "Architecture" "$CPU_ARCH"
kv "Virtualization" "${VIRT:-N/A}"

header "CPU"
kv "Model" "${CPU_MODEL:-N/A}"
kv "Cores (online)" "${CPU_CORES:-N/A}"
if [ -n "${CPU_FLAGS:-}" ]; then
  kv "Key flags" "$(echo "$CPU_FLAGS" | grep -oE '(avx512|avx2|avx|sse4_2|sse4_1|aes|vmx|svm)' | sort -u | paste -sd',' -)"
fi

header "MEMORY"
kv "Total" "${MEM_TOTAL:-N/A}"
kv "Available" "${MEM_FREE:-N/A}"

header "GRAPHICS"
kv "GPU (lspci)" "${GPU_LSPCI:-N/A}"
kv "Renderer (OpenGL)" "${GPU_RENDERER:-N/A}"
kv "Display Server" "${DISPLAY_SERVER:-N/A}"
echo "Kernel Modules:"
echo "${KMODS:-  N/A}"

header "DISKS"
echo "Block Devices:"
echo "${DISK_LAYOUT:-  N/A}"
echo
echo "Mounted Filesystems:"
echo "${DISK_USAGE:-  N/A}"

header "NETWORK"
kv "Default Gateway" "${DEFAULT_ROUTE:-N/A}"
kv "DNS" "${DNS_RESOLV:-N/A}"
echo "Interfaces (brief):"
echo "${IP_BRIEF:-  N/A}"

header "USER ENVIRONMENT"
kv "Shell" "${SHELL_NAME:-N/A}"
kv "Desktop Environment" "${DESKTOP:-N/A}"
kv "Window Manager" "${WINDOW_MANAGER:-N/A}"

header "AUDIO"
if [ -n "${AUDIO:-}" ]; then
  echo "$AUDIO"
else
  echo "  N/A"
fi

header "PACKAGES"
kv "Manager" "${PKG_MGR:-N/A}"
kv "Installed Count" "${PKG_COUNT:-N/A}"
if [ "$PKG_MGR" = "pacman" ]; then
  kv "Explicit (sample)" "${PKG_EXPLICIT:-N/A}"
  kv "AUR/Foreign (sample)" "${PKG_AUR:-N/A}"
fi

header "KERNEL CMDLINE (trimmed)"
echo "  $KCMDLINE"

echo
line 80
echo "# NOTES"
echo "- Lists are truncated to keep this summary compact. If you need full lists, let me know."
echo "- Safe, read-only commands were used; no system changes were made."
line 80
