#!/usr/bin/env bash
# Arch Linux single-file diagnostic (Markdown)
# Safe (read-only) but sudo-friendly for deeper detail.
# Produces: arch_probe_<host>_<timestamp>.md

set -euo pipefail

HOST="$(hostname -s || echo unknown)"
STAMP="$(date -Iseconds)"
OUTFILE="arch_probe_${HOST}_${STAMP}.md"

have() { command -v "$1" >/dev/null 2>&1; }

# Ask for sudo once up-front (don’t fail if not available)
if have sudo; then
  sudo -v 2>/dev/null || true
fi

print() { printf "%s\n" "$*" >> "$OUTFILE"; }

section()    { print ""; print "# $1"; print ""; }
subsection() { print ""; print "## $1"; print ""; }
code_start() { print '```'; }
code_end()   { print '```'; }

capture() {
  # capture "Title" [sudo] cmd...
  local title="$1"; shift
  local use_sudo=""
  if [[ "${1:-}" == "sudo" ]]; then use_sudo="yes"; shift; fi
  subsection "$title"
  print "\`\`\`"
  if [[ -n "$use_sudo" ]] && have sudo; then
    sudo --preserve-env=PATH "$@" 2>&1 || true
  else
    "$@" 2>&1 || true
  fi >> "$OUTFILE"
  print "\`\`\`"
}

capture_sh() {
  # capture a small shell snippet without failing the whole script
  local title="$1"; shift
  subsection "$title"
  print "\`\`\`"
  bash -c "$*" 2>&1 || true >> "$OUTFILE"
  print "\`\`\`"
}

# --- Header -----------------------------------------------------------------
print "# Arch Linux Diagnostic Report"
print "_Generated: ${STAMP} on ${HOST}_"
print
print "> ⚠️ This report may include hostnames, usernames, IP/MACs, device serials, and package lists."

# --- 0. Meta ----------------------------------------------------------------
section "Meta"
capture "User & Kernel" bash -lc 'echo "user=$USER"; echo "whoami=$(whoami)"; uname -a'
capture "OS Release" cat /etc/os-release
capture "Kernel cmdline" cat /proc/cmdline
capture "Environment (sorted)" env | LC_ALL=C sort

# --- 1. System --------------------------------------------------------------
section "System"
capture "CPU (lscpu)" lscpu
capture "Memory (free -h)" free -h
capture "Mem/Swap (/proc/meminfo, head)" bash -lc 'grep -E "^(Mem|Swap)" /proc/meminfo || head -n 50 /proc/meminfo'
capture "Boot Mode (UEFI presence)" bash -lc 'if [ -d /sys/firmware/efi ]; then echo "UEFI=yes"; else echo "UEFI=no (Legacy/CSM)"; fi'
capture "DMI / SMBIOS (dmidecode)" sudo dmidecode
capture "Firmware devices (fwupdmgr)" sudo fwupdmgr get-devices
capture "Available firmware updates (fwupdmgr)" sudo fwupdmgr get-updates
capture "Login sessions (loginctl)" loginctl
capture_sh "Active session details" 'sid=$(loginctl | awk "/$(whoami)/{print \$1; exit}"); loginctl show-session "$sid" -a || true'

# --- 2. Hardware ------------------------------------------------------------
section "Hardware"
capture "PCI devices (lspci -nnk)" bash -lc 'if have lspci; then lspci -nnk; else echo "pciutils not installed (pacman -S pciutils)"; fi'
capture "USB devices (lsusb -v or lsusb)" bash -lc 'if have lsusb; then lsusb -v 2>/dev/null || lsusb; else echo "usbutils not installed (pacman -S usbutils)"; fi'
capture "Kernel modules (lsmod)" lsmod
capture "Udev database (udevadm info -e)" bash -lc 'if have udevadm; then udevadm info -e; else echo "udevadm not available"; fi'
capture "ACPI (acpi -V)" bash -lc 'if have acpi; then acpi -V; else echo "acpi not installed (pacman -S acpi)"; fi'
capture "Sensors (lm_sensors)" bash -lc 'if have sensors; then sensors; else echo "lm_sensors not installed (pacman -S lm_sensors)"; fi'

# --- 3. Graphics ------------------------------------------------------------
section "Graphics"
capture "Installed GPU/graphics packages (pacman -Qs)" bash -lc 'pacman -Qs "mesa|vulkan|nvidia|intel|amdgpu|radeon|opencl|wayland|wlroots" || true'
capture "DRI nodes" bash -lc 'ls -l /dev/dri 2>/dev/null || true'
capture "glxinfo -B" bash -lc 'if have glxinfo; then glxinfo -B; else echo "mesa-demos not installed (pacman -S mesa-demos)"; fi'
capture "vulkaninfo --summary" bash -lc 'if have vulkaninfo; then vulkaninfo --summary; else echo "vulkan-tools not installed (pacman -S vulkan-tools)"; fi'
capture "xrandr --query (X11)" bash -lc 'if have xrandr; then xrandr --query || true; else echo "xrandr not installed (often not used under Wayland)"; fi'
capture "NVIDIA (nvidia-smi)" bash -lc 'if have nvidia-smi; then nvidia-smi; else echo "nvidia-smi not present"; fi'
capture "Xorg log (last 400 lines)" sudo bash -lc 'for f in /var/log/Xorg.0.log ~/.local/share/xorg/Xorg.0.log; do [ -r "$f" ] && { echo "=== $f ==="; tail -n 400 "$f"; }; done || echo "No Xorg log (likely Wayland)"'

