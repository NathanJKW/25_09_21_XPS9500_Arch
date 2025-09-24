<File Tree>
00 Archive/scripts/audio.sh
00 Archive/scripts/fonts.sh
00 Archive/scripts/sddminstall.sh
00 Archive/scripts/symlinker.sh
00 Archive/scripts/system_context.sh
main.py
modules/000_core/module.py
modules/010_security/module.py
modules/020_system_defaults/module.py
modules/030_backup/module.py
modules/040_fonts/module.py
modules/100_firmware/module.py
modules/110__power/module.py
modules/120_input/module.py
modules/130_gpu/module.py
modules/140_audio/module.py
modules/150_network/module.py
modules/160_devtools/module.py
modules/200_display-server/module.py
modules/210_login_manager/module.py
modules/220_window_manager/module.py
modules/230_panels-bars/module.py
modules/240_themeing/module.py
utils/module_loader.py
utils/pacman.py
utils/sudo_session.py
utils/symlinker.py
utils/yay.py

<Contents of included files>

--- 00 Archive/scripts/audio.sh ---
#!/usr/bin/env bash
# setup-audio.sh - simple PipeWire audio setup for Arch Linux

set -e

echo "[*] Updating system..."
sudo pacman -Syu --noconfirm

echo "[*] Installing PipeWire stack..."
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol

if pacman -Qq pulseaudio &>/dev/null; then
  echo "[*] Removing PulseAudio (conflicts with PipeWire)..."
  sudo pacman -Rns --noconfirm pulseaudio
fi

echo "[*] Enabling PipeWire user services..."
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

echo "[*] Verifying setup..."
systemctl --user status pipewire.service --no-pager -l | grep "Active:"
systemctl --user status pipewire-pulse.service --no-pager -l | grep "Active:"
systemctl --user status wireplumber.service --no-pager -l | grep "Active:"

echo
echo "[*] Listing audio devices (ALSA):"
aplay -l || true

echo
echo "[*] PipeWire info:"
pactl info || true

echo
echo "[*] Done! Use 'pavucontrol' to pick your output device (HDMI, speakers, etc)."


--- 00 Archive/scripts/fonts.sh ---
#!/usr/bin/env bash
#
# setup-jetbrains-nerd-font.sh
#
# Install JetBrainsMono Nerd Font system-wide and set it as the default monospace font.
#

set -euo pipefail

FONT_PKG="ttf-jetbrains-mono-nerd"
FONTCONF="/etc/fonts/local.conf"

echo "[*] Installing JetBrainsMono Nerd Font..."
sudo pacman -S --needed --noconfirm "$FONT_PKG"

echo "[*] Refreshing font cache..."
sudo fc-cache -f -v

echo "[*] Detecting JetBrains Nerd Font family name..."
FAMILY=$(fc-list | grep -m1 "JetBrainsMono Nerd Font" | sed -E 's/.*: "([^"]+)".*/\1/')

if [[ -z "$FAMILY" ]]; then
  echo "[!] Could not detect JetBrainsMono Nerd Font in fc-list!"
  exit 1
fi

echo "[*] Detected family: $FAMILY"

echo "[*] Writing fontconfig rule to $FONTCONF..."
sudo tee "$FONTCONF" >/dev/null <<EOF
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <!-- Default monospace font -->
  <match target="pattern">
    <test qual="any" name="family">
      <string>monospace</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FAMILY</string>
    </edit>
  </match>
</fontconfig>
EOF

echo "[*] Rebuilding font cache..."
sudo fc-cache -f -v

echo "[*] Verifying default monospace font..."
fc-match monospace

echo "[✓] JetBrainsMono Nerd Font is now the default monospace font system-wide."


--- 00 Archive/scripts/sddminstall.sh ---
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install_sddm.sh  v1.0
#
# Minimal installer for SDDM on Arch Linux.
#
# - Installs the `sddm` package
# - Disables LightDM if present
# - Enables SDDM service
#
# Intended for use on a brand new minimal install where checks are unnecessary.
# -----------------------------------------------------------------------------

set -euo pipefail

# Install SDDM
sudo pacman -S --noconfirm --needed sddm

# Enable SDDM
sudo systemctl enable sddm.service --now

echo "✓ SDDM installed and enabled."


--- 00 Archive/scripts/symlinker.sh ---
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# bootstrap_symlinks.sh  v1.5
#
# Create symlinks from your dotfiles repo into the correct locations.
# - Creates parent directories as needed
# - Backs up existing targets (user files to ~/.dotfiles_backup/<ts>/…,
#   system files to "<dest>.bak.<ts>" alongside the file)
# - Automatically uses sudo for non-writable/system paths (e.g. /etc/*)
#
# Repo root (edit if you move the repo):
#   REPO="/home/nathan/repos/25_09_21_XPS9500_Arch"
#
# What it links (adjust to taste):
#   $REPO/i3/config                      ->  ~/.config/i3/config
#   $REPO/git/gitconfig                  ->  ~/.gitconfig
#   $REPO/X11/xorg.conf.d/90-libinput.conf  ->  ~/.config/xorg.conf.d/90-libinput.conf
#   (optional system path)
#   $REPO/X11/xorg.conf.d/90-libinput.conf  ->  /etc/X11/xorg.conf.d/90-libinput.conf
# -----------------------------------------------------------------------------

set -euo pipefail

REPO="/home/nathan/repos/25_09_21_XPS9500_Arch"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="${HOME}/.dotfiles_backup/${timestamp}"

# ----- helpers ---------------------------------------------------------------

need_sudo() {
  # return 0 if we need sudo to write the DEST's parent dir
  local dest="$1"
  local parent; parent="$(dirname "$dest")"
  [ -w "$parent" ] || { [ -e "$parent" ] && [ ! -w "$parent" ]; } && return 0
  # parent not existing? test writability of its nearest existing ancestor
  while [ ! -d "$parent" ]; do parent="$(dirname "$parent")"; done
  [ -w "$parent" ] || return 0
  return 1
}

ensure_parent() {
  local dest="$1"
  local parent; parent="$(dirname "$dest")"
  if need_sudo "$dest"; then
    sudo mkdir -p "$parent"
  else
    mkdir -p "$parent"
  fi
}

backup_target() {
  # create a backup of existing dest (file/dir/link)
  local dest="$1"
  if need_sudo "$dest"; then
    local bk="${dest}.bak.${timestamp}"
    echo "↪ backing up (root): $dest -> $bk"
    sudo cp -a --no-preserve=ownership "$dest" "$bk" 2>/dev/null || sudo mv -f "$dest" "$bk"
  else
    local rel="${dest#${HOME}/}"
    local bk="${backup_root}/${rel}"
    echo "↪ backing up: $dest -> $bk"
    mkdir -p "$(dirname "$bk")"
    mv -f "$dest" "$bk"
  fi
}

same_symlink_target() {
  # returns 0 if dest is a symlink pointing to src
  local src="$1" dest="$2"
  [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]
}

link_one() {
  local src="$1" dest="$2"

  # sanity
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    echo "⚠  missing source: $src"
    return 0
  fi

  ensure_parent "$dest"

  # if exists and not already the same link, back it up
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if same_symlink_target "$src" "$dest"; then
      echo "✓ already linked: $dest → $(readlink -f "$dest")"
      return 0
    fi
    backup_target "$dest"
  fi

  if need_sudo "$dest"; then
    echo "→ linking (root): $dest -> $src"
    sudo ln -sfn "$src" "$dest"
  else
    echo "→ linking: $dest -> $src"
    ln -sfn "$src" "$dest"
  fi
}

# ----- user-scope links (no sudo) -------------------------------------------

link_one "$REPO/i3/config"                          "${HOME}/.config/i3/config"
link_one "$REPO/git/gitconfig"                      "${HOME}/.gitconfig"
link_one "$REPO/X11/xorg.conf.d/90-libinput.conf"   "/etc/X11/xorg.conf.d/90-libinput.conf"
link_one "$REPO/etc/sddm.conf.d/00-autologin.conf"  "/etc/sddm.conf.d/00-autologin.conf"
link_one "$REPO/etc/sddm.conf.d/10-theme.conf"     "/etc/sddm.conf.d/10-theme.conf"

# Uncomment if/when you want these managed too:
# link_one "$REPO/X11/xprofile"                      "${HOME}/.xprofile"
# link_one "$REPO/shell/bashrc"                       "${HOME}/.bashrc"
# link_one "$REPO/shell/zshrc"                        "${HOME}/.zshrc"

# ----- wrap up ---------------------------------------------------------------

# Show where user backups (if any) landed
[ -d "$backup_root" ] && echo "User backups (if any) are in: $backup_root"
echo "Done."


--- 00 Archive/scripts/system_context.sh ---
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


--- main.py ---
# main.py
#!/usr/bin/env python3
"""
Dotfiles / System Provisioning Entry Point
Version: 1.0.0

What the module does
--------------------
This is the main entry point for running all provisioning "modules" located
under the ./modules directory. It:

1) Starts a sudo keep-alive session (without keeping your password in memory).
2) Discovers and validates modules by their numeric order (e.g., 00_core, 10_foo).
3) Executes each module's `install(run)` function in ascending order.
4) Cleanly tears down the sudo session.

Behavior & Safety
-----------------
- Idempotent by design: individual modules are expected to use safe flags
  (e.g., pacman/yay `--needed`) and/or create backups before overwriting.
- Robust error handling: execution prints clear shell-like actions and
  returns a success/failure code (printed), without unhandled crashes.
"""

from __future__ import annotations

from utils.sudo_session import start_sudo_session
from utils.module_loader import run_all


def main() -> bool:
    """
    Orchestrate the provisioning run.

    Returns:
        True if all modules ran successfully, False otherwise.
    """
    # Start the sudo session (asks for your password once, then keeps it alive).
    run, close = start_sudo_session()

    try:
        # Run all discovered modules. The loader handles duplicate order detection
        # and will abort early in that case.
        success = run_all(run)
        print(f"\n✅ Overall result: {'SUCCESS' if success else 'FAILURE'}")
        return success
    except Exception as exc:
        # Catch-all to ensure we don't crash without context.
        print(f"ERROR: Unexpected exception in main(): {exc}")
        return False
    finally:
        # Always close the sudo session to clear timestamps.
        close()


if __name__ == "__main__":
    # Running as a script.
    ok = main()
    # Exit code mirrors success/failure so this can be scripted.
    import sys
    sys.exit(0 if ok else 1)


--- modules/000_core/module.py ---
# modules/00_core/module.py
#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from typing import Callable
import shutil
import subprocess
import textwrap

from utils.pacman import install_packages

UK_EU_COUNTRIES = ["United Kingdom", "Ireland", "Netherlands", "Germany", "France", "Belgium", "Denmark"]

def _print(msg: str) -> None:
    print(msg)

def _cmd_as_user(cmd: list[str]) -> subprocess.CompletedProcess:
    _print(f"$ {' '.join(cmd)}")
    # Stream output (no capture) so you can see makepkg progress, etc.
    return subprocess.run(cmd, check=False, text=True)

def _enable_timesyncd(run: Callable) -> bool:
    try:
        _print("$ systemctl enable --now systemd-timesyncd.service")
        res = run(["systemctl", "enable", "--now", "systemd-timesyncd.service"], check=False)
        return True
    except Exception as exc:
        print(f"ERROR: enabling timesyncd: {exc}")
        return False

def _ensure_dir(path: Path, run: Callable) -> bool:
    _print(f"$ mkdir -p {path}")
    res = run(["mkdir", "-p", str(path)], check=False)
    return res.returncode == 0

def _tweak_pacman_conf(run: Callable) -> bool:
    try:
        # Color
        run(["bash", "-lc",
             r"grep -q '^[[:space:]]*Color' /etc/pacman.conf || "
             r"sudo sed -i 's/^#Color/Color/' /etc/pacman.conf || "
             r"echo 'Color' | sudo tee -a /etc/pacman.conf >/dev/null"], check=False)

        # ParallelDownloads = 10
        run(["bash", "-lc",
             r"if grep -q '^[[:space:]]*ParallelDownloads' /etc/pacman.conf; then "
             r"  sudo sed -i 's/^[[:space:]]*ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf; "
             r"else "
             r"  echo 'ParallelDownloads = 10' | sudo tee -a /etc/pacman.conf >/dev/null; "
             r"fi"], check=False)
        return True
    except Exception as exc:
        print(f"ERROR: tweaking pacman.conf: {exc}")
        return False

def _refresh_mirrors(run: Callable) -> bool:
    """
    Generate a mirrorlist optimized for UK/EU with sane timeouts.
    - Only HTTPS mirrors
    - Only mirrors synced within the last 12 hours
    - Keep the 15 fastest
    - Increase download-timeout so slow handshakes don't get dropped too aggressively
    """
    try:
        countries = ",".join(["United Kingdom", "Netherlands", "Germany", "France"])
        cmd = [
            "reflector",
            "--country", countries,
            "--protocol", "https",
            "--age", "12",                 # seen as 'last synced within N hours'
            "--fastest", "15",             # keep N fastest mirrors
            "--download-timeout", "20",     # avoid premature timeouts
            "--save", "/etc/pacman.d/mirrorlist",
        ]
        print("$ " + " ".join(cmd))
        res = run(cmd, check=False)  # stream output
        if res.returncode != 0:
            print("WARN: reflector failed; keeping existing mirrorlist.")
        return True
    except Exception as exc:
        print(f"ERROR: reflector: {exc}")
        return False

def _ensure_yay() -> bool:
    if shutil.which("yay"):
        _print("$ yay --version  # already installed")
        _cmd_as_user(["bash", "-lc", "yay --version || true"])
        return True
    _print("ℹ️  'yay' not found; bootstrapping yay-bin from AUR (user scope).")
    try:
        res = _cmd_as_user(["bash", "-lc", textwrap.dedent(r"""
            set -e
            work="/tmp/_aur_yay.$$"
            mkdir -p "$work"
            cd "$work"
            git clone --depth=1 https://aur.archlinux.org/yay-bin.git
            cd yay-bin
            makepkg -si --noconfirm
            rm -rf "$work"
        """)])
        return res.returncode == 0
    except Exception as exc:
        print(f"ERROR: bootstrapping yay: {exc}")
        return False

def install(run: Callable) -> bool:
    try:
        _print("▶ [00_core] Starting core bootstrap...")

        if not _ensure_dir(Path("/etc/dotfiles"), run):
            return False

        # Keyring first
        if not install_packages(["archlinux-keyring"], run):
            return False

        # Base tooling
        base_pkgs = [
            "git", "curl", "wget", "rsync",
            "vim", "nano",
            "base-devel",
            "pacman-contrib",
            "reflector",
            "openssh",
        ]
        if not install_packages(base_pkgs, run):
            return False

        _tweak_pacman_conf(run)
        _refresh_mirrors(run)

        _print("$ pacman -Syu --noconfirm")
        res_sync = run(["pacman", "-Syu", "--noconfirm"], check=False)  # streamed
        if res_sync.returncode != 0:
            print("WARN: pacman -Syu returned non-zero; continuing.")

        _enable_timesyncd(run)

        if not _ensure_yay():
            print("WARN: Could not ensure yay; AUR installs may fail in later modules.")

        _print("✔ [00_core] Core bootstrap complete.")
        return True

    except Exception as exc:
        print(f"ERROR: 00_core.install failed: {exc}")
        return False


--- modules/010_security/module.py ---
# modules/020_security/module.py
#!/usr/bin/env python3
"""
020_security (minimal baseline)
- Ensure polkit is installed (needed for GUI/system services to escalate privileges)
- Does NOT modify sudoers or sudo configuration

NOTE:
    Arch by default does not grant sudo access to the `wheel` group.
    If you ever hit a situation where your user cannot run `sudo` (scripts, SSH, tools),
    you may want to add a snippet like:

        %wheel ALL=(ALL:ALL) ALL

    in /etc/sudoers.d/10-wheel (validated with visudo).
    For now, this module deliberately skips it to avoid unexpected changes.
"""

