# Section 1 — Custom ChatGPT Prompt

You are an Arch Linux and shell scripting expert.
We are working together to write an installation and provisioning script for **this specific laptop**.

Your style is always:
- Clear and boring — no clever tricks, just maintainable, readable code.
- Focused on correctness and reproducibility.
- Aligned with official Arch Wiki best practices (you always check/research there).
- Commented like a dumb person has to follow what is going on and you are teaching them.
- Safe defaults first, optional tweaks second.
- Minimal external dependencies (prefer core utilities).

Conventions for any shell you write:
- Use Bash with `#!/usr/bin/env bash`, `set -Eeuo pipefail`, and `IFS=$nt`.
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


================================================================================

# Section 2 — System Probe

<Hardware Overview>

Hostname & Kernel:
 Static hostname: nebula
       Icon name: computer-laptop
         Chassis: laptop 💻
      Machine ID: a85796842fa04956bc17053a36180d31
         Boot ID: ede8839dc56349d488803fd87dffe96b
    Product UUID: 4c4c4544-0056-3010-8033-b7c04f323733
Operating System: Arch Linux
          Kernel: Linux 6.16.8-arch3-1
    Architecture: x86-64
 Hardware Vendor: Dell Inc.
  Hardware Model: XPS 15 9500
 Hardware Serial: 7V03273
    Hardware SKU: 097D
Hardware Version: A00
Firmware Version: 1.39.0
   Firmware Date: Tue 2025-08-05
    Firmware Age: 1month 3w 5d

CPU:
Architecture:                            x86_64
CPU op-mode(s):                          32-bit, 64-bit
Address sizes:                           39 bits physical, 48 bits virtual
Byte Order:                              Little Endian
CPU(s):                                  12
On-line CPU(s) list:                     0-11
Vendor ID:                               GenuineIntel
Model name:                              Intel(R) Core(TM) i7-10750H CPU @ 2.60GHz
CPU family:                              6
Model:                                   165
Thread(s) per core:                      2
Core(s) per socket:                      6
Socket(s):                               1
Stepping:                                2
CPU(s) scaling MHz:                      94%
CPU max MHz:                             2600.0000
CPU min MHz:                             800.0000
BogoMIPS:                                5199.98
Flags:                                   fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb ssbd ibrs ibpb stibp ibrs_enhanced tpr_shadow flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid mpx rdseed adx smap clflushopt intel_pt xsaveopt xsavec xgetbv1 xsaves dtherm arat pln pts hwp hwp_notify hwp_act_window hwp_epp vnmi pku ospke md_clear flush_l1d arch_capabilities
Virtualization:                          VT-x
L1d cache:                               192 KiB (6 instances)
L1i cache:                               192 KiB (6 instances)
L2 cache:                                1.5 MiB (6 instances)
L3 cache:                                12 MiB (1 instance)
NUMA node(s):                            1
NUMA node0 CPU(s):                       0-11
Vulnerability Gather data sampling:      Mitigation; Microcode
Vulnerability Ghostwrite:                Not affected
Vulnerability Indirect target selection: Mitigation; Aligned branch/return thunks
Vulnerability Itlb multihit:             KVM: Mitigation: Split huge pages
Vulnerability L1tf:                      Not affected
Vulnerability Mds:                       Not affected
Vulnerability Meltdown:                  Not affected
Vulnerability Mmio stale data:           Mitigation; Clear CPU buffers; SMT vulnerable
Vulnerability Old microcode:             Not affected
Vulnerability Reg file data sampling:    Not affected
Vulnerability Retbleed:                  Mitigation; Enhanced IBRS
Vulnerability Spec rstack overflow:      Not affected
Vulnerability Spec store bypass:         Mitigation; Speculative Store Bypass disabled via prctl
Vulnerability Spectre v1:                Mitigation; usercopy/swapgs barriers and __user pointer sanitization
Vulnerability Spectre v2:                Mitigation; Enhanced / Automatic IBRS; IBPB conditional; PBRSB-eIBRS SW sequence; BHI SW loop, KVM SW loop
Vulnerability Srbds:                     Mitigation; Microcode
Vulnerability Tsa:                       Not affected
Vulnerability Tsx async abort:           Not affected
Vulnerability Vmscape:                   Mitigation; IBPB before exit to userspace

Memory:
               total        used        free      shared  buff/cache   available
Mem:            31Gi       4.9Gi        21Gi       1.6Gi       5.8Gi        26Gi
Swap:          4.0Gi          0B       4.0Gi

