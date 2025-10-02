#!/usr/bin/env bash
set -euo pipefail

# ===============================
# EDIT THESE VARIABLES
# ===============================

# 1) Section 1 — your custom prompt
# (Option A) put the prompt directly here:
PROMPT_TEXT=$'You are an Arch Linux and shell scripting expert.
We are working together to write an installation and provisioning script for **this specific laptop**.

Your style is always:
- Clear and boring — no clever tricks, just maintainable, readable code.
- Focused on correctness and reproducibility.
- Aligned with official Arch Wiki best practices (you always check/research there).
- Commented like a dumb person has to follow what is going on and you are teaching them.
- Safe defaults first, optional tweaks second.
- Minimal external dependencies (prefer core utilities).

Conventions for any shell you write:
- Use Bash with `#!/usr/bin/env bash`, `set -Eeuo pipefail`, and `IFS=$'\n\t'`.
- Structure with small functions (lower_snake_case), variables at the top (clearly documented), and a simple `main`.
- Avoid `--noconfirm` by default; if interaction-free is required, say so and make it a clearly marked variable.
- After every major step, emit an explicit verification (e.g., “OK: root partition mounted”, “OK: bootloader present”) and exit non-zero on failure.
- Prefer explicit paths and commands over shell magic. No aliases. No implicit globals.