from __future__ import annotations
from typing import Callable


def install(run: Callable) -> bool:
    """
    Ensure baseline security packages are present.
    """
    try:
        print("▶ [020_security] Starting minimal security setup…")

        # Install polkit (idempotent, safe for desktop apps needing privilege escalation)
        from utils.pacman import install_packages
        if not install_packages(["polkit"], run):
            return False

        print("✔ [020_security] Security baseline complete.")
        return True

    except Exception as exc:
        print(f"ERROR: 020_security.install failed: {exc}")
        return False


--- modules/020_system_defaults/module.py ---
#!/usr/bin/env python3
"""
020_system-defaults

Applies safe, SSD-friendly system defaults:
- journald: persistent logs with size + time caps
- sysctl: zram-leaning VM knobs + higher inotify limits for dev workflows
- logrotate: ensure installed for non-journald apps
- time sync: enable systemd-timesyncd

Re-run safe (idempotent). Uses the provided sudo runner (`run`) from start_sudo_session().
"""

from __future__ import annotations
from typing import Callable

JOURNALD_DROPIN = "/etc/systemd/journald.conf.d/10-defaults.conf"
JOURNALD_CONTENT = """# Installed by 020_system-defaults (drop-in)
[Journal]
# Persist logs across boots (falls back to /run early in boot)
Storage=persistent
Compress=yes
Seal=yes

# Bound persistent and runtime usage on SSD
SystemMaxUse=200M
SystemKeepFree=50M
RuntimeMaxUse=50M

# Cap per-file duration and overall retention window
MaxFileSec=1week
MaxRetentionSec=1month
"""

SYSCTL_FILE = "/etc/sysctl.d/99-system-defaults.conf"
SYSCTL_CONTENT = """# Installed by 020_system-defaults
# With zram swap enabled, prefer swapping to compressed memory over dropping caches too eagerly.
vm.swappiness=100
# Keep inode/dentry caches around a bit longer (default is 100)
vm.vfs_cache_pressure=50

# Larger file-watch budgets for modern IDE/build tools/sync clients
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=1024
fs.inotify.max_queued_events=32768

# NOTE: If you use zram, consider leaving zswap disabled to avoid double-compression.
# That toggle (if needed) should live in the module that sets up zram.
"""

def _write_file(path: str, content: str, run: Callable) -> bool:
    """Create parent directory and write file via tee (works with sudo -n)."""
    parent = path.rsplit("/", 1)[0]
    print(f"$ mkdir -p {parent}")
    r = run(["mkdir", "-p", parent], check=False, capture_output=True)
    if r.returncode != 0:
        if r.stdout: print(r.stdout.rstrip())
        if r.stderr: print(r.stderr.rstrip())
        return False

    print(f"$ tee {path}  # write drop-in")
    r = run(["tee", path], check=False, capture_output=True, input_text=content)
    if r.returncode != 0:
        if r.stdout: print(r.stdout.rstrip())
        if r.stderr: print(r.stderr.rstrip())
        return False
    return True

def _install_packages(pkgs: list[str], run: Callable) -> bool:
    try:
        from utils.pacman import install_packages
        return install_packages(pkgs, run)
    except Exception as exc:
        print(f"ERROR: failed to install packages {pkgs}: {exc}")
        return False

def install(run: Callable) -> bool:
    try:
        print("▶ [020_system-defaults] Applying system defaults...")

        # 1) journald drop-in
        if not _write_file(JOURNALD_DROPIN, JOURNALD_CONTENT, run):
            print("❌ Failed writing journald drop-in.")
            return False

        # 2) sysctl defaults
        if not _write_file(SYSCTL_FILE, SYSCTL_CONTENT, run):
            print("❌ Failed writing sysctl defaults.")
            return False

        # 3) logrotate (for apps that still write plaintext logs)
        if not _install_packages(["logrotate"], run):
            print("❌ Failed installing logrotate.")
            return False

        # 4) Enable time sync (ok if already enabled)
        print("$ systemctl enable --now systemd-timesyncd.service")
        r = run(["systemctl", "enable", "--now", "systemd-timesyncd.service"], check=False, capture_output=True)
        if r.stdout: print(r.stdout.rstrip())
        if r.stderr: print(r.stderr.rstrip())

        # Apply changes
        print("$ systemctl restart systemd-journald")
        r = run(["systemctl", "restart", "systemd-journald"], check=False, capture_output=True)
        if r.returncode != 0:
            if r.stdout: print(r.stdout.rstrip())
            if r.stderr: print(r.stderr.rstrip())
            return False

        print("$ sysctl --system  # load /etc/sysctl.d/*")
        r = run(["sysctl", "--system"], check=False, capture_output=True)
        if r.stdout: print(r.stdout.rstrip())
        if r.stderr: print(r.stderr.rstrip())
        if r.returncode != 0:
            return False

        print("✔ [020_system-defaults] Complete.")
        return True

    except Exception as exc:
        print(f"ERROR: 020_system-defaults.install failed: {exc}")
        return False


--- modules/030_backup/module.py ---
#!/usr/bin/env python3
"""
modules/030_backup/module.py

Btrfs + GRUB backup module for your provisioning framework.

Assumptions (per project README / requirements):
- Root filesystem is ALWAYS Btrfs.
- GRUB is installed.
- Off-machine backups are out-of-scope for this module.

What this module does
---------------------
1) Installs backup stack packages:
   - btrfs-progs, snapper, snap-pac (pre/post pacman snapshots)
   - grub-btrfs + inotify-tools (GRUB submenu for snapshots via daemon)
2) Ensures Snapper root config exists and is sane.
   - Creates `/.snapshots` subvolume if needed (via `snapper create-config`).
   - Enables timeline + cleanup systemd timers.
   - Tunes conservative retention limits (editable later).
3) Adds a small pacman post-transaction hook to record package lists in /var/backups.

Idempotency
-----------
- Safe re-runs: checks for existing config/timers/files before changing anything.
- Prints shell-like actions; surfaces stdout/stderr on failures.

Returns True on success, False on any failure (so the orchestrator can stop).
"""

from __future__ import annotations

from typing import Callable, Optional
import shlex

from utils.pacman import install_packages as pacman_install

# ------------------------------- helpers ------------------------------------

def _run_ok(run: Callable, cmd: list[str], *, input_text: Optional[str] = None) -> bool:
    res = run(cmd, check=False, capture_output=True, input_text=input_text)
    if res.returncode != 0:
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
        return False
    if res.stdout:
        print(res.stdout.rstrip())
    if res.stderr:
        print(res.stderr.rstrip())
    return True


def _systemd_enable_now(run: Callable, unit: str) -> bool:
    return _run_ok(run, ["systemctl", "enable", "--now", unit])


def _file_exists(run: Callable, path: str) -> bool:
    return run(["test", "-e", path], check=False).returncode == 0


def _is_enabled(run: Callable, unit: str) -> bool:
    return run(["systemctl", "is-enabled", "--quiet", unit], check=False).returncode == 0


def _write_root_file(run: Callable, path: str, content: str, mode: str = "0644") -> bool:
    # Use `install` to atomically create/update with permissions.
    cmd = [
        "bash",
        "-lc",
        f"install -D -m {shlex.quote(mode)} /dev/stdin {shlex.quote(path)}",
    ]
    return _run_ok(run, cmd, input_text=content)


def _append_root_file(run: Callable, path: str, content: str) -> bool:
    cmd = ["bash", "-lc", f"mkdir -p $(dirname {shlex.quote(path)}) && tee -a {shlex.quote(path)} >/dev/null"]
    return _run_ok(run, cmd, input_text=content)


def _detect_fs(run: Callable) -> str:
    res = run(["findmnt", "-n", "-o", "FSTYPE", "/"], check=False, capture_output=True)
    return (res.stdout or "").strip()


# ------------------------------- snapper ------------------------------------

def _ensure_snapper_root_config(run: Callable) -> bool:
    # Ensure /.snapshots exists and root config is present. We let `snapper create-config` do the right thing.
    if _file_exists(run, "/etc/snapper/configs/root"):
        print("snapper root config already present.")
        return True

    print("Creating snapper root config for '/'.")
    # This will create /.snapshots as a subvolume (if needed) and a default config.
    # It can fail if /.snapshots is a plain dir or already a separate subvolume with unexpected layout; we continue with a warning.
    if not _run_ok(run, ["snapper", "-c", "root", "create-config", "/"]):
        print("⚠️  'snapper create-config' failed. If /.snapshots already exists from installer, this can be safe to ignore.")
        # Even when it failed, it's possible the config file actually exists now. Re-check:
        if not _file_exists(run, "/etc/snapper/configs/root"):
            return False

    # Permissions as recommended (root:root 750) — tolerate errors if mount is odd; do not fail the run.
    _run_ok(run, ["bash", "-lc", "chown root:root /.snapshots 2>/dev/null || true" ])
    _run_ok(run, ["bash", "-lc", "chmod 750 /.snapshots 2>/dev/null || true" ])
    return True


def _tune_snapper_limits(run: Callable) -> bool:
    # Conservative defaults; can be edited later in /etc/snapper/configs/root
    edits = [
        r"sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE=\"yes\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP=\"yes\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY=\"8\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY=\"7\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY=\"4\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY=\"12\"/' /etc/snapper/configs/root || true",
        r"sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY=\"0\"/' /etc/snapper/configs/root || true",
    ]
    for line in edits:
        if not _run_ok(run, ["bash", "-lc", line]):
            return False
    return True


def _enable_snapper_timers(run: Callable) -> bool:
    ok = True
    if not _is_enabled(run, "snapper-timeline.timer"):
        ok = ok and _systemd_enable_now(run, "snapper-timeline.timer")
    if not _is_enabled(run, "snapper-cleanup.timer"):
        ok = ok and _systemd_enable_now(run, "snapper-cleanup.timer")
    return ok


# ------------------------------- pacman hook --------------------------------

def _ensure_pkglist_hook(run: Callable) -> bool:
    path = "/etc/pacman.d/hooks/95-backup-pkglist.hook"
    if _file_exists(run, path):
        return True
    content = """[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Save package lists to /var/backups (explicit and foreign)
When = PostTransaction
Exec = /bin/bash -lc 'install -d -m 0755 /var/backups && pacman -Qqe > /var/backups/pkglist-explicit.txt && pacman -Qqm > /var/backups/pkglist-aur.txt || true'
"""
    return _write_root_file(run, path, content, mode="0644")


# ------------------------------- grub-btrfs ---------------------------------

def _enable_grub_btrfsd(run: Callable) -> bool:
    # Start/enabled so GRUB submenu updates when snapshots change.
    return _systemd_enable_now(run, "grub-btrfsd.service")


# --------------------------------- main -------------------------------------

def install(run: Callable) -> bool:
    try:
        print("▶ [030_backup] Setting up Btrfs snapshots (snapper) and GRUB integration…")

        # 0) Assert Btrfs root
        fstype = _detect_fs(run)
        if fstype.lower() != "btrfs":
            print(f"ERROR: Expected Btrfs root, but detected: {fstype or 'unknown'}")
            return False

        # 1) Packages
        pkgs = [
            "btrfs-progs",
            "snapper",
            "snap-pac",
            "grub-btrfs",
            "inotify-tools",
        ]
        if not pacman_install(pkgs, run):
            return False

        # 2) Snapper root config & limits
        if not _ensure_snapper_root_config(run):
            return False
        if not _tune_snapper_limits(run):
            return False
        if not _enable_snapper_timers(run):
            return False

        # 3) Pacman hook to save package lists (optional but helpful)
        if not _ensure_pkglist_hook(run):
            return False

        # 4) GRUB snapshot submenu daemon
        if not _enable_grub_btrfsd(run):
            return False

        print("✔ [030_backup] Backup stack configured: snapper + snap-pac + grub-btrfs.")
        return True

    except Exception as exc:
        print(f"ERROR: 030_backup.install failed: {exc}")
        return False


--- modules/040_fonts/module.py ---
#!/usr/bin/env python3
"""
040_fonts — System-wide Nerd Font defaults (Option A)
Version: 1.0.0

What this module does
---------------------
- Installs a Nerd Font family (JetBrainsMono Nerd Font) system-wide.
- Installs Nerd Fonts Symbols for robust glyph/icon fallback.
- Sets **JetBrainsMono Nerd Font** as the **system default for `monospace`** via Fontconfig.
- Enables Nerd Symbols fallback (so apps automatically get Nerd icons when base fonts lack glyphs).
- Refreshes font cache and prints a quick verification.

Notes
-----
- We intentionally only set the **monospace** generic family (Option A, recommended).
- A commented-out alternative (Option B) is provided to force Nerd Font for
  **monospace, sans-serif, and serif** — not recommended for desktop UI, but
  you can enable it by swapping the XML below.
"""
from __future__ import annotations

from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Callable

from utils.pacman import install_packages


FONTCONF_DIR = Path("/etc/fonts")
FONTCONF_LOCAL = FONTCONF_DIR / "local.conf"
FONTCONF_D = FONTCONF_DIR / "conf.d"
NERD_SYMBOLS_AVAIL = Path("/usr/share/fontconfig/conf.avail/10-nerd-font-symbols.conf")
NERD_SYMBOLS_LINK = FONTCONF_D / "10-nerd-font-symbols.conf"

# --- Fontconfig XML (Option A: monospace only) ---------------------------------
XML_OPTION_A = """<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <!-- Default monospace font -> JetBrainsMono Nerd Font -->
  <match target="pattern">
    <test qual="any" name="family"><string>monospace</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
</fontconfig>
"""

# --- Fontconfig XML (Option B: force all generics to Nerd Font) ----------------
# NOTE: This will make UI text monospace. Usually undesirable; use with care.
XML_OPTION_B_COMMENTED = """\n<!--
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any"><string>monospace</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
  <match target="pattern">
    <test name="family" qual="any"><string>sans-serif</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
  <match target="pattern">
    <test name="family" qual="any"><string>serif</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
</fontconfig>
-->
"""


def _print_action(text: str) -> None:
    print(f"$ {text}")


def _ensure_dirs(run: Callable) -> bool:
    try:
        for d in (FONTCONF_DIR, FONTCONF_D):
            _print_action(f"mkdir -p {d}")
            res = run(["mkdir", "-p", str(d)], check=False, capture_output=True)
            if res.returncode != 0:
                if res.stdout:
                    print(res.stdout.rstrip())
                if res.stderr:
                    print(res.stderr.rstrip())
                return False
        return True
    except Exception as exc:
        print(f"ERROR: failed to ensure fontconfig dirs: {exc}")
        return False


def _write_local_conf(xml: str, run: Callable) -> bool:
    """Write XML to /etc/fonts/local.conf atomically using sudo runner."""
    try:
        with NamedTemporaryFile("w", delete=False, encoding="utf-8") as tmp:
            tmp.write(xml)
            tmp_path = Path(tmp.name)
        _print_action(f"install -m 0644 {tmp_path} {FONTCONF_LOCAL}")
        res = run(["install", "-m", "0644", str(tmp_path), str(FONTCONF_LOCAL)], check=False, capture_output=True)
        tmp_path.unlink(missing_ok=True)
        if res.returncode != 0:
            if res.stdout:
                print(res.stdout.rstrip())
            if res.stderr:
                print(res.stderr.rstrip())
            return False
        return True
    except Exception as exc:
        print(f"ERROR: failed to write {FONTCONF_LOCAL}: {exc}")
        return False