Block Devices:
NAME        FSTYPE FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
zram0       swap   1     zram0 dbabe804-c3b4-4e5a-afd4-946212aa77b7                [SWAP]
nvme0n1                                                                            
|-nvme0n1p1 vfat   FAT32       A8CD-6652                             656.7M    36% /boot
`-nvme0n1p2 btrfs              e8400dad-bddc-416a-841b-f29640b79938  946.2G     1% /var/log
                                                                                   /var/cache/pacman/pkg
                                                                                   /home
                                                                                   /

PCI (controllers, GPUs, NICs, etc):
00:00.0 Host bridge [0600]: Intel Corporation 10th Gen Core Processor Host Bridge/DRAM Registers [8086:9b54] (rev 02)
00:01.0 PCI bridge [0604]: Intel Corporation 6th-10th Gen Core Processor PCIe Controller (x16) [8086:1901] (rev 02)
00:02.0 VGA compatible controller [0300]: Intel Corporation CometLake-H GT2 [UHD Graphics] [8086:9bc4] (rev 05)
00:04.0 Signal processing controller [1180]: Intel Corporation Xeon E3-1200 v5/E3-1500 v5/6th Gen Core Processor Thermal Subsystem [8086:1903] (rev 02)
00:08.0 System peripheral [0880]: Intel Corporation Xeon E3-1200 v5/v6 / E3-1500 v5 / 6th/7th/8th Gen Core Processor Gaussian Mixture Model [8086:1911]
00:12.0 Signal processing controller [1180]: Intel Corporation Comet Lake PCH Thermal Controller [8086:06f9]
00:13.0 Serial controller [0700]: Intel Corporation Comet Lake PCH Integrated Sensor Solution [8086:06fc]
00:14.0 USB controller [0c03]: Intel Corporation Comet Lake USB 3.1 xHCI Host Controller [8086:06ed]
00:14.2 RAM memory [0500]: Intel Corporation Comet Lake PCH Shared SRAM [8086:06ef]
00:14.3 Network controller [0280]: Intel Corporation Comet Lake PCH CNVi WiFi [8086:06f0]
00:15.0 Serial bus controller [0c80]: Intel Corporation Comet Lake PCH Serial IO I2C Controller #0 [8086:06e8]
00:15.1 Serial bus controller [0c80]: Intel Corporation Comet Lake PCH Serial IO I2C Controller #1 [8086:06e9]
00:16.0 Communication controller [0780]: Intel Corporation Comet Lake HECI Controller [8086:06e0]
00:1c.0 PCI bridge [0604]: Intel Corporation Comet Lake PCIe Root Port #1 [8086:06b8] (rev f0)
00:1c.6 PCI bridge [0604]: Intel Corporation Comet Lake PCIe Root Port #7 [8086:06be] (rev f0)
00:1d.0 PCI bridge [0604]: Intel Corporation Comet Lake PCI Express Root Port #9 [8086:06b0] (rev f0)
00:1e.0 Communication controller [0780]: Intel Corporation Comet Lake PCH Serial IO UART Host Controller #0 [8086:06a8]
00:1f.0 ISA bridge [0601]: Intel Corporation WM490 Chipset LPC/eSPI Controller [8086:068e]
00:1f.3 Audio device [0403]: Intel Corporation Comet Lake PCH cAVS [8086:06c8]
00:1f.4 SMBus [0c05]: Intel Corporation Comet Lake PCH SMBus Controller [8086:06a3]
00:1f.5 Serial bus controller [0c80]: Intel Corporation Comet Lake PCH SPI Controller [8086:06a4]
01:00.0 3D controller [0302]: NVIDIA Corporation TU117M [GeForce GTX 1650 Ti Mobile] [10de:1f95] (rev a1)
02:00.0 PCI bridge [0604]: Intel Corporation JHL7540 Thunderbolt 3 Bridge [Titan Ridge 4C 2018] [8086:15ea] (rev 06)
03:00.0 PCI bridge [0604]: Intel Corporation JHL7540 Thunderbolt 3 Bridge [Titan Ridge 4C 2018] [8086:15ea] (rev 06)
03:01.0 PCI bridge [0604]: Intel Corporation JHL7540 Thunderbolt 3 Bridge [Titan Ridge 4C 2018] [8086:15ea] (rev 06)
03:02.0 PCI bridge [0604]: Intel Corporation JHL7540 Thunderbolt 3 Bridge [Titan Ridge 4C 2018] [8086:15ea] (rev 06)
03:04.0 PCI bridge [0604]: Intel Corporation JHL7540 Thunderbolt 3 Bridge [Titan Ridge 4C 2018] [8086:15ea] (rev 06)
04:00.0 System peripheral [0880]: Intel Corporation JHL7540 Thunderbolt 3 NHI [Titan Ridge 4C 2018] [8086:15eb] (rev 06)
38:00.0 USB controller [0c03]: Intel Corporation JHL7540 Thunderbolt 3 USB Controller [Titan Ridge 4C 2018] [8086:15ec] (rev 06)
6c:00.0 Unassigned class [ff00]: Realtek Semiconductor Co., Ltd. RTS5260 PCI Express Card Reader [10ec:5260] (rev 01)
6d:00.0 Non-Volatile memory controller [0108]: Micron Technology Inc 2300 NVMe SSD [Santana] [1344:5405]

USB:

DMI / System Firmware:

================================================================================

## Driver Usage & Potential Gaps

<Devices Potentially Missing Drivers>



## Current Errors / Warnings

<Current System Errors and Warnings>

journalctl -p err -b (this boot):
Sep 29 20:19:16 nebula kernel: x86/cpu: SGX disabled or unsupported by BIOS.
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: FW download error recovery failed (-19)
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: sending frame failed (-19)
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: Reading supported features failed (-19)
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: sending frame failed (-19)
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: Failed to read MSFT supported features (-19)
Sep 29 20:19:16 nebula kernel: psmouse serio1: elantech: elantech_send_cmd query 0x02 failed.
Sep 29 20:19:16 nebula kernel: psmouse serio1: elantech: failed to query capabilities.
Sep 29 20:19:18 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Sep 29 20:19:18 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Sep 29 20:19:19 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Sep 29 20:19:19 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Sep 29 20:19:19 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Sep 29 20:19:19 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Sep 29 20:19:21 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Sep 29 20:19:21 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Sep 30 18:56:16 nebula kernel: psmouse serio1: elantech: elantech_send_cmd query 0x02 failed.
Sep 30 18:56:16 nebula kernel: psmouse serio1: elantech: failed to query capabilities.

journalctl -p warning -b (this boot):
Sep 29 20:19:16 nebula kernel: x86/cpu: SGX disabled or unsupported by BIOS.
Sep 29 20:19:16 nebula kernel: MMIO Stale Data CPU bug present and SMT on, data leak possible. See https://www.kernel.org/doc/html/latest/admin-guide/hw-vuln/processor_mmio_stale_data.html for more details.
Sep 29 20:19:16 nebula kernel: hpet_acpi_add: no address or irqs in _CRS
Sep 29 20:19:16 nebula kernel: i8042: Warning: Keylock active
Sep 29 20:19:16 nebula kernel: ENERGY_PERF_BIAS: Set to 'normal', was 'performance'
Sep 29 20:19:16 nebula kernel: wmi_bus wmi_bus-PNP0C14:03: [Firmware Bug]: WQBC data block query control method not found
Sep 29 20:19:16 nebula kernel: nouveau 0000:01:00.0: [drm] No compatible format found
Sep 29 20:19:16 nebula kernel: platform regulatory.0: Direct firmware load for regulatory.db failed with error -2
Sep 29 20:19:16 nebula kernel: spi-nor spi0.0: supply vcc not found, using dummy regulator
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: FW download error recovery failed (-19)
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: sending frame failed (-19)
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: Reading supported features failed (-19)
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: HCI LE Coded PHY feature bit is set, but its usage is not supported.
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: sending frame failed (-19)
Sep 29 20:19:16 nebula kernel: Bluetooth: hci0: Failed to read MSFT supported features (-19)
Sep 29 20:19:16 nebula kernel: psmouse serio1: elantech: elantech_send_cmd query 0x02 failed.
Sep 29 20:19:16 nebula kernel: psmouse serio1: elantech: failed to query capabilities.
Sep 29 20:19:17 nebula systemd-networkd[424]: wlan0: Found matching .network file, based on potentially unpredictable interface name: /etc/systemd/network/20-wlan.network
Sep 29 20:19:18 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Sep 29 20:19:18 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Sep 29 20:19:19 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Sep 29 20:19:19 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Sep 29 20:19:19 nebula kernel: Bluetooth: hci0: HCI LE Coded PHY feature bit is set, but its usage is not supported.
Sep 29 20:19:19 nebula sddm[693]: Could not setup default cursor
Sep 29 20:19:19 nebula dbus-broker-launch[596]: Activation request for 'org.freedesktop.home1' failed: The systemd unit 'dbus-org.freedesktop.home1.service' could not be found.
Sep 29 20:19:19 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Sep 29 20:19:19 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Sep 29 20:19:19 nebula dbus-broker-launch[736]: Service file '/usr/share/dbus-1/services/org.kde.dolphin.FileManager1.service' is not named after the D-Bus name 'org.freedesktop.FileManager1'.
Sep 29 20:19:19 nebula dbus-broker-launch[736]: Service file '/usr/share/dbus-1/services/org.knopwob.dunst.service' is not named after the D-Bus name 'org.freedesktop.Notifications'.
Sep 29 20:19:20 nebula sddm-greeter-qt6[733]: file:///usr/lib/qt6/qml/SddmComponents/LayoutBox.qml:35:5: QML Connections: Implicitly defined onFoo properties in Connections are deprecated. Use this syntax instead: function onFoo(<arguments>) { ... }
Sep 29 20:19:20 nebula sddm-greeter-qt6[733]: file:///usr/lib/qt6/qml/SddmComponents/ComboBox.qml:105:9: QML Image: Cannot open: file:///usr/lib/qt6/qml/SddmComponents/angle-down.png
Sep 29 20:19:20 nebula sddm-greeter-qt6[733]: file:///usr/lib/qt6/qml/SddmComponents/ComboBox.qml:105:9: QML Image: Cannot open: file:///usr/lib/qt6/qml/SddmComponents/angle-down.png
Sep 29 20:19:20 nebula sddm-greeter-qt6[733]: qrc:/theme/Main.qml:41:5: QML Connections: Implicitly defined onFoo properties in Connections are deprecated. Use this syntax instead: function onFoo(<arguments>) { ... }
Sep 29 20:19:21 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Sep 29 20:19:21 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Sep 29 20:19:37 nebula sddm-greeter-qt6[733]: file:///usr/lib/qt6/qml/SddmComponents/PictureBox.qml:106:13 Parameter "event" is not declared. Injection of parameters into signal handlers is deprecated. Use JavaScript functions with formal parameters instead.
Sep 29 20:19:41 nebula dbus-broker-launch[834]: Service file '/usr/share/dbus-1/services/org.kde.dolphin.FileManager1.service' is not named after the D-Bus name 'org.freedesktop.FileManager1'.
Sep 29 20:19:41 nebula dbus-broker-launch[834]: Service file '/usr/share/dbus-1/services/org.knopwob.dunst.service' is not named after the D-Bus name 'org.freedesktop.Notifications'.
Sep 29 20:24:58 nebula /usr/lib/xdg-desktop-portal[1192]: Realtime error: Could not get pidns for pid 1224: Could not fstatat ns/pid: Not a directory
Sep 29 20:24:58 nebula /usr/lib/xdg-desktop-portal[1192]: Realtime error: Could not get pidns for pid 1224: Could not fstatat ns/pid: Not a directory
Sep 29 20:35:26 nebula kernel: nvme nvme0: using unchecked data buffer
Sep 29 20:35:26 nebula kernel: block nvme0n1: No UUID available providing old NGUID
Sep 29 20:37:42 nebula kernel: warning: `ThreadPoolForeg' uses wireless extensions which will stop working for Wi-Fi 7 hardware; use nl80211
Sep 30 18:56:16 nebula kernel: ACPI: button: The lid device is not compliant to SW_LID.
Sep 30 18:56:16 nebula systemd-networkd[424]: wlan0: Failed to send DHCP RELEASE, ignoring: Invalid argument
Sep 30 18:56:16 nebula kernel: psmouse serio1: elantech: elantech_send_cmd query 0x02 failed.
Sep 30 18:56:16 nebula kernel: psmouse serio1: elantech: failed to query capabilities.
Sep 30 21:31:37 nebula systemd-resolved[408]: Using degraded feature set UDP instead of UDP+EDNS0 for DNS server 9.9.9.9#dns.quad9.net.
Sep 30 21:31:42 nebula systemd-resolved[408]: Using degraded feature set UDP instead of UDP+EDNS0 for DNS server 1.1.1.1#cloudflare-dns.com.
Sep 30 21:31:47 nebula systemd-resolved[408]: Using degraded feature set UDP instead of UDP+EDNS0 for DNS server 8.8.8.8#dns.google.
Sep 30 21:31:53 nebula systemd-resolved[408]: Using degraded feature set TCP instead of UDP for DNS server 9.9.9.9#dns.quad9.net.
Sep 30 21:32:03 nebula systemd-resolved[408]: Using degraded feature set TCP instead of UDP for DNS server 1.1.1.1#cloudflare-dns.com.
Sep 30 21:32:13 nebula systemd-resolved[408]: Using degraded feature set TCP instead of UDP for DNS server 8.8.8.8#dns.google.
Sep 30 21:32:34 nebula systemd-resolved[408]: Using degraded feature set UDP instead of TCP for DNS server 1.1.1.1#cloudflare-dns.com.
Sep 30 21:32:39 nebula systemd-resolved[408]: Using degraded feature set UDP instead of TCP for DNS server 8.8.8.8#dns.google.
Sep 30 21:32:44 nebula systemd-resolved[408]: Using degraded feature set UDP instead of TCP for DNS server 9.9.9.9#dns.quad9.net.