Arch specifics:
- Follow the Arch Wiki; name the exact page/section you rely on in comments (e.g., “# per Arch Wiki: Installation guide → Partitioning”).
- Use `pacman -S --needed` for installs; handle mirrors, keys, time sync, and initramfs per the Wiki.
- For partitioning/filesystems/bootloader, show the intended layout and confirm devices before running destructive commands.

Your role is to act like a trusted sysadmin mentor: explain reasoning, suggest improvements, and write shell code that will actually work on Arch.

Our goal is to get from Arch Minimal install to rices hyprland daily driver.

Once you have read and understood the following ask me what i want to do.
'

# (Option B) OR load from a file. Leave empty to ignore.
TEMPLATE_PATH=".prompts/my_prompt.md"

# 2) Section 3 — files to include (explicit list)
#   - put any relative/absolute paths you want included
#   - only these will be listed & dumped into Section 3
FILES=(
  "./install.sh"
  "./modules/10-base.sh"
  "./modules/20-snapper-btrfs-grub.sh"
  "./modules/30-base-system.sh"
  "./modules/40-gpu-setup.sh"
  "./modules/50-hyprland-setup.sh"
  "./modules/60-app-install.sh"
  "./files/hyprland/environment.d/10-qtct.conf"
  "./files/hyprland/environment.d/20-cursor.conf"
  "./files/hyprland/environment.d/30-hypr-nvidia-safe.conf"
  "./files/hyprland/foot/foot.ini"
  "./files/hyprland/gtk/gtk-3.0/settings.ini"
  "./files/hyprland/gtk/gtk-4.0/settings.ini"
  "./files/hyprland/hypr/env.conf"
  "./files/hyprland/hypr/hyprland.conf"
  "./files/hyprland/hypr/monitors.conf"
  "./files/hyprland/hypr/startup.conf"
  "./files/hyprland/icons/default/index.theme"
  "./files/hyprland/mako/config"
  "./files/hyprland/sddm/10-wayland.conf"
  "./files/hyprland/sddm/20-session.conf"
  "./files/hyprland/wallpapers/README.txt"
  "./files/hyprland/waybar/config.jsonc"
  "./files/hyprland/waybar/style.css"
  "./files/hyprland/wofi/config"
  "./files/hyprland/wofi/style.css"
  "./files/kitty/kitty.conf"
  "./files/snapper/home"
  "./files/snapper/root"
)

# 3) Output file (where everything is written)
OUTPUT_FILE="gptcontext.md"

# 4) If true, don’t write to OUTPUT_FILE — just print to stdout
DRY_RUN=false

# ===============================
# INTERNAL HELPERS (don’t edit)
# ===============================
have_cmd() { command -v "$1" >/dev/null 2>&1; }

try_sudo() {
  if have_cmd sudo && sudo -n true 2>/dev/null; then
    sudo "$@"
  else
    "$@" 2>/dev/null || true
  fi
}

hr() { printf '%*s\n' "${1:-80}" '' | tr ' ' '='; }

# Load template file if provided (takes precedence if non-empty)
if [[ -n "${TEMPLATE_PATH:-}" && -f "$TEMPLATE_PATH" ]]; then
  PROMPT_TEXT="$(cat "$TEMPLATE_PATH")"
fi

# ===============================
# Section 2 — collectors
# ===============================
collect_hardware() {
  echo "<Hardware Overview>"
  echo
  echo "Hostname & Kernel:"
  if have_cmd hostnamectl; then hostnamectl || true; else uname -a || true; fi
  echo
  echo "CPU:"
  if have_cmd lscpu; then lscpu || true; else grep -m1 'model name' /proc/cpuinfo 2>/dev/null || true; fi
  echo
  echo "Memory:"
  if have_cmd free; then free -h || true; fi
  echo
  echo "Block Devices:"
  if have_cmd lsblk; then lsblk -f || true; fi
  echo
  echo "PCI (controllers, GPUs, NICs, etc):"
  if have_cmd lspci; then lspci -nn || true; fi
  echo
  echo "USB:"
  if have_cmd lsusb; then lsusb || true; fi
  echo
  echo "DMI / System Firmware:"
  if have_cmd dmidecode; then
    echo "(dmidecode may require root; attempting)"
    try_sudo dmidecode -t system -t bios || echo "dmidecode unavailable or permission denied."
  fi
}

collect_driver_gaps() {
  echo "<Devices Potentially Missing Drivers>"
  echo
  # PCI entries with no "Kernel driver in use"
  if have_cmd lspci; then
    if have_cmd awk; then
      lspci -nnk | awk '
        BEGIN{RS=""; FS="\n"}
        {
          used=0
          for(i=1;i<=NF;i++){
            if($i ~ /Kernel driver in use:/) used=1
          }
          if(used==0){ print $0 "\n---" }
        }'
    else
      echo "awk not available to parse lspci output."
    fi
  else
    echo "lspci not found."
  fi
  echo
  # USB devices with empty driver
  if have_cmd usb-devices; then
    usb-devices | awk '
      BEGIN{RS=""; FS="\n"}
      {
        drv=""
        for(i=1;i<=NF;i++){
          if($i ~ /^D: *Driver=/){ split($i,a,"="); drv=a[2] }
        }
        if(drv=="" || drv=="(none)"){ print $0 "\n---" }
      }'
  elif have_cmd lsusb; then
    echo "usb-devices not found; lsusb output listed above for reference."
  fi
}

collect_errors() {
  echo "<Current System Errors and Warnings>"
  echo
  if have_cmd journalctl; then
    echo "journalctl -p err -b (this boot):"
    journalctl -p err -b --no-pager -n 200 || true
    echo
    echo "journalctl -p warning -b (this boot):"
    journalctl -p warning -b --no-pager -n 200 || true
  elif have_cmd dmesg; then
    echo "dmesg (errors & warnings):"
    dmesg --ctime --level=err,warn 2>/dev/null || dmesg | grep -Ei 'error|fail|warn' || true
  else
    echo "Neither journalctl nor dmesg found."
  fi
}

# ===============================
# Section 3 helpers
# ===============================
validate_files() {
  local -a good=() missing=()
  for f in "${FILES[@]}"; do
    if [[ -f "$f" ]]; then good+=("$f"); else missing+=("$f"); fi
  done
  FILES=("${good[@]}")

  if ((${#missing[@]})); then
    echo "Warning: these paths were not found and will be skipped:" >&2
    for m in "${missing[@]}"; do echo "  - $m" >&2; done
  fi
}

file_tree() {
  for f in "${FILES[@]}"; do
    python3 - "$f" <<'PY' 2>/dev/null || realpath --relative-to="." "$f" 2>/dev/null || echo "$f"
import os, sys
p = sys.argv[1]
print(os.path.relpath(p, "."))
PY
  done | sort -u
}

# ===============================
# Build Output
# ===============================
build_output() {
  {
    echo "# Section 1 — Custom ChatGPT Prompt"
    echo
    if [[ -n "${PROMPT_TEXT//[$'\t\r\n ']/}" ]]; then
      echo "$PROMPT_TEXT"
    else
      echo "_(No prompt provided — edit PROMPT_TEXT or TEMPLATE_PATH at the top of the script.)_"
    fi
    echo
    hr 80
    echo
    echo "# Section 2 — System Probe"
    echo
    collect_hardware
    echo
    hr 80
    echo
    echo "## Driver Usage & Potential Gaps"
    echo
    collect_driver_gaps
    echo
    echo "## Current Errors / Warnings"
    echo
    collect_errors
    echo
    hr 80
    echo
    echo "# Section 3 — Files (Tree & Contents)"
    echo
    if ((${#FILES[@]})); then
      echo "## File Tree"
      echo
      echo '<File Tree>'
      file_tree
      echo
      echo "## Contents"
      echo
      for f in "${FILES[@]}"; do
        relpath="$(python3 - <<'PY' "$f" 2>/dev/null || echo "$f"
import os, sys
print(os.path.relpath(sys.argv[1], "."))
PY
)"
        echo "--- ${relpath} ---"
        if have_cmd file && file -b --mime "$f" 2>/dev/null | grep -qi 'text'; then
          cat "$f"
        else
          if grep -qI . "$f" 2>/dev/null; then
            cat "$f"
          else
            echo "[binary or non-text content omitted]"
          fi
        fi
        echo
      done
    else
      echo "_(No files specified — edit the FILES array near the top of the script.)_"
    fi
  } | {
      if "$DRY_RUN"; then cat; else tee "$OUTPUT_FILE" >/dev/null; fi
    }

  if "$DRY_RUN"; then
    echo "Dry run complete (output not written)."
  else
    echo "Context file created: $OUTPUT_FILE"
  fi
}

# ===============================
# Main
# ===============================
validate_files
build_output