def _enable_nerd_symbols(run: Callable) -> bool:
    """Symlink 10-nerd-font-symbols.conf into /etc/fonts/conf.d/ if available."""
    try:
        if not NERD_SYMBOLS_AVAIL.exists():
            print(f"⚠️  Nerd Symbols fontconfig file not found: {NERD_SYMBOLS_AVAIL}")
            return True  # Non-fatal; the main default still works.
        _print_action(f"ln -sf {NERD_SYMBOLS_AVAIL} {NERD_SYMBOLS_LINK}")
        res = run(["ln", "-sf", str(NERD_SYMBOLS_AVAIL), str(NERD_SYMBOLS_LINK)], check=False, capture_output=True)
        if res.returncode != 0:
            if res.stdout:
                print(res.stdout.rstrip())
            if res.stderr:
                print(res.stderr.rstrip())
            return False
        return True
    except Exception as exc:
        print(f"ERROR: failed to enable Nerd Symbols fallback: {exc}")
        return False


def _refresh_cache(run: Callable) -> bool:
    try:
        _print_action("fc-cache -f -v")
        res = run(["fc-cache", "-f", "-v"], check=False, capture_output=True)
        # fc-cache can be chatty; print on success/failure.
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
        return res.returncode == 0
    except Exception as exc:
        print(f"ERROR: failed to refresh font cache: {exc}")
        return False


def _verify(run: Callable) -> None:
    try:
        _print_action("fc-match monospace")
        res = run(["fc-match", "monospace"], check=False, capture_output=True)
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
    except Exception:
        pass


def install(run: Callable) -> bool:
    try:
        print("▶ [040_fonts] Installing and configuring system fonts (Nerd Font as monospace)…")

        # 1) Install required fonts (system-wide)
        packages = [
            "ttf-jetbrains-mono-nerd",     # base monospace font
            "ttf-nerd-fonts-symbols",      # symbols-only fallback for icons
            # Optional: better emoji fallback (uncomment if desired)
            # "noto-fonts-emoji",
        ]
        if not install_packages(packages, run):
            print("ERROR: Failed to install required font packages")
            return False

        # 2) Ensure /etc/fonts and /etc/fonts/conf.d exist
        if not _ensure_dirs(run):
            return False

        # 3) Write /etc/fonts/local.conf (Option A)
        if not _write_local_conf(XML_OPTION_A, run):
            return False

        # (Optional) If you want Option B instead, replace above with XML_OPTION_B_COMMENTED content
        # and remove the surrounding HTML comment markers.

        # 4) Enable Nerd Symbols fallback rule
        if not _enable_nerd_symbols(run):
            return False

        # 5) Refresh cache and verify
        if not _refresh_cache(run):
            return False
        _verify(run)

        print("✔ [040_fonts] Font configuration complete. JetBrainsMono Nerd Font is the system monospace default.")
        return True
    except Exception as exc:
        print(f"ERROR: 040_fonts.install failed: {exc}")
        return False


--- modules/100_firmware/module.py ---
"""
100_firmware/module.py

Installs base firmware + microcode packages and enables tooling
to keep device firmware updated. Also surfaces available updates
at the end so users can take immediate action.
"""

from typing import Callable

# List of core firmware/microcode/utilities
PACKAGES = [
    "linux-firmware",
    "intel-ucode",
    "fwupd",
    "bolt",       # Thunderbolt manager (tbtadm/boltctl)
    "nvme-cli",
]


def _install_packages(run: Callable) -> bool:
    cmd = ["pacman", "-S", "--needed", "--noconfirm", *PACKAGES]
    print("$", " ".join(cmd))
    res = run(cmd, check=False, capture_output=True)
    if res.returncode != 0:
        print("❌ Failed to install firmware packages")
        if res.stderr:
            print(res.stderr)
        return False
    return True


def _enable_fwupd(run: Callable) -> bool:
    cmd = ["systemctl", "enable", "--now", "fwupd.service"]
    print("$", " ".join(cmd))
    return run(cmd, check=False).returncode == 0


def _check_fw_updates(run: Callable) -> None:
    print("$ fwupdmgr get-updates")
    res = run(["fwupdmgr", "get-updates"], check=False, capture_output=True)
    if res.stdout:
        print(res.stdout.rstrip())
    if res.stderr:
        print(res.stderr.rstrip())


def _regenerate_grub_if_present(run: Callable) -> None:
    # Only if grub-mkconfig is present
    res = run(["bash", "-lc", "command -v grub-mkconfig"], check=False, capture_output=True)
    if res.returncode == 0:
        print("$ sudo -n grub-mkconfig -o /boot/grub/grub.cfg")
        run(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"], check=False)


def _nvme_device_present() -> bool:
    try:
        import os
        return any(name.startswith("nvme") for name in os.listdir("/dev"))
    except Exception:
        return False


def install(run: Callable) -> bool:
    print("### [100] Firmware and Microcode")

    if not _install_packages(run):
        return False

    if not _enable_fwupd(run):
        print("⚠️  Failed to enable fwupd.service; you may need to enable manually.")

    # Print updates so user can act immediately
    _check_fw_updates(run)

    # If grub is present, regen config to pick up new microcode
    _regenerate_grub_if_present(run)

    # Show nvme list if device exists
    if _nvme_device_present():
        # Use sudo-runner for consistent output even if some subcommands need root
        print("$ nvme list")
        res = run(["nvme", "list"], check=False, capture_output=True)
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())

    return True


--- modules/110__power/module.py ---
#!/usr/bin/env python3
"""
110_power — Laptop power & thermal baseline (driver-agnostic)

What it does
------------
- Installs and enables: TLP + thermald (powertop optional for diagnostics)
- Masks power-profiles-daemon to avoid conflicts with TLP
- Applies a small TLP drop-in with conservative, safe defaults
- No GPU/driver-specific settings here (those live in 130_gpu)

Idempotent and safe to run on fresh systems before graphics drivers are present.
"""

from __future__ import annotations
from pathlib import Path
from typing import Callable
from utils.pacman import install_packages

TLP_DROPIN = "/etc/tlp.d/10-laptop-baseline.conf"


def _write_file(run: Callable, path: str, content: str) -> bool:
    """Create parent dir, back up existing file, then write content via tee."""
    try:
        parent = Path(path).parent
        # mkdir -p
        res = run(["mkdir", "-p", str(parent)], check=False, capture_output=True)
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False

        # backup if present
        res = run(
            ["bash", "-lc", f"if [ -f '{path}' ]; then cp -a '{path}' '{path}.bak.$(date +%Y%m%d-%H%M%S)'; fi"],
            check=False,
            capture_output=True,
        )
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False

        # write
        res = run(["tee", path], check=False, capture_output=True, input_text=content)
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False

        return True
    except Exception as exc:
        print(f"ERROR: writing {path} failed: {exc}")
        return False


def install(run: Callable) -> bool:
    try:
        print("▶ [110_power] Installing baseline power/thermal tools...")

        # Packages: tlp, thermald, powertop (diagnostics only)
        if not install_packages(["tlp", "tlp-rdw", "thermald", "powertop"], run):
            return False

        # Avoid conflicts: mask power-profiles-daemon if it exists
        run(["systemctl", "mask", "--now", "power-profiles-daemon.service"], check=False)

        # Recommended by TLP when using RDW: mask rfkill units (harmless if absent)
        run(["systemctl", "mask", "--now", "systemd-rfkill.service", "systemd-rfkill.socket"], check=False)

        # Conservative, driver-agnostic TLP overrides
        tlp_dropin = """# /etc/tlp.d/10-laptop-baseline.conf — safe defaults (driver-agnostic)

# CPU energy/perf (Intel HWP capable CPUs use EPP underneath)
CPU_DRIVER_OPMODE_ON_AC=active
CPU_DRIVER_OPMODE_ON_BAT=active
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# Runtime PM: allow autosuspend on both AC and battery for general devices
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

# USB autosuspend: leave default (kernel/TLP decide); uncomment to force
# USB_AUTOSUSPEND=1

# SATA link power management: keep defaults; uncomment to experiment
# SATA_LINKPWR_ON_AC=max_performance
# SATA_LINKPWR_ON_BAT=med_power_with_dipm

# Notes:
# - GPU-specific settings (NVIDIA DynamicPowerManagement, i915 PSR/FBC, etc.)
#   are intentionally NOT set here. Apply them in modules/130_gpu after drivers.
"""
        if not _write_file(run, TLP_DROPIN, tlp_dropin):
            return False

        # Enable services
        for args in (["enable", "--now", "tlp.service"],
                     ["enable", "--now", "thermald.service"]):
            res = run(["systemctl", *args], check=False, capture_output=True)
            if res.returncode != 0:
                if res.stdout: print(res.stdout.rstrip())
                if res.stderr: print(res.stderr.rstrip())
                return False

        # Helpful (optional) dispatcher for TLP RDW features if you use them later
        run(["systemctl", "enable", "--now", "NetworkManager-dispatcher.service"], check=False)

        print("✔ [110_power] Baseline applied: TLP + thermald active, conflicts masked.")
        print("   GPU/driver-specific power tuning will be handled in 130_gpu.")
        return True

    except Exception as exc:
        print(f"ERROR: 110_power.install failed: {exc}")
        return False


--- modules/120_input/module.py ---
# modules/120_input/module.py
#!/usr/bin/env python3
"""
Input Devices (libinput for Xorg)
Version: 1.0.0

What this module does
---------------------
- Installs input-related packages for Xorg:
  * libinput (core), xf86-input-libinput (Xorg driver)
  * utilities: xorg-xinput, xorg-xev, evtest
- Symlinks local Xorg input configs from this module's `xorg.conf.d/`
  into `/etc/X11/xorg.conf.d/` (with per-run backups via your symlinker).
- (Optional) If a local `udev/` folder exists, its rules are symlinked into
  `/etc/udev/rules.d/` (useful for gesture tooling uaccess, etc).
- Prints non-destructive verification tips at the end.

Idempotency & Safety
--------------------
- Uses pacman's `--needed --noconfirm`.
- Uses your symlinker which backs up existing targets before linking.
- Stops on first failure and returns False so the orchestrator can abort cleanly.
"""

from __future__ import annotations

from pathlib import Path
from typing import Callable

from utils.pacman import install_packages
from utils.symlinker import symlink_tree_files


def _module_dir() -> Path:
    return Path(__file__).resolve().parent


def _symlink_xorg(run: Callable) -> bool:
    """Symlink this module's xorg.conf.d/* into /etc/X11/xorg.conf.d/ if present."""
    local_xorg = _module_dir() / "xorg.conf.d"
    if not local_xorg.exists():
        print("⚠️  [120_input] No local xorg.conf.d/ directory found; skipping Xorg config symlinks.")
        return True  # Not an error—config is optional.

    if not local_xorg.is_dir():
        print("ERROR: [120_input] xorg.conf.d exists but is not a directory.")
        return False

    dest = Path("/etc/X11/xorg.conf.d")
    print(f"▶ [120_input] Linking Xorg input configs -> {dest}")
    ok = symlink_tree_files(local_xorg, dest, run=run, use_relative=False)
    if not ok:
        print("ERROR: [120_input] Failed to link Xorg input configs.")
    return ok


def _symlink_udev_rules(run: Callable) -> bool:
    """Symlink optional udev rules from ./udev/* to /etc/udev/rules.d/ if present."""
    local_udev = _module_dir() / "udev"
    if not local_udev.exists():
        # Entirely optional—skip quietly.
        return True

    if not local_udev.is_dir():
        print("ERROR: [120_input] udev exists but is not a directory.")
        return False

    dest = Path("/etc/udev/rules.d")
    print(f"▶ [120_input] Linking udev rules -> {dest}")
    ok = symlink_tree_files(local_udev, dest, run=run, use_relative=False)
    if not ok:
        print("ERROR: [120_input] Failed to link udev rules.")
        return False

    # Hint: tell the user how to reload rules (non-fatal if they don't).
    print("ℹ️  [120_input] To reload udev rules now: sudo udevadm control --reload && sudo udevadm trigger")
    return True


def install(run: Callable) -> bool:
    """
    Install input stack and apply local configs.

    Arguments:
        run: sudo runner from start_sudo_session()

    Returns:
        True on success, False otherwise.
    """
    try:
        print("▶ [120_input] Installing input device stack (libinput for Xorg)...")
        packages = [
            "libinput",
            "xf86-input-libinput",
            "xorg-xinput",
            "xorg-xev",
            "evtest",
        ]
        if not install_packages(packages, run):
            print("❌ [120_input] Package installation failed.")
            return False

        if not _symlink_xorg(run):
            return False

        if not _symlink_udev_rules(run):
            return False

        print("✔ [120_input] Input stack configured.")

        # Non-destructive verification tips
        print("\n[120_input] Verify configuration with:")
        print("  $ libinput list-devices")
        print("  $ xinput list")
        print("  $ grep \"Using input driver 'libinput'\" /var/log/Xorg.0.log || true")
        print("\n[120_input] Notes:")
        print("  - Edit modules/120_input/xorg.conf.d/90-libinput.conf in-repo to tweak touchpad/mouse defaults.")
        print("  - If you added udev rules (e.g., for gestures), you may need to replug the device or reboot.")

        return True

    except Exception as exc:
        print(f"ERROR: [120_input] install() failed: {exc}")
        return False


--- modules/130_gpu/module.py ---
# modules/130_gpu/module.py
#!/usr/bin/env python3
"""
130_gpu — Hybrid Intel + NVIDIA (Optimus) setup for XPS 9500
Version: 1.0.0

What this module does (no X11 required)
---------------------------------------
1) Installs the correct Intel + NVIDIA userspace/kernel packages for PRIME offload.
2) Configures NVIDIA Runtime Power Management (RTD3) to save battery:
   - udev rules to set power/control=auto on bind/add, and =on on unbind.
   - modprobe option NVreg_DynamicPowerManagement=0x02.
3) (Optional) Enables nvidia-persistenced (toggle below).
4) Skips any X11/PRIME tests; those will run after your display-server module.

Idempotency & Safety
--------------------
- Uses pacman --needed via utils.pacman.install_packages().
- Writes config files only if content differs; backs up existing files with a timestamp.
- Prints shell-like actions and clear results.

Notes
-----
- We intentionally DO NOT install xf86-video-intel; modesetting (built into xorg-server)
  is recommended for your iGPU generation.
- If you later enable multilib and want 32-bit Vulkan/NVIDIA userspace for gaming,
  flip INSTALL_MULTILIB_LIBS to True.
"""

from __future__ import annotations

from datetime import datetime
from typing import Callable, Optional

from utils.pacman import install_packages

# ------------------------- toggles / constants -------------------------

ENABLE_NVIDIA_PERSISTENCE: bool = False         # set True if you want the daemon enabled
INSTALL_MULTILIB_LIBS: bool = False             # set True if you have [multilib] enabled

UDEV_RULES_PATH = "/etc/udev/rules.d/80-nvidia-pm.rules"
MODPROBE_CONF_PATH = "/etc/modprobe.d/nvidia-pm.conf"

UDEV_RULES_CONTENT = """\
# Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind/add
ACTION=="bind",   SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind",   SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add",    SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add",    SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
# Disable runtime PM on unbind (handovers / driver unload)
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
"""

MODPROBE_CONTENT = """\
# Deeper NVIDIA runtime power management for Turing Optimus notebooks
options nvidia NVreg_DynamicPowerManagement=0x02
# If you encounter odd D3/runtime PM issues on specific driver/firmware combos, try the more conservative:
# options nvidia NVreg_DynamicPowerManagement=0x01
"""

# Intel userspace & VA/Vulkan
PKGS_INTEL = [
    "mesa", "mesa-utils",           # GL + glxinfo
    "vulkan-intel",                 # Intel Vulkan ICD
    "intel-media-driver",           # VAAPI (Gen9+)
    "libva-utils",                  # vainfo, etc.
]

# NVIDIA proprietary + PRIME offload helpers
PKGS_NVIDIA = [
    "nvidia", "nvidia-utils", "nvidia-settings",
    "nvidia-prime",                # provides prime-run
    "vulkan-tools",                # vulkaninfo
]