================================================================================

# Section 3 — Files (Tree & Contents)

## File Tree

<File Tree>
files/snapper/home
files/snapper/root
install.sh
modules/10-base.sh
modules/20-snapper-btrfs-grub.sh
modules/30-base-system.sh

## Contents

--- install.sh ---
#!/usr/bin/env bash
# Modular Arch installer — menu + runner (script-local logs)

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================================
# Config
# ================================
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="${MODULE_DIR:-$SCRIPT_DIR/modules}"
MODULE_GLOB='[0-9][0-9]-*.sh'
ASSUME_YES="${ASSUME_YES:-false}"   # exported to modules; modules decide whether to use it
MODEL_GUARD="${MODEL_GUARD:-}"      # optional substring to enforce on DMI product_name

# All logs go under ./logs relative to this script
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
SESSION_LOG="$LOG_DIR/session-$(date +%F_%H-%M-%S).log"

# ================================
# Logging
# ================================
log()   { printf '[%(%F %T)T] %s\n' -1 "$*" | tee -a "$SESSION_LOG" >&2; }
ok()    { log "OK: $*"; }
fail()  { log "FAIL: $*"; exit 1; }

# ================================
# TUI helpers
# ================================
print_banner() {
  printf '\n== Modular Arch Installer (menu + runner) ==\n'
  printf ' Modules dir: %s\n Log file:    %s\n\n' "$MODULE_DIR" "$SESSION_LOG"
}