# --- 4. Network -------------------------------------------------------------
section "Network"
capture "IP addresses (ip -d addr)" ip -d addr
capture "Routes (ip route)" ip route
capture "DNS (resolvectl or resolv.conf)" bash -lc 'if have resolvectl; then resolvectl status; else cat /etc/resolv.conf; fi'
capture "nsswitch.conf" sudo cat /etc/nsswitch.conf
capture "NetworkManager (nmcli)" bash -lc 'if have nmcli; then nmcli general status; nmcli device status; nmcli -g IP4.DNS device show 2>/dev/null || true; else echo "NetworkManager not present"; fi'
capture "Wi-Fi (iw dev)" bash -lc 'if have iw; then iw dev; else echo "iw not installed (pacman -S iw)"; fi'
capture "Per-interface details (ethtool)" bash -lc '
if have ethtool; then
  for i in $(ls /sys/class/net | grep -v lo); do
    echo "### $i"
    ethtool -i "$i" || true
    ethtool "$i" 2>/dev/null || true
    ethtool -k "$i" 2>/dev/null || true
    echo
  done
else
  echo "ethtool not installed (pacman -S ethtool)"
fi'

# --- 5. Storage -------------------------------------------------------------
section "Storage"
capture "Block devices (lsblk)" lsblk -e7 -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS,FSTYPE,FSAVAIL,FSUSE%
capture "Filesystems (findmnt -A)" findmnt -A
capture "UUIDs/labels (blkid)" sudo blkid
capture "Mounted (mount)" mount
capture "BTRFS/ZFS mdadm status (best effort)" bash -lc '
for cmd in btrfs zpool zfs mdadm; do
  if have "$cmd"; then
    case "$cmd" in
      btrfs) btrfs filesystem show 2>/dev/null || true; btrfs subvolume list -t / 2>/dev/null || true;;
      zpool) zpool status 2>/dev/null || true;;
      zfs)   zfs list 2>/dev/null || true;;
      mdadm) sudo mdadm --detail --scan 2>/dev/null || true; sudo mdadm --detail /dev/md/* 2>/dev/null || true;;
    esac
  fi
done'
capture "NVMe list" bash -lc 'if have nvme; then nvme list; else echo "nvme-cli not installed (pacman -S nvme-cli)"; fi'
capture "SMART (full health all disks)" sudo bash -lc '
if have smartctl; then
  for d in /dev/sd? /dev/nvme?n? 2>/dev/null; do
    [ -e "$d" ] || continue
    echo "==== $d ===="
    smartctl -a "$d" 2>&1 || true
    echo
  done
else
  echo "smartmontools not installed (pacman -S smartmontools)"
fi'

# --- 6. Packages & Repos ----------------------------------------------------
section "Packages & Repositories"
capture "All installed packages (pacman -Q)" pacman -Q
capture "Explicitly installed (pacman -Qe)" pacman -Qe
capture "Foreign/AUR packages (pacman -Qm)" pacman -Qm || true
capture "Upgradeable (pacman -Qu)" bash -lc 'pacman -Qu || true'
capture "Kernel packages" bash -lc 'pacman -Q | grep -E "^linux(-lts|-zen|-hardened)?\\s" || true'
capture "Mirrors (active only)" bash -lc 'grep -v "^[[:space:]]*#" /etc/pacman.d/mirrorlist || true'
capture "Keyring/GnuPG" bash -lc 'pacman -Q archlinux-keyring gnupg 2>/dev/null || true'
capture "Enabled pacman.conf" sudo cat /etc/pacman.conf

# --- 7. Services & Boot -----------------------------------------------------
section "Services & Boot"
capture "Failed units" systemctl --failed
capture "Running services" bash -lc 'systemctl list-units --type=service --state=running --no-pager'
capture "Enabled/disabled unit files" bash -lc 'systemctl list-unit-files --type=service --no-pager'
capture "Timers" bash -lc 'systemctl list-timers --all --no-pager'
capture "Boot performance (blame)" systemd-analyze blame
capture "Boot critical chain" systemd-analyze critical-chain
capture "Initrd generators (dracut/mkinitcpio)" bash -lc '
if have dracut; then dracut --print-cmdline 2>/dev/null || true; fi
if have mkinitcpio; then mkinitcpio -V; grep -v "^[[:space:]]*#" /etc/mkinitcpio.conf 2>/dev/null || true; fi'

# --- 8. Logs ---------------------------------------------------------------
section "Logs"
capture "Journal (this boot) - errors" sudo journalctl -b -p 3 --no-pager
capture "Journal (this boot) - warnings" sudo journalctl -b -p 4 --no-pager
capture "Journal (previous boot) - errors" sudo bash -lc 'journalctl -b -1 -p 3 --no-pager || true'
capture "Kernel ring (dmesg err/warn)" bash -lc 'dmesg --level=emerg,alert,crit,err,warn 2>/dev/null || dmesg 2>/dev/null || true'
capture "Full boot journal (this boot)" sudo journalctl -b --no-pager

# --- 9. Security / Misc -----------------------------------------------------
section "Security / Misc"
capture "SELinux/AppArmor/LSM & seccomp flags" bash -lc '
grep -H . /sys/module/*/parameters/enabled 2>/dev/null | grep -Ei "(apparmor|selinux)" || true
grep -E "Seccomp|NoNewPrivs|CapEff|CapBnd" /proc/$$/status || true'
capture "Sysctl deltas" sudo sysctl -a 2>/dev/null || true
capture "Open file limits" bash -lc 'ulimit -a'

# --- Epilogue ---------------------------------------------------------------
print ""
print "---"
print "_End of report_"
print ""

echo "✅ Report written to: $OUTFILE"