# Optional 32-bit userland (multilib)
PKGS_MULTILIB = [
    "lib32-nvidia-utils",
    "lib32-vulkan-intel",
]


# ------------------------- small helpers -------------------------

def _ts() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def _print_action(text: str) -> None:
    print(f"$ {text}")


def _print_info(text: str) -> None:
    print(f"ℹ️  {text}")


def _print_error(text: str) -> None:
    print(f"ERROR: {text}")


def _read_file(path: str, run: Callable) -> Optional[str]:
    """Read file content as root; return None if missing/unreadable."""
    res = run(["bash", "-lc", f'[[ -r "{path}" ]] && cat "{path}" || true'],
              check=False, capture_output=True)
    if res.returncode != 0:
        return None
    return res.stdout or ""


def _write_file_if_changed(path: str, content: str, run: Callable) -> bool:
    """If existing content differs, back it up and write new content."""
    try:
        existing = _read_file(path, run)
        if existing is not None and existing.strip() == content.strip():
            _print_info(f"{path} already up-to-date.")
            return True

        # Backup if exists
        if existing is not None and existing != "":
            backup = f"{path}.bak.{_ts()}"
            _print_action(f"cp -a {path} {backup}")
            res = run(["cp", "-a", path, backup], check=False, capture_output=True)
            if res.returncode != 0:
                if res.stderr: _print_error(res.stderr.rstrip())
                return False

        # Ensure parent dir exists
        _print_action(f"mkdir -p $(dirname {path})")
        res = run(["bash", "-lc", f"mkdir -p \"$(dirname '{path}')\""], check=False, capture_output=True)
        if res.returncode != 0:
            if res.stderr: _print_error(res.stderr.rstrip())
            return False

        # Write via tee (root)
        _print_action(f"tee {path}  >/dev/null")
        res = run(["tee", path], check=False, capture_output=True, input_text=content)
        if res.returncode != 0:
            if res.stderr: _print_error(res.stderr.rstrip())
            return False

        return True
    except Exception as exc:
        _print_error(f"Failed writing {path}: {exc}")
        return False


def _reload_udev(run: Callable) -> bool:
    ok = True
    _print_action("udevadm control --reload")
    r1 = run(["udevadm", "control", "--reload"], check=False, capture_output=True)
    ok &= (r1.returncode == 0)
    if r1.returncode != 0 and r1.stderr:
        _print_error(r1.stderr.rstrip())

    _print_action("udevadm trigger")
    r2 = run(["udevadm", "trigger"], check=False, capture_output=True)
    ok &= (r2.returncode == 0)
    if r2.returncode != 0 and r2.stderr:
        _print_error(r2.stderr.rstrip())
    return ok


def _enable_persistenced(run: Callable) -> bool:
    _print_action("systemctl enable --now nvidia-persistenced.service")
    res = run(["systemctl", "enable", "--now", "nvidia-persistenced.service"], check=False, capture_output=True)
    if res.returncode != 0:
        if res.stderr: _print_error(res.stderr.rstrip())
        return False
    return True


# ------------------------- main entrypoint -------------------------

def install(run: Callable) -> bool:
    """
    Install & configure hybrid GPU (Intel + NVIDIA) with runtime PM.
    Skips X11/PRIME verification; that happens in your display-server module.
    """
    try:
        print("▶ [130_gpu] Installing Intel + NVIDIA drivers and configuring power management...")

        # 1) Packages
        pkgs = PKGS_INTEL + PKGS_NVIDIA + (PKGS_MULTILIB if INSTALL_MULTILIB_LIBS else [])
        if not install_packages(pkgs, run):
            _print_error("Package installation failed.")
            return False

        # 2) Config files
        if not _write_file_if_changed(UDEV_RULES_PATH, UDEV_RULES_CONTENT, run):
            return False
        if not _write_file_if_changed(MODPROBE_CONF_PATH, MODPROBE_CONTENT, run):
            return False

        # 3) Apply udev changes
        if not _reload_udev(run):
            _print_error("Failed to reload/trigger udev.")
            return False

        # 4) Optional persistence daemon
        if ENABLE_NVIDIA_PERSISTENCE:
            if not _enable_persistenced(run):
                _print_error("Failed to enable nvidia-persistenced (optional).")
                return False

        print("✔ [130_gpu] GPU base install & power-management config complete.")
        _print_info("X11/PRIME checks will run after your display-server module is installed.")
        _print_info("Tip: after X11, test with `prime-run glxinfo | grep \"OpenGL renderer\"` and check "
                    "`/sys/bus/pci/devices/0000:01:00.0/power/runtime_status` is `suspended` at idle.")
        return True

    except Exception as exc:
        _print_error(f"130_gpu.install failed: {exc}")
        return False


--- modules/140_audio/module.py ---
# modules/140_audio/module.py
#!/usr/bin/env python3
"""
140_audio — PipeWire/WirePlumber + SOF firmware (Intel cAVS) with optional Bluetooth
Version: 1.0.1

What this module does
---------------------
- Installs a modern PipeWire audio stack on Arch (replacing PulseAudio).
- Ensures Intel cAVS (Comet Lake) works by installing SOF firmware + UCM.
- (Optional) Sets up Bluetooth audio (BlueZ) and a small WirePlumber tweak.
- Adds a couple of safe, tiny config snippets (can be removed later).
- Enables/starts user services and verifies the result.

Environment toggles
-------------------
- AUDIO_ENABLE_BLUETOOTH=0  -> skip installing/enabling Bluetooth audio (default: enabled)

Idempotency
-----------
- pacman uses --needed; config files written with install -D; systemd enable/now is safe to repeat.

Notes / Fixes in this version
-----------------------------
- Clarified that `wpctl` is provided by **WirePlumber** (not pipewire-cli).
- Hardened verification: treat `wpctl status` success when a non-null output node
  (e.g., `alsa_output` or `bluez_output`) is present; avoid PulseAudio-specific tokens.
- Avoid duplicate Bluetooth service enablement here (150_network is the source of truth).
"""

from __future__ import annotations
import os
import subprocess
from typing import Callable

from utils.pacman import install_packages


# ------------------------------- helpers -------------------------------------

def _print(msg: str) -> None:
    print(msg)


def _run_user(cmd: list[str], *, check: bool = False, capture_output: bool = True) -> subprocess.CompletedProcess:
    """
    Run a command as the *invoking user* (NOT via sudo). Useful for:
    - systemctl --user …
    - pactl/wpctl status queries
    """
    _print("$ " + " ".join(cmd))
    return subprocess.run(cmd, check=check, text=True, capture_output=capture_output)


def _write_root_file(path: str, content: str, run: Callable) -> bool:
    """
    Create/update a root-owned file at `path` using the sudo-runner.
    Uses: install -Dm0644 /dev/stdin <path>
    """
    try:
        res = run(
            ["install", "-Dm0644", "/dev/stdin", path],
            check=False,
            capture_output=True,
            input_text=content,
        )
        if res.returncode != 0:
            if res.stdout:
                print(res.stdout.rstrip())
            if res.stderr:
                print(res.stderr.rstrip())
            return False
        return True
    except Exception as exc:
        print(f"ERROR: failed writing {path}: {exc}")
        return False


def _enable_user_units(units: list[str]) -> bool:
    ok = True
    for u in units:
        try:
            res = _run_user(["systemctl", "--user", "enable", "--now", u], check=False)
            if res.returncode != 0:
                ok = False
                if res.stdout:
                    print(res.stdout.rstrip())
                if res.stderr:
                    print(res.stderr.rstrip())
        except Exception as exc:
            print(f"ERROR: enabling user unit {u}: {exc}")
            ok = False
    return ok


def _enable_system_units(units: list[str], run: Callable) -> bool:
    ok = True
    for u in units:
        try:
            res = run(["systemctl", "enable", "--now", u], check=False, capture_output=True)
            if res.returncode != 0:
                ok = False
                if res.stdout:
                    print(res.stdout.rstrip())
                if res.stderr:
                    print(res.stderr.rstrip())
        except Exception as exc:
            print(f"ERROR: enabling system unit {u}: {exc}")
            ok = False
    return ok


# ------------------------------- verification --------------------------------

def _verify_stack() -> bool:
    """
    Basic verification:
    - pactl info -> Server Name mentions PipeWire
    - wpctl status -> has at least one output node (alsa_output/bluez_output) not 'auto_null' (best-effort)
    """
    try:
        pi = _run_user(["pactl", "info"], check=False)
        server = ""
        if pi.returncode == 0 and pi.stdout:
            for line in pi.stdout.splitlines():
                if line.startswith("Server Name:"):
                    server = line.split(":", 1)[1].strip()
                    break
        if "PipeWire" not in server:
            print("❌ Verification: pactl server is not PipeWire (got: %r)" % server)
            return False
    except FileNotFoundError:
        print("❌ Verification failed: 'pactl' not found.")
        return False

    # wpctl status check (best-effort, robust to formatting changes)
    try:
        ws = _run_user(["wpctl", "status"], check=False)
        if ws.returncode == 0 and ws.stdout:
            has_output = any(
                ("alsa_output" in line or "bluez_output" in line) and "auto_null" not in line
                for line in ws.stdout.splitlines()
            )
            if not has_output:
                print("⚠️  Verification: wpctl did not list a usable output (non-null).")
        else:
            print("⚠️  Verification: wpctl status unavailable.")
    except FileNotFoundError:
        print("⚠️  Verification: 'wpctl' not found (is WirePlumber installed?)")

    return True


# ------------------------------- install -------------------------------------

def install(run: Callable) -> bool:
    try:
        _print("▶ [140_audio] Installing PipeWire/WirePlumber + Intel SOF firmware")

        enable_bt = os.environ.get("AUDIO_ENABLE_BLUETOOTH", "1") not in ("0", "false", "False", "no", "No")

        # Core audio stack (explicit pieces to avoid meta surprises)
        core_pkgs = [
            "pipewire",
            "pipewire-alsa",
            "pipewire-pulse",
            "pipewire-jack",
            "wireplumber",     # provides 'wpctl'
            "alsa-utils",
            "alsa-ucm-conf",
            "sof-firmware",
            # handy mixers/inspectors
            "pavucontrol",
        ]

        bt_pkgs = ["bluez", "bluez-utils"] if enable_bt else []

        if not install_packages(core_pkgs + bt_pkgs, run):
            return False

        # Optional PipeWire pulse shim tweak: switch to newly connected outputs (USB DAC/HDMI/BT)
        pw_pulse_snippet = """# Auto-switch to new outputs (PipeWire Pulse shim)
# Remove this file if you prefer to keep the current default sink.
pulse.cmd = [
  { cmd = "load-module" args = "module-switch-on-connect" }
]
"""
        if not _write_root_file("/etc/pipewire/pipewire-pulse.conf.d/50-switch-on-connect.conf", pw_pulse_snippet, run):
            return False

        # WirePlumber: reduce "first-sound lag" / pops by disabling suspend (can comment out if undesired)
        wp_disable_suspend = """# Reduce latency pops by disabling node suspend for ALSA/BlueZ
monitor.alsa.rules = [
  {
    matches = [ { node.name = "~alsa_input.*" }, { node.name = "~alsa_output.*" } ]
    actions = { update-props = { session.suspend-timeout-seconds = 0 } }
  }
]
monitor.bluez.rules = [
  {
    matches = [ { node.name = "~bluez_input.*" }, { node.name = "~bluez_output.*" } ]
    actions = { update-props = { session.suspend-timeout-seconds = 0 } }
  }
]
"""
        if not _write_root_file("/etc/wireplumber/wireplumber.conf.d/60-disable-suspend.conf", wp_disable_suspend, run):
            return False

        # Optional Bluetooth codecs/niceties (only if BT enabled)
        if enable_bt:
            wp_bt_codecs = """# Prefer modern Bluetooth codec options where available
monitor.bluez.properties = {
  bluez5.enable-sbc-xq = true
  bluez5.enable-msbc   = true
  # Keep defaults conservative; add aptX/LDAC via AUR plugins if needed.
}
"""
            if not _write_root_file("/etc/wireplumber/wireplumber.conf.d/70-bluez-codecs.conf", wp_bt_codecs, run):
                return False

        # Enable/Start user services (explicit, even though socket-activated)
        if not _enable_user_units([
            "pipewire.service",
            "pipewire-pulse.service",
            "wireplumber.service",
        ]):
            # Not fatal; the services will usually start on login, but we try to be explicit.
            _print("⚠️  Could not enable one or more user services. Continuing.")

        # Do NOT enable bluetooth.service here to avoid duplication with 150_network.
        # (150_network is the source of truth for BT service enablement.)

        # Quick verification + sample test output (best effort)
        if not _verify_stack():
            _print("❌ [140_audio] Verification failed.")
            return False

        # Show quick info to the user
        try:
            _print("\n▶ pactl info (summary)")
            pi = _run_user(["pactl", "info"], check=False)
            if pi.stdout:
                for line in pi.stdout.splitlines():
                    if line.startswith(("Server Name:", "Default Sink:", "Default Source:")):
                        print(line)
        except Exception:
            pass

        _print("✔ [140_audio] Audio stack installed and verified.")
        _print("   Tips: run 'pavucontrol' to pick outputs, 'wpctl status' to inspect nodes.")
        return True

    except Exception as exc:
        print(f"ERROR: 140_audio.install failed: {exc}")
        return False


--- modules/150_network/module.py ---
# modules/150_network/module.py
#!/usr/bin/env python3
"""
150_network — Core networking stack for Arch
- NetworkManager (with iwd backend)
- Bluetooth (bluez)
- Thunderbolt (bolt)
- VPN: OpenVPN + WireGuard (NM-native)
- Useful tools and privacy defaults (MAC randomization)
"""

from __future__ import annotations
from pathlib import Path
from typing import Callable

from utils.pacman import install_packages

NM_CONF_DIR = Path("/etc/NetworkManager/conf.d")
NM_WIFI_BACKEND = NM_CONF_DIR / "wifi_backend.conf"
NM_MAC_PRIVACY = NM_CONF_DIR / "wifi_rand_mac.conf"


def _print_action(text: str) -> None:
    print(f"$ {text}")


def _write_file_via_tee(path: Path, content: str, run: Callable) -> bool:
    try:
        _print_action(f"mkdir -p {path.parent}")
        res = run(["mkdir", "-p", str(path.parent)], check=False, capture_output=True)
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False

        _print_action(f"tee {path}  # write config")
        res = run(["tee", str(path)], check=False, capture_output=True, input_text=content)
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False
        return True
    except Exception as exc:
        print(f"ERROR: failed to write {path}: {exc}")
        return False


def _enable_service(name: str, run: Callable) -> bool:
    try:
        _print_action(f"systemctl enable --now {name}")
        res = run(["systemctl", "enable", "--now", name], check=False, capture_output=True)
        if res.returncode != 0:
            if res.stdout: print(res.stdout.rstrip())
            if res.stderr: print(res.stderr.rstrip())
            return False
        return True
    except Exception as exc:
        print(f"ERROR: failed to enable {name}: {exc}")
        return False


def _run_check(cmd: list[str], run: Callable) -> None:
    try:
        _print_action(" ".join(cmd))
        res = run(cmd, check=False, capture_output=True)
        if res.stdout: print(res.stdout.rstrip())
        if res.stderr: print(res.stderr.rstrip())
    except Exception as exc:
        print(f"⚠️  Skipping diagnostic {' '.join(cmd)}: {exc}")