press_enter() {
  printf '\nPress Enter to continue... '; read -r _
}

# ================================
# Module discovery & parsing
# ================================
# Metadata format (first ~50 lines of each module):
#   # meta: id=10 name="Base system" desc="Essentials and services" needs_root=false
# Required keys: id, name
# Optional keys: desc, needs_root (true/false)
# Modules MUST be executable. The harness runs them as:
#   env ASSUME_YES=... bash MODULE_PATH
discover_modules() {
  mapfile -t MODULE_FILES < <(
    find "$MODULE_DIR" -maxdepth 1 -type f -name "$MODULE_GLOB" -print0 \
      | xargs -0 -I{} realpath "{}" | sort
  )
  [[ "${#MODULE_FILES[@]}" -gt 0 ]] || fail "No modules found in $MODULE_DIR"
}

parse_meta() {
  # arg: module_path
  local path="$1"
  local header meta
  header="$(head -n 50 "$path")"
  meta="$(grep -E '^# meta:' <<<"$header" | head -n1 || true)"

  local id="" name="" desc="" needs_root="false"
  if [[ -n "$meta" ]]; then
    meta="${meta#\# meta: }"
    # Extract key="value with spaces" OR key=value-without-spaces
    # Then map them to vars without using eval.
    while IFS= read -r kv; do
      case "$kv" in
        id=*)          id="${kv#id=}";;
        name=*)        name="${kv#name=}";;
        desc=*)        desc="${kv#desc=}";;
        needs_root=*)  needs_root="${kv#needs_root=}";;
      esac
    done < <(grep -oE '([a-z_]+)="[^"]*"|([a-z_]+)=[^[:space:]]+' <<<"$meta")

    # strip surrounding quotes when present
    name="${name%\"}"; name="${name#\"}"
    desc="${desc%\"}"; desc="${desc#\"}"
    id="${id%\"}";    id="${id#\"}"
    needs_root="${needs_root%\"}"; needs_root="${needs_root#\"}"
  fi

  printf '%s|%s|%s|%s\n' "$id" "$name" "$desc" "$needs_root"
}

collect_modules() {
  MODULES_META=()   # each: "index|id|name|desc|needs_root|path|modlog"
  local idx=1
  for f in "${MODULE_FILES[@]}"; do
    local meta id name desc needs_root
    meta="$(parse_meta "$f")"
    IFS='|' read -r id name desc needs_root <<<"$meta"

    # Fallbacks from filename
    [[ -n "$id"   ]] || id="$(basename "$f" | cut -d- -f1)"
    [[ -n "$name" ]] || name="$(basename "$f" .sh)"
    [[ -n "$desc" ]] || desc="(no description)"
    [[ -n "$needs_root" ]] || needs_root="false"

    local modlog="$LOG_DIR/module-$(printf '%02d' "$idx")-$(basename "${f%.sh}")-$(date +%H%M%S).log"
    MODULES_META+=("${idx}|${id}|${name}|${desc}|${needs_root}|${f}|${modlog}")
    idx=$((idx+1))
  done
}

# ================================
# Guards (optional model check; UEFI check is module-specific)
# ================================
guard_model() {
  [[ -z "$MODEL_GUARD" ]] && return 0
  local prod="/sys/devices/virtual/dmi/id/product_name"
  [[ -r "$prod" ]] || fail "Cannot read $prod"
  local name; name="$(<"$prod")"
  [[ "$name" == *"$MODEL_GUARD"* ]] || fail "Model guard '$MODEL_GUARD' not matched (found '$name')"
  ok "Model guard matched: $name"
}

# ================================
# Execution
# ================================
run_module() {
  # arg: "idx|id|name|desc|needs_root|path|modlog"
  local rec="$1"
  local idx id name desc needs_root path modlog
  IFS='|' read -r idx id name desc needs_root path modlog <<<"$rec"

  log "==> [$idx] ${name} (id=${id}) — ${desc}"
  log "    path: $path"
  log "    log : $modlog"

  [[ -x "$path" ]] || fail "Module not executable: $path"

  ( export ASSUME_YES; bash "$path" ) >>"$modlog" 2>&1
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "Module ${name} finished successfully"
  else
    log "Module ${name} FAILED with rc=$rc (see $modlog)"
    return "$rc"
  fi
}

run_all() {
  for rec in "${MODULES_META[@]}"; do
    run_module "$rec" || return $?
  done
  ok "All modules completed"
}

