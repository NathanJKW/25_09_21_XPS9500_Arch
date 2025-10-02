#!/usr/bin/env bash
set -euo pipefail
HOST="$(uname -n || echo unknown)"
STAMP="$(date -Iseconds)"
OUT="arch_core_${HOST}_${STAMP}.md"

export LC_ALL=C

have(){ command -v "$1" >/dev/null 2>&1; }
if command -v sudo >/dev/null; then sudo -v 2>/dev/null || true; fi

p(){ printf "%s\n" "$*" >>"$OUT"; }
sec(){ p ""; p "# $1"; p ""; }
sub(){ p ""; p "## $1"; p ""; }

# ✅ redirect the WHOLE group into the file
cap(){
  local title="$1"; shift
  sub "$title"
  p '```'
  { "$@" 2>&1 || true; } >>"$OUT"
  p '```'
}

p "# Arch Core Diagnostic"
p "_Generated: $STAMP on $HOST"
p "> Minimal set: OS/kernel, CPU/RAM, devices, network, storage, key logs."

sec "System"
cap "OS Release" cat /etc/os-release
cap "Kernel/Arch" uname -a
cap "Kernel cmdline" cat /proc/cmdline
cap "CPU (lscpu)" lscpu
cap "Memory (free -h)" free -h

sec "Hardware snapshot"
cap "PCI (short VGA/3D/Net/Storage)" bash -lc 'if command -v lspci; then lspci -nnk | grep -E "VGA|3D|Display|Network|Ethernet|Wireless|Storage|SATA|NVMe" -A3; else echo "pciutils not installed"; fi'
cap "USB (short)" bash -lc 'if command -v lsusb; then lsusb; else echo "usbutils not installed"; fi'
cap "Loaded modules (lsmod head)" bash -lc 'lsmod | head -n 80'

sec "Graphics quick"
cap "DRI nodes" bash -lc 'ls -l /dev/dri 2>/dev/null || true'
cap "glxinfo -B" bash -lc 'command -v glxinfo >/dev/null && glxinfo -B || echo "mesa-demos not installed"'
cap "vulkaninfo --summary" bash -lc 'command -v vulkaninfo >/dev/null && vulkaninfo --summary || echo "vulkan-tools not installed"'
cap "nvidia-smi" bash -lc 'command -v nvidia-smi >/dev/null && nvidia-smi || echo "nvidia-smi not present"'

sec "Network"
cap "IP addresses" ip -d addr
cap "Routes" ip route
cap "DNS status" bash -lc 'command -v resolvectl >/dev/null && resolvectl status || cat /etc/resolv.conf'

sec "Storage"
cap "Block devices" lsblk -e7 -o NAME,RM,SIZE,RO,TYPE,MOUNTPOINTS,FSTYPE,FSAVAIL,FSUSE%
cap "Filesystems" findmnt -A
cap "SMART quick" bash -lc '
if command -v smartctl >/dev/null; then
  for d in /dev/sd? /dev/nvme?n? 2>/dev/null; do [ -e "$d" ] && { echo "== $d =="; sudo smartctl -H "$d" || true; }; done
else echo "smartmontools not installed"; fi'

sec "Services & Errors"
cap "Failed units" systemctl --failed
cap "Boot errors (this boot)" sudo journalctl -b -p 3 --no-pager
cap "Boot warnings (this boot)" sudo journalctl -b -p 4 --no-pager

p ""; p "---"; p "_End of core report_"
echo "✅ Wrote $OUT"