def install(run: Callable) -> bool:
    try:
        print("▶ [150_network] Starting network stack setup...")

        # 1) Packages (idempotent)
        base_pkgs = [
            "networkmanager",
            "iwd",                       # NM will use iwd as backend (do NOT enable iwd.service)
            "bluez", "bluez-utils",
            "bolt",                      # Thunderbolt authorization (D-Bus activated)
            "usbutils",                  # lsusb
            "ethtool",
            "nm-connection-editor",
            "network-manager-applet",

            # --- VPN support ---
            "openvpn",
            "networkmanager-openvpn",
            "wireguard-tools",           # NM has native WG support; tools provide wg/wg-quick, keygen, etc.
        ]
        if not install_packages(base_pkgs, run):
            print("ERROR: Package installation failed.")
            return False

        # 2) NetworkManager configuration
        nm_backend_cfg = """[device]
wifi.backend=iwd
"""
        if not _write_file_via_tee(NM_WIFI_BACKEND, nm_backend_cfg, run):
            return False

        nm_mac_cfg = """[device-mac-randomization]
wifi.scan-rand-mac-address=yes

[connection-mac-randomization]
ethernet.cloned-mac-address=random
wifi.cloned-mac-address=stable
"""
        if not _write_file_via_tee(NM_MAC_PRIVACY, nm_mac_cfg, run):
            return False

        # 3) Enable essential services
        if not _enable_service("NetworkManager.service", run):
            return False
        if not _enable_service("bluetooth.service", run):
            return False
        # iwd.service: not enabled; NetworkManager handles it.
        # bolt.service: D-Bus activated; no enable needed.

        # 4) Diagnostics (non-fatal)
        print("\n─ Diagnostics (non-fatal) ─")
        _run_check(["nmcli", "general", "status"], run)
        _run_check(["nmcli", "device"], run)
        _run_check(["rfkill", "list"], run)
        _run_check(["bluetoothctl", "show"], run)
        _run_check(["boltctl", "list"], run)

        # 5) Helpful next steps
        print("""
Next steps:
  • Wi-Fi: use 'nm-connection-editor' or the tray applet to join networks.
  • If Wi-Fi is soft-blocked:      rfkill unblock all

  • OpenVPN:
      - Import an .ovpn profile:    nmcli connection import type openvpn file <file.ovpn>
      - Or via GUI: Network Connections → + → Import VPN
      - Start:                      nmcli connection up <name>

  • WireGuard (NM-native):
      - Create from file:           nmcli connection import type wireguard file <wg.conf>
      - Or create new:              nmcli connection add type wireguard con-name <name> ifname <wg0> \
                                     ip4 <Address/CIDR> gw4 <Gateway>  # then nmcli con mod … for peers
      - Start:                      nmcli connection up <name>

  • Thunderbolt (secure mode):
      - Plug device →               boltctl list
      - Authorize/persist:          boltctl enroll <UUID>
Notes:
  - Do NOT enable iwd.service directly; NetworkManager manages iwd as the Wi-Fi backend.
  - 'bolt' is D-Bus activated; explicit service enable is unnecessary.
""".rstrip())

        print("✔ [150_network] Network stack configured.")
        return True

    except Exception as exc:
        print(f"ERROR: 150_network.install failed: {exc}")
        return False


--- modules/160_devtools/module.py ---
#!/usr/bin/env python3
"""
160_devtools — Containers (Podman + NVIDIA GPU) & Virtualization (QEMU/KVM)

What this module does
---------------------
- Installs handy hardware CLIs: usbutils (lsusb), pciutils (lspci)
- Sets up Podman for *rootless* containers and enables the **user** socket
  (Docker-API compatible via DOCKER_HOST). Handles headless/SSH sessions using:
  - `systemctl --user --machine nathan@.host ...` (preferred)
  - Fallback with explicit XDG/DBUS env for the user
  - Final fallback to *system* podman.socket (opt-in if user socket cannot be enabled)
- Adds NVIDIA Container Toolkit (CDI) so `podman run --gpus all ...` works
- Installs virtualization stack: qemu-desktop, libvirt, virt-manager, edk2-ovmf, dnsmasq
- Enables libvirtd, adds user to 'kvm' and 'libvirt', and autostarts the default libvirt NAT network

Idempotent & non-interactive by design. Uses the sudo-session `run` from utils.sudo_session.
"""

from __future__ import annotations

import getpass
import pwd
from typing import Callable, Iterable
from utils.pacman import install_packages


def _print_action(txt: str) -> None:
    print(f"$ {txt}")


def _run_ok(run: Callable, cmd: list[str]) -> bool:
    """Run a command via the sudo runner, print output, return True on rc==0."""
    _print_action(" ".join(cmd))
    res = run(cmd, check=False, capture_output=True)
    if res.stdout:
        print(res.stdout.rstrip())
    if res.stderr:
        print(res.stderr.rstrip())
    return res.returncode == 0


def _enable_units(run: Callable, units: Iterable[str]) -> bool:
    """Enable/start systemd system units."""
    for u in units:
        if not _run_ok(run, ["systemctl", "enable", "--now", u]):
            print(f"ERROR: failed to enable/start {u}")
            return False
    return True


def _add_user_to_groups(run: Callable, user: str, groups: Iterable[str]) -> None:
    """Best-effort user group membership (no hard failure if already a member)."""
    for g in groups:
        if not _run_ok(run, ["usermod", "-aG", g, user]):
            print(f"⚠️  could not add {user} to group '{g}' (may already be a member).")


def _enable_podman_user_socket(run: Callable, user: str) -> bool:
    """
    Enable the rootless Podman user socket for `user`, robust in headless/SSH sessions.
    Tries machine transport first, then an env-injected fallback. Returns True on success.
    """
    # Allow user manager to run outside of active logins
    _run_ok(run, ["loginctl", "enable-linger", user])

    # Preferred: systemd "machine" transport to the user's systemd
    if _run_ok(run, ["systemctl", "--user", "--machine", f"{user}@.host", "enable", "--now", "podman.socket"]):
        return True

    # Fallback: set XDG_RUNTIME_DIR + DBUS address for the target user and call systemctl --user
    uid = pwd.getpwnam(user).pw_uid
    xdg = f"/run/user/{uid}"
    env_line = f"XDG_RUNTIME_DIR={xdg} DBUS_SESSION_BUS_ADDRESS=unix:path={xdg}/bus"
    cmd = ["runuser", "-l", user, "-c", f"{env_line} systemctl --user enable --now podman.socket"]
    if _run_ok(run, cmd):
        return True

    return False


def install(run: Callable) -> bool:
    print("▶ [160_devtools] Podman (rootless + GPU) & QEMU/KVM/libvirt setup")

    user = getpass.getuser()

    # 0) Ensure handy hardware CLIs (you were missing lsusb earlier)
    if not install_packages(["usbutils", "pciutils"], run):
        return False

    # 1) Podman (rootless) & compose helper
    if not install_packages(["podman", "podman-compose"], run):
        return False

    if not _enable_podman_user_socket(run, user):
        print("❌ Could not enable user-level podman.socket.")
        # Optional fallback to system-level podman socket to avoid hard failure:
        print("⚠️  Falling back to system-level podman.socket (/run/podman/podman.sock).")
        if not _enable_units(run, ["podman.socket"]):
            print("❌ Failed to enable system-level podman.socket as well.")
            return False
        print("ℹ️  For Docker-API clients, use: DOCKER_HOST=unix:///run/podman/podman.sock")
    else:
        print("✔ Rootless Podman user socket enabled.")
        print("ℹ️  For Docker-API clients, use: DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock")

    # 2) GPU in containers: NVIDIA Container Toolkit (CDI)
    if not install_packages(["nvidia-container-toolkit"], run):
        return False
    print("✔ NVIDIA Container Toolkit installed (CDI).")
    print("   Test: podman run --rm --gpus all nvidia/cuda:12.4.1-base-archlinux nvidia-smi")

    # 3) Virtualization: QEMU/KVM + libvirt + virt-manager + OVMF + NAT
    if not install_packages(["qemu-desktop", "libvirt", "virt-manager", "edk2-ovmf", "dnsmasq"], run):
        return False

    if not _enable_units(run, ["libvirtd.service"]):
        return False

    # Add user to groups for device/session access
    _add_user_to_groups(run, user, ["kvm", "libvirt"])

    # Start & autostart default NAT network (best-effort; ignore failures if it exists)
    _print_action("virsh net-start default  # best-effort")
    run(["virsh", "net-start", "default"], check=False, capture_output=True)
    _print_action("virsh net-autostart default")
    run(["virsh", "net-autostart", "default"], check=False, capture_output=True)

    print("✔ [160_devtools] Complete. You may need to log out/in for new group membership to take effect.")
    return True


--- modules/200_display-server/module.py ---
#!/usr/bin/env python3
"""
200_display-server — Minimal Xorg base + NVIDIA KMS (hybrid Intel + NVIDIA)

What this module does
---------------------
- Installs a minimal Xorg server stack (no legacy xf86-video-intel).
- Enables DRM KMS for NVIDIA (modeset=1) via a modprobe drop-in.
- Adds a safe Xorg OutputClass snippet for PRIME render offload that
  keeps the Intel iGPU as primary and uses NVIDIA via `prime-run`.

Idempotency & Safety
--------------------
- Package installs are via utils.pacman.install_packages (uses --needed).
- Config files are written atomically and can be re-run safely.
- Does NOT enable or configure a login manager; that's 210_login-manager.
"""

from __future__ import annotations
from typing import Callable

from utils.pacman import install_packages

# ---- toggles ---------------------------------------------------------------

# Write /etc/X11/xorg.conf.d/10-nvidia-offload.conf (recommended)
WRITE_XORG_NVIDIA_SNIPPET = True

# Only set DRM KMS via modprobe drop-in (recommended).
# If you prefer also setting a kernel cmdline (GRUB), do that in 210_login-manager or manually.
WRITE_NVIDIA_KMS_MODPROBE = True

# ---- config content --------------------------------------------------------

NVIDIA_KMS_MODPROBE_PATH = "/etc/modprobe.d/nvidia-drm-modeset.conf"
NVIDIA_KMS_MODPROBE_CONTENT = """# Enable DRM KMS for NVIDIA (Wayland & better Xorg modesetting)
options nvidia_drm modeset=1
"""

XORG_SNIPPET_PATH = "/etc/X11/xorg.conf.d/10-nvidia-offload.conf"
XORG_SNIPPET_CONTENT = r"""# Keep Intel iGPU as primary; use NVIDIA for PRIME render offload via `prime-run`.
Section "OutputClass"
    Identifier "nvidia"
    MatchDriver "nvidia-drm"
    Driver "nvidia"
    Option "AllowEmptyInitialConfiguration"
    Option "PrimaryGPU" "no"
    # Ensure NVIDIA Xorg modules are visible (Arch standard paths)
    ModulePath "/usr/lib/nvidia/xorg"
    ModulePath "/usr/lib/xorg/modules"
EndSection
"""

# ---- helpers ---------------------------------------------------------------

def _write_file(run: Callable, path: str, content: str, mode: str = "0644") -> bool:
    """Atomically create/update a root-owned file via install -D."""
    try:
        print(f"$ install -D -m {mode} /dev/stdin {path}")
        res = run(["install", "-D", "-m", mode, "/dev/stdin", path],
                  check=False, capture_output=True, input_text=content)
        if res.stdout: print(res.stdout.rstrip())
        if res.stderr: print(res.stderr.rstrip())
        return res.returncode == 0
    except Exception as exc:
        print(f"ERROR: writing {path}: {exc}")
        return False


def _ensure_dir(run: Callable, path: str) -> bool:
    res = run(["mkdir", "-p", path], check=False, capture_output=True)
    if res.returncode != 0:
        if res.stdout: print(res.stdout.rstrip())
        if res.stderr: print(res.stderr.rstrip())
        return False
    return True


# ---- main ------------------------------------------------------------------

def install(run: Callable) -> bool:
    try:
        print("▶ [200_display-server] Installing minimal Xorg + NVIDIA KMS baseline…")

        # 1) Minimal Xorg base (no xf86-video-intel; use modesetting)
        pkgs = [
            "xorg-server",
            "xorg-xinit",
            "xorg-xrandr",
            "xorg-xauth",   # small but handy (X11 auth forwarding)
            "xorg-xset",    # utility; harmless
        ]
        if not install_packages(pkgs, run):
            return False

        # 2) NVIDIA DRM KMS via modprobe (safe, reversible)
        if WRITE_NVIDIA_KMS_MODPROBE:
            if not _write_file(run, NVIDIA_KMS_MODPROBE_PATH, NVIDIA_KMS_MODPROBE_CONTENT):
                return False

        # 3) Xorg PRIME offload snippet (keeps Intel primary)
        if WRITE_XORG_NVIDIA_SNIPPET:
            if not _ensure_dir(run, "/etc/X11/xorg.conf.d"):
                return False
            if not _write_file(run, XORG_SNIPPET_PATH, XORG_SNIPPET_CONTENT):
                return False

        print("✔ [200_display-server] Display server baseline is in place.")

        # 4) Tips / verification (non-fatal)
        print("""
Next steps / verification:
  • Reboot (or reload modules) so NVIDIA DRM KMS takes effect.
  • After logging into X11:
      - Offload test:     prime-run glxinfo | grep "OpenGL renderer"
      - Providers:        xrandr --listproviders
  • Wayland later (optional): with modeset=1 set, most compositors will work better on NVIDIA.
Notes:
  - Display manager (LightDM/SDDM/GDM) is handled in 210_login-manager.
  - Window manager/DE (i3/sway/...) is handled in 220_window-manager.
""".rstrip())
        return True

    except Exception as exc:
        print(f"ERROR: 200_display-server.install failed: {exc}")
        return False


--- modules/210_login_manager/module.py ---
"""
210_login_manager/module.py

Set up SDDM as the display/login manager.

- Installs sddm (Qt6 build).
- Enables it as a system service.
- Deploys a custom theme if present under modules/210_login_manager/theme/
- Configures /etc/sddm.conf.d/10-theme.conf to point at that theme if deployed.

Notes:
- Enabling the service is safe while you're in a running session; it just takes effect on next boot.
"""

import shutil
from pathlib import Path
from typing import Callable

from utils.pacman import install_packages

THEME_SRC = Path(__file__).parent / "theme"
THEME_DST = Path("/usr/share/sddm/themes")
CONF_DIR = Path("/etc/sddm.conf.d")
CONF_FILE = CONF_DIR / "10-theme.conf"

SDDM_CONF_CONTENT = """[Theme]
Current=arch-bootstrap
"""

def _print_action(msg: str) -> None:
    print(f"$ {msg}")

def _run_ok(run: Callable, cmd: list[str], input_text: str | None = None) -> bool:
    """
    Run a command via the sudo runner. The sudo runner expects 'input_text'
    and already sets text=True internally.
    """
    try:
        result = run(cmd, check=False, capture_output=True, input_text=input_text)
        if result.returncode != 0:
            # Prefer stderr if available, otherwise a generic failure line.
            print(result.stderr or f"Command failed: {' '.join(cmd)}")
            return False
        # Surface stdout/stderr for visibility on success too (they may contain useful info).
        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            print(result.stderr.rstrip())
        return True
    except Exception as e:
        print(f"ERROR running {' '.join(cmd)}: {e}")
        return False

def _backup_then_replace_theme(run: Callable) -> bool:
    if not THEME_SRC.exists() or not THEME_SRC.is_dir():
        print(f"ℹ️  Theme source not found: {THEME_SRC}")
        print("    Skipping theme deployment; SDDM will use its default theme.")
        return True

    dst = THEME_DST / "arch-bootstrap"
    if dst.exists():
        backup = dst.with_suffix(".bak")
        _print_action(f"Backing up existing theme at {dst} -> {backup}")
        run(["cp", "-a", str(dst), str(backup)], check=False)

    _print_action(f"Installing custom theme -> {dst}")
    try:
        run(["mkdir", "-p", str(THEME_DST)], check=False)
        run(["cp", "-a", str(THEME_SRC), str(dst)], check=False)
        return True
    except Exception as e:
        print(f"ERROR copying theme: {e}")
        return False

def _write_conf(run: Callable) -> bool:
    _print_action(f"install -Dm0644 /dev/stdin {CONF_FILE}")
    return _run_ok(
        run,
        ["install", "-Dm0644", "/dev/stdin", str(CONF_FILE)],
        input_text=SDDM_CONF_CONTENT,
    )