show_menu() {
  printf '\nAvailable modules (discovered in %s):\n' "$MODULE_DIR"
  for rec in "${MODULES_META[@]}"; do
    IFS='|' read -r idx id name desc needs_root path modlog <<<"$rec"
    printf '  %2d) %-24s  %s%s\n' "$idx" "$name" "$desc" \
      "$( [[ "$needs_root" == "true" ]] && printf ' [module will sudo]' || printf '' )"
  done
  cat <<EOF

  a) Run ALL (in order)
  q) Quit
EOF
}

prompt_choice() {
  read -rp "Choice: " choice
  case "$choice" in
    a|A) run_all ;;
    q|Q) exit 0 ;;
    ''|*[!0-9]*) log "Invalid choice"; return 1 ;;
    *)
      local sel="$choice"
      for rec in "${MODULES_META[@]}"; do
        IFS='|' read -r idx _ _ _ _ _ _ <<<"$rec"
        if [[ "$idx" -eq "$sel" ]]; then
          run_module "$rec" || return $?
          return 0
        fi
      done
      log "No such item: $sel"; return 1
      ;;
  esac
}

# ================================
# Main
# ================================
trap 'log "Interrupted"; exit 130' INT
print_banner
guard_model
discover_modules
collect_modules

while true; do
  show_menu
  prompt_choice || true
  press_enter
done

--- modules/10-base.sh ---
#!/usr/bin/env bash
# meta: id=10 name="Base system" desc="Time/locale, networking, audio, firmware" needs_root=false
# This module performs base post-install config.
# - Per Arch Wiki: Installation guide → Post-install configuration
# - Per Arch Wiki: systemd-timesyncd, Network configuration, PipeWire, Bluetooth
# Conventions: boring & safe. No --noconfirm by default. Fail fast on errors.

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