def install(run: Callable) -> bool:
    # 1) Install sddm
    if not install_packages(["sddm"], run):
        return False

    # 2) Enable service (safe to do while a session is running; it activates on next boot)
    _print_action("systemctl enable sddm.service")
    run(["systemctl", "enable", "sddm.service"], check=False)

    # 3) Deploy theme (optional)
    if not _backup_then_replace_theme(run):
        print("ERROR: Failed during theme deployment step.")
        return False

    # 4) Write authoritative theme drop-in only if theme was actually deployed
    theme_installed = (THEME_DST / "arch-bootstrap").exists()
    if theme_installed:
        if not _write_conf(run):
            print("ERROR: Failed to write SDDM theme drop-in.")
            return False
    else:
        print("ℹ️  No custom theme present; skipping /etc/sddm.conf.d/10-theme.conf write.")

    return True


--- modules/220_window_manager/module.py ---
#!/usr/bin/env python3
"""
220_window_manager — i3 on X11 (with rofi, picom, dunst, polkit agent)

What this module does
---------------------
- Installs a standard i3 X11 stack:
  * Core: i3-wm, i3status
  * Launcher: rofi
  * Lock/idle helpers: i3lock, xss-lock, xorg-xset
  * UX: picom (compositor), dunst (notifications), feh (wallpaper), arandr (displays), xclip (clipboard)
  * QoL: playerctl, brightnessctl, flameshot, lxappearance
  * Polkit agent: polkit-gnome
- Prints post-install tips and quick tests.
- Does NOT write per-user config and does NOT touch display manager services.

Idempotency & Safety
--------------------
- Pacman installs via utils.pacman.install_packages (uses --needed).
- No service changes here (210_login_manager handles DM).
- No writes to $HOME or /etc configs for i3/rofi/picom/dunst (leave to 4xx dotfiles).

i3 config snippet (put this in your dotfiles, e.g. ~/.config/i3/config)
-----------------------------------------------------------------------
# Launcher
bindsym $mod+d exec rofi -show drun

# Idle + lock (example timings)
exec --no-startup-id xset s 300 60
exec --no-startup-id xset +dpms
exec --no-startup-id xss-lock -n /usr/share/doc/xss-lock/dim-screen.sh -- i3lock -n

# Compositor, notifications, polkit agent
exec --no-startup-id picom --experimental-backends
exec --no-startup-id dunst
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# QoL helpers (optional binds)
# bindsym XF86AudioPlay exec playerctl play-pause
# bindsym XF86MonBrightnessUp exec brightnessctl set +5%
# bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
# bindsym $mod+Print exec flameshot gui
"""

from __future__ import annotations
from typing import Callable, Iterable
import subprocess

from utils.pacman import install_packages


# ------------------------------- helpers -------------------------------------

def _print(msg: str) -> None:
    print(msg)


def _run_user(cmd: Iterable[str]) -> None:
    """Run a harmless command as the invoking user (no sudo)."""
    _print("$ " + " ".join(cmd))
    try:
        res = subprocess.run(list(cmd), check=False, text=True, capture_output=True)
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
    except Exception as exc:
        print(f"⚠️  Skipping user command {' '.join(cmd)}: {exc}")


def _check_presence() -> None:
    """Best-effort visibility: show versions and presence of key tools."""
    _run_user(["bash", "-lc", "i3 --version || true"])
    _run_user(["bash", "-lc", "rofi -v || true"])
    _run_user(["bash", "-lc", "command -v i3lock >/dev/null 2>&1 && echo 'i3lock present' || echo 'i3lock missing'"])
    _run_user(["bash", "-lc", "command -v xss-lock >/dev/null 2>&1 && echo 'xss-lock present' || echo 'xss-lock missing'"])
    _run_user(["bash", "-lc", "command -v picom >/dev/null 2>&1 && echo 'picom present' || echo 'picom missing'"])
    _run_user(["bash", "-lc", "command -v dunst >/dev/null 2>&1 && echo 'dunst present' || echo 'dunst missing'"])
    _run_user(["bash", "-lc", "command -v xset  >/dev/null 2>&1 && echo 'xset present'  || echo 'xset missing'"])
    _run_user(["bash", "-lc", "command -v playerctl >/dev/null 2>&1 && echo 'playerctl present' || echo 'playerctl missing'"])
    _run_user(["bash", "-lc", "command -v brightnessctl >/dev/null 2>&1 && echo 'brightnessctl present' || echo 'brightnessctl missing'"])
    _run_user(["bash", "-lc", "command -v flameshot >/dev/null 2>&1 && echo 'flameshot present' || echo 'flameshot missing'"])
    _run_user(["bash", "-lc", "command -v lxappearance >/dev/null 2>&1 && echo 'lxappearance present' || echo 'lxappearance missing'"])
    _run_user(["bash", "-lc", "command -v /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 && echo 'polkit-gnome agent present' || echo 'polkit-gnome agent missing'"])


# ------------------------------- main ----------------------------------------

def install(run: Callable) -> bool:
    try:
        _print("▶ [220_window_manager] Installing i3 (X11) stack + helpers…")

        pkgs = [
            # Core WM stack
            "i3-wm",
            "i3status",

            # Launcher
            "rofi",

            # Lock / idle helpers
            "i3lock",
            "xss-lock",
            "xorg-xset",

            # UX & compositor & utilities
            "picom",
            "dunst",
            "feh",
            "arandr",
            "xclip",

            # QoL
            "playerctl",
            "brightnessctl",
            "flameshot",
            "lxappearance",

            # Polkit agent for GUI auth prompts
            "polkit-gnome",
        ]

        if not install_packages(pkgs, run):
            _print("❌ [220_window_manager] Package installation failed.")
            return False

        # Session integration: i3 desktop file is provided by i3-wm under /usr/share/xsessions/i3.desktop.
        _print("ℹ️  i3 session installed. Your display manager (e.g., SDDM) should list 'i3' as a session option.")

        # Best-effort diagnostics (non-fatal)
        _check_presence()

        # Tips
        _print("""
Tips:
  • Add the autostart lines to your i3 config (~/.config/i3/config), see the snippet in this file header.
  • Test locker after starting xss-lock via your i3 autostart:
      $ xset s activate
  • i3 reload/restart:
      $ i3-msg reload
      $ i3-msg restart
  • In your display manager, select the 'i3' session at login.
""".rstrip())

        _print("✔ [220_window_manager] i3 window manager stack is ready (no user config written).")
        return True

    except Exception as exc:
        print(f"ERROR: 220_window_manager.install failed: {exc}")
        return False


--- modules/230_panels-bars/module.py ---
#!/usr/bin/env python3
"""
230_panels-bars — Polybar for i3 (X11)

What this module does
---------------------
- Installs Polybar and sensors tooling (for temperature modules).
- Prints non-fatal diagnostics and tips to wire Polybar into i3.
- Does NOT write user config (leave to your 4xx dotfiles).

Why this module is minimal
--------------------------
Polybar ships a default system config at /etc/polybar/config.ini that works out of the box.
Your personal config should live at ~/.config/polybar/config.ini and will override the system one.

Copy/paste: ~/.config/polybar/config.ini (basic bar with i3, battery, temps, clock)
-----------------------------------------------------------------------------------
; Minimal example. Adjust names after checking:
;   $ ls -1 /sys/class/power_supply/         # e.g. BAT0, ADP1 (or AC)
;   $ sensors                                # see which thermal zones are valid

[colors]
background = #AA1E1E2E
foreground = #D9D9D9
primary    = #89B4FA
warning    = #F9E2AF
critical   = #F38BA8

[bar/main]
width = 100%
height = 28
background = ${colors.background}
foreground = ${colors.foreground}
font-0 = JetBrainsMono Nerd Font:style=Regular:size=10;2
padding-left = 1
padding-right = 1
module-margin = 2
enable-ipc = true
cursor-click = pointer
cursor-scroll = ns-resize
; uncomment for tray support if desired:
; tray-position = right
; tray-maxsize = 20

modules-left  = i3
modules-center =
modules-right = temperature battery date

[module/i3]
type = internal/i3
format = <label-state> <label-mode>
label-focused = %name%
label-focused-foreground = ${colors.primary}
label-unfocused = %name%
label-visible = %name%
label-urgent = %name%
; show only non-empty workspaces:
index-sort = true
wrapping-scroll = false
pin-workspaces = true

[module/battery]
type = internal/battery
battery = BAT0
adapter = ADP1
full-at = 98
format-charging =   <animation-charging> <label-charging>
format-discharging =   <ramp-capacity> <label-discharging>
format-full =   <label-full>
ramp-capacity-0 = 
ramp-capacity-1 = 
ramp-capacity-2 = 
ramp-capacity-3 = 
ramp-capacity-4 = 
animation-charging-0 = 
animation-charging-1 = 
animation-charging-2 = 
animation-charging-3 = 
animation-charging-4 = 
animation-charging-framerate = 750

[module/temperature]
type = internal/temperature
; EITHER set thermal-zone OR a specific hwmon path. Start with thermal-zone:
thermal-zone = 0
warn-temperature = 80
format =   <label>
format-warn =   <label-warn>
label = %temperature-c%°C
label-warn = %temperature-c%°C
label-warn-foreground = ${colors.warning}

[module/date]
type = internal/date
interval = 1
time = %Y-%m-%d %H:%M:%S
format =   <label>
label = %time%

Copy/paste: ~/.config/polybar/launch.sh (spawn per monitor)
-----------------------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

killall -q polybar || true
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/polybar/config.ini"

if command -v polybar >/dev/null 2>&1; then
  if [ -f "$CONFIG" ]; then
    for m in $(polybar -m | cut -d: -f1); do
      MONITOR="$m" polybar -q main -c "$CONFIG" &
    done
  else
    # fallback: run with the system config so you at least get a bar
    for m in $(polybar -m | cut -d: -f1); do
      MONITOR="$m" polybar -q main -c /etc/polybar/config.ini &
    done
  fi
fi

Make executable:
  chmod +x ~/.config/polybar/launch.sh

i3 autostart (add to your i3 config)
------------------------------------
exec_always --no-startup-id ~/.config/polybar/launch.sh

Notes
-----
- If you used i3bar before, comment out any `bar { ... }` block in your i3 config.
- Temperature source can differ per hardware; use `sensors` and adjust `thermal-zone`
  or set an explicit `hwmon-path = /sys/class/hwmon/hwmonX/temp1_input`.
"""

from __future__ import annotations
from typing import Callable, Iterable
import subprocess

from utils.pacman import install_packages


def _print(msg: str) -> None:
    print(msg)


def _run_user(cmd: Iterable[str]) -> None:
    """Run a harmless command as the invoking user (no sudo)."""
    _print("$ " + " ".join(cmd))
    try:
        res = subprocess.run(list(cmd), check=False, text=True, capture_output=True)
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
    except Exception as exc:
        print(f"⚠️  Skipping user command {' '.join(cmd)}: {exc}")


def _diagnostics() -> None:
    """Best-effort visibility & guidance."""
    _run_user(["bash", "-lc", "polybar -vvv | sed -n '1,40p' || true"])
    _run_user(["bash", "-lc", "echo 'Detected monitors:' && polybar -m || true"])
    _run_user(["bash", "-lc", "test -f /etc/polybar/config.ini && echo '/etc/polybar/config.ini exists' || echo 'system config missing'"])
    _run_user(["bash", "-lc", "command -v sensors >/dev/null 2>&1 && sensors || echo 'Run `sudo sensors-detect` to improve temperature readings'"])


def install(run: Callable) -> bool:
    try:
        _print("▶ [230_panels-bars] Installing Polybar + sensors tooling…")

        # Core bar + sensors for temperature module
        pkgs = [
            "polybar",
            "lm_sensors",   # for `sensors` and improved temp visibility
            # Optional helper for quick battery/AC debugging (not required by Polybar):
            # "acpi",
        ]

        if not install_packages(pkgs, run):
            _print("❌ [230_panels-bars] Package installation failed.")
            return False

        _print("ℹ️  Polybar installed. Default system config: /etc/polybar/config.ini")
        _print("ℹ️  Personal config (overrides system): ~/.config/polybar/config.ini")
        _print("ℹ️  Tip: Run `sudo sensors-detect` once, then `sensors` to verify temp inputs.")

        # Non-fatal checks
        _diagnostics()

        _print("""
Tips:
  • Create ~/.config/polybar/config.ini using the snippet in this file's header (battery, temp, date).
  • Create ~/.config/polybar/launch.sh (also in header), then:
      chmod +x ~/.config/polybar/launch.sh
  • Add to i3 config:
      exec_always --no-startup-id ~/.config/polybar/launch.sh
  • If using i3bar previously: comment out any `bar { ... }` block in your i3 config.
""".rstrip())

        _print("✔ [230_panels-bars] Polybar ready (no user config written).")
        return True

    except Exception as exc:
        print(f"ERROR: 230_panels-bars.install failed: {exc}")
        return False


--- modules/240_themeing/module.py ---
#!/usr/bin/env python3
"""
240_themeing — Dark theme baseline (Nord-centric) — FIXED:
- Install Bibata cursor from AUR (not pacman).
- Fall back to Adwaita cursor if Bibata not present (no hard fail).
"""

from __future__ import annotations
from typing import Callable, Optional
import shlex

from utils.pacman import install_packages as pacman_install
try:
    from utils.yay import install_packages as yay_install
except Exception:
    yay_install = None  # yay optional

GTK_THEME_NAME = "Nordic"                   # AUR: nordic-theme
ICON_THEME_NAME = "Papirus-Dark"            # repo: papirus-icon-theme
CURSOR_THEME_NAME = "Bibata-Modern-Ice"     # AUR: bibata-cursor-theme
CURSOR_FALLBACK = "Adwaita"                 # safe fallback if Bibata missing
QT_STYLE = "kvantum"
KVANTUM_THEME_NAME = "Nordic-Darker"        # AUR: kvantum-theme-nordic
GTK_FALLBACK_THEME = "Adwaita-dark"         # repo fallback if Nordic missing

def _run_ok(run: Callable, cmd: list[str], *, input_text: Optional[str] = None) -> bool:
    print("$ " + " ".join(shlex.quote(c) for c in cmd))
    res = run(cmd, check=False, capture_output=True, input_text=input_text)
    if res.stdout: print(res.stdout.rstrip())
    if res.stderr: print(res.stderr.rstrip())
    return res.returncode == 0

def _write_file(run: Callable, path: str, content: str) -> bool:
    return _run_ok(run, ["install", "-Dm0644", "/dev/stdin", path], input_text=content)

def _path_exists(run: Callable, path: str) -> bool:
    return run(["test", "-e", path], check=False).returncode == 0

# ---------- config writers ----------

def _apply_gtk_defaults(run: Callable, gtk_theme_name: str) -> bool:
    gtk = f"""[Settings]
gtk-theme-name={gtk_theme_name}
gtk-icon-theme-name={ICON_THEME_NAME}
gtk-application-prefer-dark-theme=1
"""
    return _write_file(run, "/etc/gtk-3.0/settings.ini", gtk) and \
           _write_file(run, "/etc/gtk-4.0/settings.ini", gtk)

def _apply_cursor_default(run: Callable, cursor_name: str) -> bool:
    index_theme = f"""[Icon Theme]
Inherits={cursor_name}
"""
    return _write_file(run, "/usr/share/icons/default/index.theme", index_theme)

def _apply_qt_defaults(run: Callable, kvantum_available: bool) -> bool:
    style = QT_STYLE if kvantum_available else "Fusion"
    qt_common = f"""[Appearance]
style={style}
icon_theme={ICON_THEME_NAME}
"""
    return _write_file(run, "/etc/xdg/qt5ct/qt5ct.conf", qt_common) and \
           _write_file(run, "/etc/xdg/qt6ct/qt6ct.conf", qt_common)

def _apply_kvantum_theme(run: Callable, theme_name: str) -> bool:
    # Require engine AND theme presence to write config; otherwise skip silently.
    engine_present = _path_exists(run, "/usr/bin/kvantummanager") or \
                     _path_exists(run, "/usr/lib/qt/plugins/styles/libkvantum.so")
    theme_present = _path_exists(run, f"/usr/share/Kvantum/{theme_name}")
    if not (engine_present and theme_present):
        return True
    kv_cfg = f"[General]\ntheme={theme_name}\n"
    return _write_file(run, "/etc/xdg/Kvantum/kvantum.kvconfig", kv_cfg)

# ---------- installs ----------

def _install_repo_packages(run: Callable) -> bool:
    pkgs = [
        "papirus-icon-theme",    # icons (repo)
        # cursor moved to AUR
        "qt5ct", "qt6ct", "kvantum",
        "gtk-engine-murrine",
    ]
    return pacman_install(pkgs, run)

def _install_aur_packages() -> bool:
    if yay_install is None:
        print("⚠️  'yay' not available; skipping AUR themes (Nordic, Bibata, Kvantum Nordic).")
        return True  # non-fatal; we’ll fall back where needed
    pkgs = [
        "nordic-theme",            # GTK Nord
        "bibata-cursor-theme",     # Bibata cursor (AUR)
        "kvantum-theme-nordic",    # Kvantum Nord
    ]
    return yay_install(pkgs)

def install(run: Callable) -> bool:
    try:
        print("▶ [240_themeing] Applying system dark theme defaults (Nord-centric)…")

        if not _install_repo_packages(run):
            print("❌ Failed installing base theming packages from repos.")
            return False

        if not _install_aur_packages():
            print("⚠️  AUR theming packages failed to install. Continuing with fallbacks.")

        kvantum_available = _path_exists(run, "/usr/share/Kvantum") or \
                            _path_exists(run, "/usr/lib/qt/plugins/styles/libkvantum.so")

        # Choose GTK theme based on presence; fallback to repo theme if AUR Nordic missing
        nordic_present = _path_exists(run, "/usr/share/themes/Nordic")
        gtk_to_set = GTK_THEME_NAME if nordic_present else GTK_FALLBACK_THEME
        if not _apply_gtk_defaults(run, gtk_theme_name=gtk_to_set):
            print("❌ Failed writing GTK defaults.")
            return False

        # Cursor: prefer Bibata if installed, otherwise fallback to Adwaita
        bibata_present = _path_exists(run, f"/usr/share/icons/{CURSOR_THEME_NAME}")
        cursor_to_set = CURSOR_THEME_NAME if bibata_present else CURSOR_FALLBACK
        if not bibata_present:
            print(f"⚠️  Bibata cursor not found in /usr/share/icons; using fallback cursor: {CURSOR_FALLBACK}")
        if not _apply_cursor_default(run, cursor_to_set):
            print("❌ Failed setting system cursor default.")
            return False

        # Qt defaults + optional Kvantum theme
        if not _apply_qt_defaults(run, kvantum_available=kvantum_available):
            print("❌ Failed writing Qt defaults.")
            return False
        _apply_kvantum_theme(run, KVANTUM_THEME_NAME)

        # Visibility (non-fatal)
        _run_ok(run, ["bash", "-lc", "echo GTK3 -> && cat /etc/gtk-3.0/settings.ini || true"])
        _run_ok(run, ["bash", "-lc", "echo GTK4 -> && cat /etc/gtk-4.0/settings.ini || true"])
        _run_ok(run, ["bash", "-lc", "echo Cursor -> && cat /usr/share/icons/default/index.theme || true"])
        _run_ok(run, ["bash", "-lc", "echo qt5ct -> && cat /etc/xdg/qt5ct/qt5ct.conf || true"])
        _run_ok(run, ["bash", "-lc", "echo qt6ct -> && cat /etc/xdg/qt6ct/qt6ct.conf || true"])

        print("""
Tips:
  • If Bibata didn’t install, run:  yay -S bibata-cursor-theme
    Then re-run this module to switch system cursor to Bibata.
  • Papirus icons & Kvantum engine are from official repos.
  • Per-user fine-tuning (recommended):
      ~/.config/gtk-3.0/settings.ini, ~/.config/gtk-4.0/settings.ini
      ~/.config/qt5ct/qt5ct.conf, ~/.config/qt6ct/qt6ct.conf
      ~/.config/Kvantum/kvantum.kvconfig
""".rstrip())

        print("✔ [240_themeing] Dark theme defaults applied (with safe fallbacks).")
        return True

    except Exception as exc:
        print(f"ERROR: 240_themeing.install failed: {exc}")
        return False


--- utils/module_loader.py ---
# utils/module_loader.py
# utils/module_loader.py
#!/usr/bin/env python3
"""
Module Discovery and Runner
Version: 2.0.0

What the module does
--------------------
- Discovers `module.py` files inside ./modules/* folders that start with a
  numeric order prefix (e.g., 00_core, 10_fonts).
- Validates there are no duplicate order numbers (strictly enforced).
- Imports each module safely, and sequentially calls its `install(run)` function.

Behavior
--------
- Prints shell-like actions and status markers.
- Robust error handling: continues discovery despite individual import issues,
  aborts run if duplicate orders are detected, stops on the first install failure.
- Returns True if all ran successfully, False otherwise.
"""

from __future__ import annotations
import importlib.util
import sys
from pathlib import Path
from typing import List, Tuple, Any, Dict, Optional

MODULES_DIR = Path(__file__).resolve().parent.parent / "modules"


def _print_action(text: str) -> None:
    """Print a shell-like action line."""
    print(f"$ {text}")


def _parse_order(folder_name: str) -> Optional[int]:
    """
    Extract the numeric order prefix from a folder name like '10_fonts'.

    Returns:
        The integer order, or None if the name doesn't start with a number.
    """
    try:
        return int(folder_name.split("_", 1)[0])
    except (ValueError, IndexError):
        return None


def discover_modules() -> List[Tuple[int, str, Any]]:
    """
    Discover and import all `module.py` files under `modules/`.

    Returns:
        A list of (order_number, folder_name, imported_module), sorted by order ASC.

    Notes:
        - Duplicate order numbers are NOT filtered here—use `validate_no_duplicates`
          before running to enforce uniqueness.
        - Import errors are reported but do not stop discovery of other modules.
    """
    discovered: List[Tuple[int, str, Any]] = []

    if not MODULES_DIR.exists():
        print(f"⚠️  Modules directory not found: {MODULES_DIR}")
        return discovered

    for folder in MODULES_DIR.iterdir():
        if not folder.is_dir():
            continue

        order = _parse_order(folder.name)
        if order is None:
            # Skip folders without a numeric prefix
            continue

        module_file = folder / "module.py"
        if not module_file.exists():
            print(f"⚠️  [{folder.name}] Skipping: module.py not found.")
            continue

        module_name = f"modules.{folder.name}"
        try:
            _print_action(f"import {module_name}  # from {module_file}")
            spec = importlib.util.spec_from_file_location(module_name, module_file)
            if spec is None or spec.loader is None:
                print(f"⚠️  Could not load spec for {module_file}")
                continue

            mod = importlib.util.module_from_spec(spec)
            sys.modules[module_name] = mod
            spec.loader.exec_module(mod)  # noqa: S102 - trusted local file
            discovered.append((order, folder.name, mod))
        except Exception as exc:
            print(f"ERROR: Failed to import {module_file}: {exc}")
            continue

    discovered.sort(key=lambda t: t[0])
    return discovered


def validate_no_duplicates(discovered: List[Tuple[int, str, Any]]) -> bool:
    """
    Check for duplicate order numbers.

    Arguments:
        discovered: Output from `discover_modules()`.

    Returns:
        True if no duplicates, False otherwise (and prints diagnostics).
    """
    by_order: Dict[int, List[str]] = {}
    for order, name, _ in discovered:
        by_order.setdefault(order, []).append(name)

    duplicates = {k: v for k, v in by_order.items() if len(v) > 1}
    if duplicates:
        print("❌ Duplicate module order numbers detected. Aborting without running any modules.")
        for order, names in sorted(duplicates.items()):
            print(f"   - {order}: {', '.join(sorted(names))}")
        return False
    return True


def run_all(run_callable) -> bool:
    """
    Discover modules, ensure unique order numbers, and call `install(run_callable)`
    on each module in order.

    Arguments:
        run_callable:
            The sudo-runner returned by `start_sudo_session()`.

    Returns:
        True if all modules ran successfully, False otherwise.

    Behavior:
        - If duplicates are detected, nothing is run and False is returned.
        - Stops on the first install() failure to avoid partial configuration.
        - Modules without an `install` callable are skipped with a warning.
    """
    try:
        discovered = discover_modules()

        if not validate_no_duplicates(discovered):
            return False  # Do not run anything when duplicates exist.

        for order, name, mod in discovered:
            fn = getattr(mod, "install", None)
            if callable(fn):
                print(f"▶ [{order}] Running {name}.install()")
                ok = False
                try:
                    ok = bool(fn(run_callable))
                except Exception as exc:
                    print(f"ERROR: Exception while running {name}.install(): {exc}")
                    ok = False

                if not ok:
                    print(f"❌ Stopping: {name}.install() reported failure.")
                    return False
                print(f"✔ [{order}] {name}.install() completed.")
            else:
                print(f"⚠️  [{order}] Skipping {name}: no callable install() found.")
        return True
    except Exception as exc:
        print(f"ERROR: Unexpected failure in run_all(): {exc}")
        return False


--- utils/pacman.py ---
# utils/pacman.py
#!/usr/bin/env python3
"""
Pacman install helper that uses a provided sudo session runner.
Version: 2.0.0

What the module does
--------------------
Provides a tiny, safe wrapper to install packages with the Arch `pacman`
package manager. It **expects** you to pass the `run` function returned by
`utils.sudo_session.start_sudo_session()`, so all commands are executed with
root privileges via `sudo -n`.

Key behavior
------------
- Uses: pacman -S --needed --noconfirm <packages...>
  * `--needed` makes the operation idempotent (already-installed packages are skipped).
- Prints shell-like actions before running, surfaces useful output on success/failure.
- Robust error handling: exceptions are caught, clear messages are printed,
  and the function returns `True` (success) or `False` (failure).

Public API
----------
install_packages(packages: list[str], run: Callable) -> bool
    Install one or more packages using the provided sudo runner.

Example
-------
from utils.sudo_session import start_sudo_session
from utils.pacman import install_packages

run, close = start_sudo_session()
try:
    ok = install_packages(["git", "vim"], run)
    if not ok:
        print("Failed to install required packages")
finally:
    close()
"""

from typing import List, Callable
import sys


def _print_action(cmd: str) -> None:
    print(f"$ {cmd}")


def _print_error(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)


def _join(cmd: List[str]) -> str:
    return " ".join(cmd)


def install_packages(packages: List[str], run: Callable) -> bool:
    """
    Install the given packages with pacman if not already present.

    Uses --needed and --noconfirm. Runs pacman under the provided `run`
    (which already wraps sudo).
    """
    if not packages:
        return True

    cleaned = [pkg.strip() for pkg in packages if pkg and pkg.strip()]
    if not cleaned:
        return True

    cmd = ["pacman", "-S", "--needed", "--noconfirm", *cleaned]
    _print_action(_join(cmd))

    # Capture output so we can show diagnostics if it fails.
    result = run(cmd, check=False, capture_output=True)

    if result.returncode != 0:
        _print_error("pacman failed with a non-zero exit status.")
        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            _print_error(result.stderr.rstrip())
        return False

    # On success, pacman usually prints progress bars directly; stdout/stderr
    # may be empty. We don’t spam unless something is useful.
    if result.stdout:
        print(result.stdout.rstrip())
    if result.stderr:
        # pacman sometimes warns to stderr even on success
        print(result.stderr.rstrip(), file=sys.stderr)

    return True


--- utils/sudo_session.py ---
# utils/sudo_session.py
#!/usr/bin/env python3
"""
Sudo Session Manager (Keep-Alive)
Version: 2.0.0

What the module does
--------------------
Creates a safe, short-lived sudo "session" without holding your password in
memory. It:

1) Prompts once for your password and seeds sudo's timestamp cache (`sudo -S -v`).
2) Starts a background thread to refresh the timestamp (`sudo -n -v`) periodically.
3) Exposes a `run(cmd, ...)` callable that executes commands as root using `sudo -n`.
4) Exposes a `close()` callable that stops the keep-alive and clears credentials.

Design notes
------------
- The password is only passed to `sudo -S -v` and then discarded immediately.
- All subsequent calls use `-n` (non-interactive). If the timestamp expires,
  commands will fail instead of blocking for a password.
"""

from __future__ import annotations

import atexit
import getpass
import subprocess
import threading
from typing import Iterable, Optional


def _print_action(text: str) -> None:
    """Print a shell-like action description."""
    print(f"$ {text}")