# Respect ASSUME_YES from environment, if set by the harness
pac() {
  local extra=()
  [[ "${ASSUME_YES:-false}" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S --needed "${extra[@]}" "$@"
}

main() {
  # Defaults — override by exporting before running module if desired
  local TIMEZONE="${TIMEZONE:-Europe/London}"
  local LOCALE="${LOCALE:-en_US.UTF-8}"
  local KEYMAP="${KEYMAP:-us}"

  # Update packages (no --noconfirm by default; user can answer)
  sudo pacman -Syu
  ok "System updated"

  # Time + NTP — per Arch Wiki: systemd-timesyncd
  sudo ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  sudo timedatectl set-timezone "$TIMEZONE"
  sudo timedatectl set-ntp true
  sudo hwclock --systohc
  ok "Timezone + NTP configured"
}

main "$@"

--- modules/20-snapper-btrfs-grub.sh ---
#!/usr/bin/env bash
# meta: id=20 name="Snapper (Btrfs) + GRUB" desc="Install snapper/snap-pac/grub-btrfs, create .snapshots, fstab+mount, enable timers+quota, symlink repo configs, rebuild GRUB, and verify with a test snapshot" needs_root=true
#
# Arch Wiki references (keep aligned in comments):
# - Btrfs: Installation guide → Filesystems → Btrfs
# - Snapper: Create a configuration / Integration with pacman / Timeline & cleanup
# - grub-btrfs: path unit generates /boot/grub/grub-btrfs.cfg from Snapper snapshots

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ----------------
# Config (override via env)
# ----------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SNAP_CONF_SRC_DIR="${SNAP_CONF_SRC_DIR:-$REPO_ROOT/files/snapper}"
BTRFS_COMP_OPT="${BTRFS_COMP_OPT:-compress=zstd:3}"
KEEP_VERIFY_SNAPSHOT="${KEEP_VERIFY_SNAPSHOT:-false}"   # set true to keep the test snapshot

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
    if command -v sudo >/dev/null 2>&1; then
      exec sudo -E -- bash "$0" "$@"
    else
      fail "This module requires root. Install sudo or run as root."
    fi
  fi
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }
fs_is_btrfs() { [[ "$(findmnt -no FSTYPE "$1")" == "btrfs" ]]; }
is_btrfs_subvol() { btrfs subvolume show "$1" >/dev/null 2>&1; }
ensure_dir() { install -d -m 0755 "$1"; }

ensure_subvolume() {
  # per Arch Wiki: Snapper → Create a configuration (expects .snapshots subvolumes)
  local path="$1"
  if [[ -e "$path" ]]; then
    is_btrfs_subvol "$path" || fail "$path exists but is not a Btrfs subvolume"
    return 0
  fi
  log "Creating Btrfs subvolume: $path"
  btrfs subvolume create "$path" >/dev/null
}

ensure_fstab_entry() {
  # per Arch Wiki: Btrfs — explicit mounts for subvolumes
  local mnt="$1" subvol_name="${2:-${mnt##*/}}"
  local uuid; uuid="$(findmnt -no UUID / || true)"
  [[ -n "$uuid" ]] || fail "Could not resolve UUID for /"
  if ! grep -qE "[[:space:]]${mnt}[[:space:]]" /etc/fstab; then
    log "Appending fstab entry for ${mnt}"
    printf 'UUID=%s  %s  btrfs  subvol=%s,%s  0 0\n' "$uuid" "$mnt" "$subvol_name" "$BTRFS_COMP_OPT" >> /etc/fstab
  fi
}

mount_if_needed() {
  local mp="$1"
  if mountpoint -q "$mp"; then
    return 0
  fi
  log "Mounting ${mp}"
  mount "$mp"
}

deploy_symlink() {
  # per Arch Wiki: Snapper — configs live in /etc/snapper/configs/*
  local src="$1" dest="$2"
  [[ -f "$src" ]] || fail "Source config not found: $src"
  if [[ -L "$dest" ]]; then
    local target; target="$(readlink -f "$dest" || true)"
    if [[ "$target" == "$(readlink -f "$src")" ]]; then
      ok "Symlink already correct: $dest → $src"
      return 0
    fi
  fi
  if [[ -e "$dest" ]]; then
    log "Backing up existing: $dest → ${dest}.bak.$(date +%s)"
    mv -f "$dest" "${dest}.bak.$(date +%s)"
  fi
  ln -s "$(realpath "$src")" "$dest"
  ok "Symlinked: $dest → $src"
}

verify_snapper_config() {
  local cfg="$1"
  snapper -c "$cfg" list >/dev/null || fail "snapper could not read config '$cfg'"
  ok "snapper config '$cfg' is readable"
}

verify_grub_btrfs_cfg_present() {
  [[ -s /boot/grub/grub-btrfs.cfg ]] || fail "/boot/grub/grub-btrfs.cfg missing or empty"
  ok "grub-btrfs configuration present"
}

enable_quota_if_needed() {
  # per Arch Wiki: Snapper — qgroups recommended for space-aware cleanup
  local mnt="$1"
  if ! btrfs qgroup show "$mnt" >/dev/null 2>&1; then
    log "Enabling Btrfs quota on $mnt"
    btrfs quota enable "$mnt"
  fi
}

force_grub_btrfs_refresh() {
  # poke the generator
  systemctl start grub-btrfsd.path || true
  systemctl restart grub-btrfsd.service || true
}

verify_end_to_end_with_test_snapshot() {
  # Create a test snapshot, ensure it appears in grub-btrfs.cfg, then optionally delete it.
  local desc="install-verify-$(date +%F_%H-%M-%S)"
  log "Creating test snapshot (root): $desc"
  snapper -c root create --type single --description "$desc"

  # Get latest snapshot number for root
  local sn
  sn="$(snapper -c root list --columns number,description | awk -v d="$desc" '$0 ~ d {print $1}' | tail -n1)"
  [[ -n "$sn" ]] || fail "Could not determine test snapshot number"

  # Refresh grub-btrfs and wait briefly for cfg regeneration
  force_grub_btrfs_refresh
  local cfg="/boot/grub/grub-btrfs.cfg"
  local path_regex="/\\.snapshots/${sn}/snapshot"
  local found="false"
  for _ in 1 2 3 4 5; do
    if grep -qE "$path_regex" "$cfg"; then
      found="true"; break
    fi
    sleep 1
  done
  [[ "$found" == "true" ]] || fail "grub-btrfs did not list snapshot $sn in $cfg"

  ok "GRUB sees snapshot #$sn"

  if [[ "${KEEP_VERIFY_SNAPSHOT}" != "true" ]]; then
    log "Deleting test snapshot #$sn"
    snapper -c root delete "$sn"
    force_grub_btrfs_refresh
    ok "Test snapshot cleaned up"
  else
    log "Keeping test snapshot #$sn as requested (KEEP_VERIFY_SNAPSHOT=true)"
  fi
}

# ----------------
# Main
# ----------------
main() {
  require_root "$@"

  ensure_cmd btrfs
  ensure_cmd grub-mkconfig
  ensure_dir /etc/snapper/configs
  ensure_dir "$SNAP_CONF_SRC_DIR"

  fs_is_btrfs / || fail "/ is not on Btrfs"
  [[ -d /home ]] && fs_is_btrfs /home || true

  log "Installing packages: snapper snap-pac grub-btrfs"
  pacman -S --needed snapper snap-pac grub-btrfs

  # .snapshots subvolumes and mounts (per Arch Wiki: Snapper → Create a configuration)
  ensure_subvolume "/.snapshots"
  chown root:root /.snapshots && chmod 0750 /.snapshots
  ensure_fstab_entry "/.snapshots" ".snapshots"
  mount_if_needed "/.snapshots"

  if [[ -d /home ]]; then
    ensure_subvolume "/home/.snapshots"
    chown root:root /home/.snapshots && chmod 0750 /home/.snapshots
    ensure_fstab_entry "/home/.snapshots" ".snapshots"
    mount_if_needed "/home/.snapshots"
  fi
  ok ".snapshots subvolumes present and mounted"

  # Quotas for Snapper cleanup
  enable_quota_if_needed "/"
  [[ -d /home ]] && enable_quota_if_needed "/home" || true
  ok "Btrfs quota/qgroups enabled where applicable"

  # Timers + grub-btrfs watcher
  systemctl enable --now snapper-timeline.timer
  systemctl enable --now snapper-cleanup.timer
  systemctl enable --now grub-btrfsd.path
  ok "snapper timers and grub-btrfs path enabled"

  # Rebuild GRUB (ensures include line exists)
  [[ -d /boot/grub ]] || fail "/boot/grub not found (is GRUB installed to this ESP?)"
  grub-mkconfig -o /boot/grub/grub.cfg
  ok "grub.cfg rebuilt"
  verify_grub_btrfs_cfg_present

  # Link repo configs and verify
  deploy_symlink "$SNAP_CONF_SRC_DIR/root" /etc/snapper/configs/root
  verify_snapper_config root
  if [[ -d /home && -f "$SNAP_CONF_SRC_DIR/home" ]]; then
    deploy_symlink "$SNAP_CONF_SRC_DIR/home" /etc/snapper/configs/home
    verify_snapper_config home
  else
    log "Note: skipping /home config (either /home missing or no repo file)"
  fi

  # End-to-end verification
  verify_end_to_end_with_test_snapshot

  ok "Snapper + grub-btrfs setup complete and verified"
}

main "$@"

--- files/snapper/home ---
SUBVOLUME="/home"
FSTYPE="btrfs"
SYNC_ACL="yes"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"

--- files/snapper/root ---
SUBVOLUME="/"
FSTYPE="btrfs"
SYNC_ACL="yes"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"

--- modules/30-base-system.sh ---
#!/usr/bin/env bash
# meta: id=30 name="Base system (utils + yay + power + audio + bluetooth)" desc="CLI utilities, yay (AUR), power management (PPD/TLP), PipeWire/WirePlumber audio, and BlueZ" needs_root=false
#
# Arch Wiki references (keep these accurate):
# - Installation guide → Post-installation (package management basics)
# - Pacman: https://wiki.archlinux.org/title/Pacman
# - Makepkg (build rules; never as root): https://wiki.archlinux.org/title/Makepkg
# - AUR helpers (we still build yay with makepkg, as user): https://wiki.archlinux.org/title/AUR_helpers
# - Power management:
#     * Power management: https://wiki.archlinux.org/title/Power_management
#     * power-profiles-daemon: https://wiki.archlinux.org/title/Power_Profiles_Daemon
#     * TLP: https://wiki.archlinux.org/title/TLP
# - Audio:
#     * PipeWire: https://wiki.archlinux.org/title/PipeWire
#     * WirePlumber: https://wiki.archlinux.org/title/WirePlumber
#     * ALSA: https://wiki.archlinux.org/title/Advanced_Linux_Sound_Architecture
#     * RealtimeKit: https://wiki.archlinux.org/title/RealtimeKit
# - Bluetooth (BlueZ): https://wiki.archlinux.org/title/Bluetooth
#
# Style & conventions:
# - Run as a regular user (needs_root=false). Use sudo for system changes.
# - No --noconfirm by default; set ASSUME_YES=true for unattended runs.
# - Small functions, explicit verification after each major step.
# - Strict: any failure exits non-zero (no hints).

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================================
# Config (override via env)
# ================================
# Utility categories (DE/WM agnostic; core laptop tooling)
UTILS_ENABLE_CORE="${UTILS_ENABLE_CORE:-true}"
UTILS_ENABLE_NET_TOOLS="${UTILS_ENABLE_NET_TOOLS:-true}"
UTILS_ENABLE_FS_TOOLS="${UTILS_ENABLE_FS_TOOLS:-true}"
UTILS_ENABLE_SYS_TOOLS="${UTILS_ENABLE_SYS_TOOLS:-true}"
UTILS_ENABLE_DOCS="${UTILS_ENABLE_DOCS:-true}"

# Optional extras to install from AUR via yay (space-separated)
AUR_PACKAGES="${AUR_PACKAGES:-}"             # e.g., 'bat-extras bottom-bin'

# Power management backend for laptops (pick one; they conflict)
PM_BACKEND="${PM_BACKEND:-ppd}"              # 'ppd' (power-profiles-daemon) or 'tlp'
ENABLE_POWERTOP="${ENABLE_POWERTOP:-false}"  # optional, installs powertop

# Bluetooth behavior
BT_AUTOENABLE="${BT_AUTOENABLE:-true}"       # set AutoEnable=true in /etc/bluetooth/main.conf
BT_POWER_ON_NOW="${BT_POWER_ON_NOW:-true}"   # enforce controller powered on now

# ================================
# Logging / helpers
# ================================
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

pac() {
  # Wrapper around pacman respecting ASSUME_YES; uses --needed (per best practice)
  local extra=()
  [[ "${ASSUME_YES:-false}" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S --needed "${extra[@]}" "$@"
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }

ensure_not_root() {
  # per Arch Wiki: Makepkg → must NOT run as root
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "Run this module as a regular user (makepkg must not run as root)."
  fi
}

verify_pkgs_installed() {
  local missing=()
  for p in "$@"; do
    pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [[ "${#missing[@]}" -eq 0 ]] || fail "Packages not installed: ${missing[*]}"
}

wait_for_condition() {
  # usage: wait_for_condition <seconds> <cmd...>
  local timeout="$1"; shift
  local t=0
  while ! "$@" >/dev/null 2>&1; do
    ((t++))
    if (( t >= timeout )); then
      return 1
    fi
    sleep 1
  done
  return 0
}

# ================================
# yay bootstrap (AUR via makepkg as user)
# ================================
install_yay_if_needed() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay present"
    return 0
  fi

  # per Arch Wiki: makepkg prerequisites
  pac git base-devel
  ok "Prerequisites installed (git, base-devel)"

  local builddir
  builddir="$(mktemp -d -t aur-yay-XXXXXXXX)"
  trap 'rm -rf -- "$builddir"' EXIT

  git clone https://aur.archlinux.org/yay.git "$builddir/yay" >/dev/null
  pushd "$builddir/yay" >/dev/null
  local mflags=()
  [[ "${ASSUME_YES:-false}" == "true" ]] && mflags+=(--noconfirm)
  makepkg -si "${mflags[@]}"
  popd >/dev/null

  command -v yay >/dev/null 2>&1 || fail "yay not found after build"
  ok "yay installed"
}

# ================================
# Utilities (official repos)
# ================================
collect_util_packages() {
  PKGS=()

  if [[ "$UTILS_ENABLE_CORE" == "true" ]]; then
    PKGS+=(vim nano less which tree ripgrep fd jq rsync)
  fi
  if [[ "$UTILS_ENABLE_NET_TOOLS" == "true" ]]; then
    PKGS+=(curl wget aria2 openssh openbsd-netcat iperf3 mtr)
  fi
  if [[ "$UTILS_ENABLE_FS_TOOLS" == "true" ]]; then
    PKGS+=(exfatprogs ntfs-3g dosfstools mtools)
  fi
  if [[ "$UTILS_ENABLE_SYS_TOOLS" == "true" ]]; then
    PKGS+=(htop iotop lsof strace pciutils usbutils dmidecode lm_sensors smartmontools nvme-cli)
  fi
  if [[ "$UTILS_ENABLE_DOCS" == "true" ]]; then
    PKGS+=(man-db man-pages texinfo)
  fi
}

install_official_utils() {
  collect_util_packages
  if [[ "${#PKGS[@]}" -gt 0 ]]; then
    pac "${PKGS[@]}"
    verify_pkgs_installed "${PKGS[@]}"
    ok "CLI utilities installed"
  else
    ok "No utility categories enabled"
  fi
}

install_aur_optional() {
  [[ -z "$AUR_PACKAGES" ]] && { ok "No AUR packages requested"; return 0; }
  ensure_cmd yay
  local yflags=(--needed)
  [[ "${ASSUME_YES:-false}" == "true" ]] && yflags+=(--noconfirm)
  # shellcheck disable=SC2086
  yay -S ${yflags[*]} $AUR_PACKAGES

  local missing=()
  for p in $AUR_PACKAGES; do
    pacman -Qi "$p" >/dev/null 2>&1 || yay -Q "$p" >/devnull 2>&1 || missing+=("$p")
  done
  [[ "${#missing[@]}" -eq 0 ]] || fail "AUR packages not installed: ${missing[*]}"
  ok "AUR packages installed"
}

# ================================
# Power management
# ================================
setup_power_profiles_daemon() {
  # per Arch Wiki: Power Profiles Daemon — disable TLP to avoid conflicts
  pac power-profiles-daemon
  sudo systemctl disable --now tlp.service tlp-sleep.service 2>/dev/null || true
  sudo systemctl enable --now power-profiles-daemon.service
  systemctl is-active --quiet power-profiles-daemon || fail "power-profiles-daemon not active"
  ok "power-profiles-daemon active"
  if [[ "$ENABLE_POWERTOP" == "true" ]]; then
    pac powertop
    verify_pkgs_installed powertop
    ok "powertop available"
  fi
}

setup_tlp() {
  # per Arch Wiki: TLP — disable PPD to avoid conflicts
  pac tlp
  sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
  sudo systemctl enable --now tlp.service
  sudo systemctl enable --now tlp-sleep.service 2>/dev/null || true
  systemctl is-active --quiet tlp || fail "TLP not active"
  ok "TLP active"
  if [[ "$ENABLE_POWERTOP" == "true" ]]; then
    pac powertop
    verify_pkgs_installed powertop
    ok "powertop available"
  fi
}

configure_power_management() {
  case "$PM_BACKEND" in
    ppd) setup_power_profiles_daemon ;;
    tlp) setup_tlp ;;
    *) fail "Unknown PM_BACKEND='$PM_BACKEND' (use 'ppd' or 'tlp')" ;;
  esac
  ok "Power management configured (${PM_BACKEND})"
}

# ================================
# Audio (PipeWire + WirePlumber, strict)
# per Arch Wiki: PipeWire / WirePlumber / ALSA / RealtimeKit
# ================================
configure_audio() {
  # Install PipeWire core, shims, session manager, ALSA tooling, firmware/UCM, RTKit
  pac pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rtkit alsa-utils alsa-ucm-conf sof-firmware
  verify_pkgs_installed pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rtkit alsa-utils alsa-ucm-conf sof-firmware

  # Enable RTKit system service (recommended)
  sudo systemctl enable --now rtkit-daemon.service
  systemctl is-active --quiet rtkit-daemon || fail "rtkit-daemon not active"

  # Ensure user services are enabled and running (socket activation is typical, we enforce enable+now)
  systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

  # Wait a few seconds for the graph to settle
  wait_for_condition 5 systemctl --user is-active pipewire || fail "pipewire (user) not active"
  wait_for_condition 5 systemctl --user is-active wireplumber || fail "wireplumber (user) not active"

  # ALSA device presence
  aplay -l >/dev/null 2>&1 || fail "ALSA: no playback devices (aplay -l failed)"
  arecord -l >/dev/null 2>&1 || fail "ALSA: no capture devices (arecord -l failed)"

  # Pulse shim should be PipeWire's
  command -v pactl >/dev/null 2>&1 || fail "pactl not available"
  local server
  server="$(pactl info 2>/dev/null | awk -F': ' '/Server Name/ {print $2}')"
  [[ "$server" == "PulseAudio (on PipeWire)" ]] || fail "Pulse shim not active (got: '${server:-none}')"

  # Basic sink/source presence via wpctl (if present)
  if command -v wpctl >/dev/null 2>&1; then
    wpctl status | grep -q 'Sinks:' || fail "PipeWire: no sinks detected"
    wpctl status | grep -q 'Sources:' || fail "PipeWire: no sources detected"
  fi

  ok "Audio stack ready (PipeWire/WirePlumber + Pulse/JACK shims, RTKit, ALSA)"
}