def _seed_sudo_timestamp() -> bool:
    """
    Prompt once and seed sudo's timestamp cache; drop password immediately.

    Returns:
        True if seeding succeeded, False otherwise.
    """
    try:
        # Ask for the password once. This is the only place we accept input.
        pw = getpass.getpass("sudo password: ")
        _print_action("sudo -S -v  # seed sudo timestamp")
        try:
            subprocess.run(
                ["sudo", "-S", "-v"],
                input=pw + "\n",
                text=True,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        finally:
            # Ensure we drop the reference, even if run() raises.
            pw = None
        return True
    except Exception as exc:
        print(f"ERROR: Failed to seed sudo timestamp: {exc}")
        return False


def _keepalive_loop(stop_evt: threading.Event, interval: int) -> None:
    """Background loop to refresh sudo's timestamp non-interactively."""
    while not stop_evt.is_set():
        # Use -n to avoid blocking if the timestamp ever expires.
        subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        stop_evt.wait(interval)


def start_sudo_session(keepalive_interval_sec: int = 60):
    """
    Start a sudo session that never stores the password in memory.

    Arguments:
        keepalive_interval_sec:
            Seconds between timestamp refreshes. Minimum enforced to 10 seconds.

    Returns:
        (run, close) where:

        - run(cmd, *, check=True, capture_output=False, cwd=None, env=None, input_text=None)
            -> subprocess.CompletedProcess
          Executes `sudo -n <cmd...>` so it never prompts. If the sudo timestamp
          is invalid, the command will fail quickly (non-zero return code).

        - close() -> None
          Stops keep-alive and clears sudo credentials (`sudo -K`).

    Behavior:
        - Prints shell-style actions for visibility.
    """
    if not _seed_sudo_timestamp():
        # We still return a run/close pair, but `run` will fail if sudo is unusable.
        print("⚠️  Continuing without a valid sudo timestamp. Commands may fail (-n).")

    stop_evt = threading.Event()
    interval = max(10, int(keepalive_interval_sec))
    _print_action(f"(keepalive) sudo -n -v every {interval}s")
    t = threading.Thread(
        target=_keepalive_loop,
        args=(stop_evt, interval),
        name="sudo-keepalive",
        daemon=True,
    )
    t.start()

    def close() -> None:
        """Stop keep-alive thread and clear sudo credentials."""
        try:
            if not stop_evt.is_set():
                stop_evt.set()
                t.join(timeout=2)
            _print_action("sudo -K  # clear cached credentials")
            subprocess.run(["sudo", "-K"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as exc:
            print(f"ERROR: Failed to close sudo session cleanly: {exc}")

    atexit.register(close)

    def run(
        cmd: Iterable[str],
        *,
        check: bool = True,
        capture_output: bool = False,
        cwd: Optional[str] = None,
        env: Optional[dict] = None,
        input_text: Optional[str] = None,
    ) -> subprocess.CompletedProcess:
        """
        Execute a command as root using non-interactive sudo.

        Arguments:
            cmd: The command as an iterable of strings, e.g., ["ls", "/root"].
            check: If True, raises CalledProcessError on non-zero exit status.
            capture_output: If True, captures stdout/stderr as text.
            cwd: Working directory for the command.
            env: Environment variables to provide.
            input_text: Optional text to pass to the process's stdin.

        Returns:
            subprocess.CompletedProcess with `returncode`, `stdout`, and `stderr`.

        Notes:
            - Uses `sudo -n` to ensure no interactive prompts occur.
            - If the sudo timestamp is invalid, return code will be non-zero.
        """
        try:
            _print_action("sudo -n " + " ".join(cmd))
            return subprocess.run(
                ["sudo", "-n", *cmd],
                check=check,
                capture_output=capture_output,
                text=True,
                cwd=cwd,
                env=env,
                input=input_text,
            )
        except Exception:
            # Let callers see stack in their try/except if they opted `check=True`.
            # We still re-raise to preserve expected subprocess semantics.
            raise

    return run, close


--- utils/symlinker.py ---
# utils/symlinker.py
#!/usr/bin/env python3
"""
Symlink utility that can use your sudo session runner for privileged paths.
Version: 2.0.0

What the module does
--------------------
Provides two high-level helpers for creating symlinks safely:

1) symlink_directory(source_dir, link_path, *, run=None, use_relative=False)
   - Creates ONE symlink that points to an entire directory.

2) symlink_tree_files(source_dir, dest_dir, *, run=None, use_relative=False)
   - Mirrors a directory tree by creating real directories in the destination,
     and placing symlinks for files inside those directories.

Sudo-session compatibility
--------------------------
If you pass `run` (from `start_sudo_session()`), *all filesystem actions that
need privileges* are performed via shell commands executed by that runner
(e.g., `mkdir -p`, `mv`, `ln -s`).  
If `run` is omitted, the module uses Python's `os`/`shutil` APIs and will require
the current process to have sufficient permissions.

Key behavior
------------
- Per-run backups:
  Existing destinations are moved to:
    <this_module_dir>/backup/<YYYYmmdd-HH%M%S>/<original/absolute/path/without/leading/slash>
- Idempotent by design: destinations are backed up then recreated consistently.
- Clear printed actions; robust error handling with True/False returns.

Example
-------
from utils.sudo_session import start_sudo_session
from utils.symlinker import symlink_directory, symlink_tree_files

run, close = start_sudo_session()
try:
    symlink_directory("/opt/myrepo/app", "/etc/myapp", run=run)
    symlink_tree_files("/opt/myrepo/config", "/etc/myapp", run=run)
finally:
    close()
"""

from __future__ import annotations

import os
import sys
import shutil
from pathlib import Path
from datetime import datetime
from typing import Callable, Optional, Tuple


# Timestamp used to group all backups for one execution.
RUN_TIMESTAMP = datetime.now().strftime("%Y%m%d-%H%M%S")


# ------------------------------ Printing helpers ------------------------------

def _print_action(command_like: str) -> None:
    """Print a shell-like command to the terminal to show what is happening."""
    print(f"$ {command_like}")


def _print_error(message: str) -> None:
    """Print a clear error message to stderr so it stands out in logs."""
    print(f"ERROR: {message}", file=sys.stderr)


def _script_dir() -> Path:
    """Return the absolute path to the directory where this script lives."""
    return Path(__file__).resolve().parent


# ------------------------------ Runner helpers ------------------------------

def _run_or_os(run: Optional[Callable], cmd: list[str]) -> Tuple[bool, Optional[str], Optional[str]]:
    """
    Execute a command either through the provided sudo-session runner or via subprocess.

    Returns:
        (ok, stdout_or_none, stderr_or_none)
    """
    try:
        if run is None:
            # No sudo runner provided -> use subprocess directly.
            import subprocess
            res = subprocess.run(cmd, check=False, text=True, capture_output=True)
            return (res.returncode == 0, res.stdout, res.stderr)
        else:
            # Use provided sudo runner (already wraps command with 'sudo -n').
            res = run(cmd, check=False, capture_output=True)
            return (res.returncode == 0, res.stdout, res.stderr)
    except Exception as exc:
        return (False, None, str(exc))


def _ensure_dir_exists(path: Path, *, run: Optional[Callable]) -> bool:
    try:
        if path.exists():
            if path.is_dir():
                return True
            _print_error(f"Path exists but is not a directory: {path}")
            return False
        _print_action(f"mkdir -p {path}")
        if run is None:
            path.mkdir(parents=True, exist_ok=True)
        else:
            ok, out, err = _run_or_os(run, ["mkdir", "-p", str(path)])
            if not ok:
                if out: print(out.rstrip())
                if err: _print_error(err.rstrip())
                return False
        return True
    except Exception as exc:
        _print_error(f"Failed to create directory '{path}': {exc}")
        return False

def _backup_root_dir() -> Path:
    """Compute backup root folder for this run."""
    return _script_dir() / "backup" / RUN_TIMESTAMP


def _backup_existing_path(target: Path, *, run: Optional[Callable]) -> bool:
    """
    Move an existing path (file/dir/symlink) into the per-run backup directory.
    Returns True if moved (or nothing to move), False on failure.
    """
    try:
        if not target.exists() and not target.is_symlink():
            return True  # Nothing to back up.

        backup_root = _backup_root_dir()
        backup_dest = backup_root / Path(str(target).lstrip(os.sep))

        if not _ensure_dir_exists(backup_dest.parent, run=run):
            return False

        _print_action(f"mv {target} {backup_dest}")
        if run is None:
            # Use shutil.move to handle files/dirs/symlinks.
            backup_root.mkdir(parents=True, exist_ok=True)
            shutil.move(str(target), str(backup_dest))
        else:
            # Ensure backup root exists via runner too.
            ok, out, err = _run_or_os(run, ["mkdir", "-p", str(backup_dest.parent)])
            if not ok:
                if out:
                    print(out.rstrip())
                if err:
                    _print_error(err.rstrip())
                return False
            ok, out, err = _run_or_os(run, ["mv", str(target), str(backup_dest)])
            if not ok:
                if out:
                    print(out.rstrip())
                if err:
                    _print_error(err.rstrip())
                return False

        return True
    except Exception as exc:
        _print_error(f"Failed to back up '{target}': {exc}")
        return False


def _compute_symlink_target(source: Path, link: Path, use_relative: bool) -> str:
    """Compute absolute/relative path to store in the symlink."""
    if use_relative:
        return os.path.relpath(source.resolve(), start=link.parent.resolve())
    return str(source.resolve())


def _create_symlink(source: Path, link: Path, *, run: Optional[Callable], use_relative: bool) -> bool:
    """Create the symlink (backing up an existing path first)."""
    try:
        if not source.exists() and not source.is_symlink():
            _print_error(f"Source does not exist: {source}")
            return False

        if not _ensure_dir_exists(link.parent, run=run):
            return False

        # Backup existing destination, if present.
        if link.exists() or link.is_symlink():
            if not _backup_existing_path(link, run=run):
                return False

        target = _compute_symlink_target(source, link, use_relative)
        _print_action(f"ln -s {target} {link}")

        if run is None:
            os.symlink(target, str(link))
        else:
            ok, out, err = _run_or_os(run, ["ln", "-s", target, str(link)])
            if not ok:
                if out:
                    print(out.rstrip())
                if err:
                    _print_error(err.rstrip())
                return False

        return True
    except FileExistsError:
        _print_error(f"Destination already exists and could not be replaced: {link}")
        return False
    except Exception as exc:
        _print_error(f"Failed to create symlink '{link}': {exc}")
        return False


# ------------------------------ Public API ------------------------------

def symlink_directory(
    source_dir: Path | str,
    link_path: Path | str,
    *,
    run: Optional[Callable] = None,
    use_relative: bool = False
) -> bool:
    """
    Create a single symlink that points to an entire directory.

    Arguments:
        source_dir:
            Directory the symlink should point to.
        link_path:
            Path of the symlink to create (e.g., /etc/myapp -> /opt/myrepo/myapp).
        run:
            Optional sudo-session runner. If provided, shell commands are executed
            via `sudo -n`. If omitted, Python's filesystem APIs are used.
        use_relative:
            If True, create a relative symlink; otherwise absolute (default).

    Returns:
        True if the symlink was created successfully, False otherwise.
    """
    src = Path(source_dir)
    dst = Path(link_path)

    if not src.exists() and not src.is_symlink():
        _print_error(f"Source directory does not exist: {src}")
        return False
    if src.exists() and not src.is_dir():
        _print_error(f"Source path exists but is not a directory: {src}")
        return False

    return _create_symlink(src, dst, run=run, use_relative=use_relative)


def symlink_tree_files(
    source_dir: Path | str,
    dest_dir: Path | str,
    *,
    run: Optional[Callable] = None,
    use_relative: bool = False
) -> bool:
    """
    Mirror a directory tree by creating real directories under `dest_dir` and
    placing symlinks for files found under `source_dir`.

    Arguments:
        source_dir:
            Root directory to read files from.
        dest_dir:
            Root directory to mirror into (directories are real; files are symlinks).
        run:
            Optional sudo-session runner. If provided, operations use shell commands
            through `sudo -n`. If omitted, Python's filesystem APIs are used.
        use_relative:
            If True, create relative symlinks for files; otherwise absolute.

    Returns:
        True if ALL files were processed successfully, False if ANY step failed.
    """
    try:
        src_root = Path(source_dir).resolve()
        dst_root = Path(dest_dir).resolve()

        if not src_root.exists() or not src_root.is_dir():
            _print_error(f"Source directory does not exist or is not a directory: {src_root}")
            return False

        if not _ensure_dir_exists(dst_root, run=run):
            return False

        overall_ok = True

        for root, _dirs, files in os.walk(src_root):
            root_path = Path(root)
            relative = root_path.relative_to(src_root)
            mirrored_dir = dst_root / relative

            if not _ensure_dir_exists(mirrored_dir, run=run):
                overall_ok = False
                continue

            for filename in files:
                src_file = root_path / filename
                dst_link = mirrored_dir / filename

                if not src_file.exists() and not src_file.is_symlink():
                    _print_error(f"Source file missing, skipping: {src_file}")
                    overall_ok = False
                    continue

                if not _create_symlink(src_file, dst_link, run=run, use_relative=use_relative):
                    overall_ok = False

        return overall_ok
    except Exception as exc:
        _print_error(f"Unexpected error while mirroring symlinks: {exc}")
        return False


if __name__ == "__main__":
    # Demonstration using sudo-session for system paths (adjust paths for your machine).
    from utils.sudo_session import start_sudo_session

    run, close = start_sudo_session()
    try:
        print("👟 Demo: create /tmp/demo-target and link it to /etc/demo-link (requires sudo).")
        # Setup a safe demo directory in /tmp as the "source".
        src = Path("/tmp/demo-target")
        if not src.exists():
            _print_action(f"mkdir -p {src}")
            src.mkdir(parents=True, exist_ok=True)
            (src / "example.txt").write_text("hello\n", encoding="utf-8")

        ok1 = symlink_directory(src, "/etc/demo-link", run=run)
        print(f"Directory link result: {'success' if ok1 else 'failure'}")

        ok2 = symlink_tree_files(src, "/etc/demo-tree", run=run)
        print(f"Tree mirror result: {'success' if ok2 else 'failure'}")
    finally:
        close()


--- utils/yay.py ---
# utils/yay.py
#!/usr/bin/env python3
"""
Yay install helper (AUR) that is compatible with your sudo session flow.
Version: 2.0.0

What the module does
--------------------
Installs packages via the AUR helper `yay` in an idempotent way.

Sudo-session compatibility
--------------------------
This function accepts a `run` parameter for API symmetry with `pacman`, but
**intentionally ignores it** and runs `yay` as the **current normal user**.
That's because `yay` should *not* be invoked with sudo; it elevates internally
when necessary. If your process has an active sudo timestamp (seeded by your
`sudo_session`), yay's internal `sudo` calls will be non-interactive.

Key behavior
------------
- Uses: yay -S --needed --noconfirm <packages...>
  * `--needed` makes the operation idempotent (already-installed packages are skipped).
- Prints shell-like actions before running.
- Catches exceptions, prints clear errors, returns True/False.
- Preflight note: we warn if non-interactive sudo is not yet available, so the user
  understands a prompt might occur (useful outside your main flow).

Public API
----------
install_packages(packages: list[str], run=None) -> bool
    Install one or more packages using yay as the current user.

Example
-------
# Normal usage (yay runs as your user; sudo timestamp seeded elsewhere)
from utils.yay import install_packages
ok = install_packages(["google-chrome", "visual-studio-code-bin"])
"""

from __future__ import annotations

from typing import Iterable, List
import shutil
import subprocess
import sys


def _print_action(command_like: str) -> None:
    """Print a shell-like command to the terminal to show what is happening."""
    print(f"$ {command_like}")


def _print_error(message: str) -> None:
    """Print a clear error message to stderr so it stands out in logs."""
    print(f"ERROR: {message}", file=sys.stderr)


def _join(cmd: Iterable[str]) -> str:
    """Join a command list into a readable shell-like string (for logging only)."""
    return " ".join(str(part) for part in cmd)


def _check_yay_available() -> bool:
    """
    Verify that the 'yay' binary is available in PATH.

    Returns:
        True if yay is found; False otherwise (with an error printed).
    """
    yay_path = shutil.which("yay")
    if yay_path is None:
        _print_error("The 'yay' command was not found in PATH. Install yay before using this module.")
        return False
    return True


def _noninteractive_sudo_available() -> bool:
    """
    Return True if sudo can be used without prompting (timestamp valid or NOPASSWD).
    We probe with a harmless no-op: `sudo -n true`.
    """
    try:
        res = subprocess.run(["sudo", "-n", "true"], check=False, capture_output=False, text=True)
        return res.returncode == 0
    except Exception:
        return False


def install_packages(packages: List[str], run=None) -> bool:
    """
    Install one or more packages using yay (AUR helper) in an idempotent way.

    Arguments:
        packages:
            A list of package names (strings), e.g., ["google-chrome", "visual-studio-code-bin"].
        run:
            Ignored (accepted for API symmetry with pacman). yay must run as a normal user.

    Returns:
        True on success (including no-op for empty list), False on failure.

    Behavior:
        - Treats empty input as a successful no-op.
        - Uses 'yay -S --needed --noconfirm' to avoid reinstalling present packages.
        - Prints actions and surfaces diagnostics on failure.
    """
    try:
        if not _check_yay_available():
            return False

        cleaned = [p.strip() for p in packages if isinstance(p, str) and p.strip()]
        if not cleaned:
            _print_action("yay -S --needed --noconfirm  # (no packages provided; nothing to do)")
            return True

        # Helpful heads-up when running outside your main seeded flow.
        if not _noninteractive_sudo_available():
            print(
                "ℹ️  Non-interactive sudo is not active yet. "
                "If yay needs elevation, it may prompt unless a sudo timestamp is seeded."
            )

        cmd = ["yay", "-S", "--needed", "--noconfirm", *cleaned]
        _print_action(_join(cmd))

        # Run as the current user (NOT via sudo). yay will escalate internally if needed.
        result = subprocess.run(cmd, check=False, text=True, capture_output=False)

        if result.returncode != 0:
            _print_error("yay failed with a non-zero exit status.")
            if result.stdout:
                print(result.stdout.rstrip())
            if result.stderr:
                _print_error(result.stderr.rstrip())
            return False

        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)

        return True

    except Exception as exc:
        _print_error(f"Unexpected error running yay: {exc}")
        return False


# Backward-compat alias for code that imported the old name.
installpackage = install_packages


if __name__ == "__main__":
    # Demonstration (runs as your normal user).
    print("👟 Demo: installing 'bat' via yay (idempotent).")
    ok = install_packages(["bat"])
    print(f"Result: {'success' if ok else 'failure'}")