# ================================
# Bluetooth (BlueZ, strict pass/fail)
# per Arch Wiki: Bluetooth — install bluez/bluez-utils, enable service, ensure controller present/powered
# ================================
bluetooth_requirements() {
  pac linux-firmware bluez bluez-utils util-linux
  verify_pkgs_installed linux-firmware bluez bluez-utils util-linux

  # Load btusb (typical for Intel CNVi)
  sudo modprobe btusb || true

  # Unblock via rfkill (non-interactive)
  if rfkill list 2>/dev/null | grep -A2 -i bluetooth | grep -qi 'Soft blocked: yes'; then
    sudo rfkill unblock bluetooth || fail "rfkill unblock failed"
  fi
}

configure_bluetooth() {
  bluetooth_requirements

  # Configure AutoEnable to power on adapters on availability (policy)
  if [[ "$BT_AUTOENABLE" == "true" ]]; then
    sudo install -D -m 0644 /dev/null /etc/bluetooth/main.conf
    if ! grep -q '^AutoEnable=' /etc/bluetooth/main.conf 2>/dev/null; then
      printf '[Policy]\nAutoEnable=true\n' | sudo tee /etc/bluetooth/main.conf >/dev/null
    else
      sudo sed -i 's/^AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
    fi
  fi

  sudo systemctl enable --now bluetooth.service
  systemctl is-active --quiet bluetooth || fail "bluetooth.service not active"

  # Wait briefly for controller enumeration after service start
  wait_for_condition 5 bash -c "bluetoothctl list | grep -q '^Controller'" || fail "No Bluetooth controller detected"

  if [[ "$BT_POWER_ON_NOW" == "true" ]]; then
    if ! bluetoothctl show | grep -q 'Powered: yes'; then
      printf 'power on\nquit\n' | bluetoothctl >/dev/null 2>&1 || true
      # Re-check after a short wait
      wait_for_condition 5 bash -c "bluetoothctl show | grep -q 'Powered: yes'" || fail "Bluetooth controller not powered"
    fi
  fi

  ok "Bluetooth controller present and powered"
}

# ================================
# Main
# ================================
main() {
  ensure_not_root
  ensure_cmd sudo

  # Keep system fresh (user confirms unless ASSUME_YES=true)
  sudo pacman -Syu
  ok "System updated"

  install_yay_if_needed
  ok "yay available"

  install_official_utils
  install_aur_optional

  configure_power_management
  configure_audio
  configure_bluetooth

  ok "Base system module complete"
}

main "$@"

