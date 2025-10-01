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
         Boot ID: be8c59ed904c47fa905d3745240c629a
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
    Firmware Age: 1month 3w 6d

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
CPU(s) scaling MHz:                      100%
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
Mem:            31Gi       3.8Gi        25Gi       1.5Gi       3.3Gi        27Gi
Swap:          4.0Gi          0B       4.0Gi

Block Devices:
NAME        FSTYPE FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
zram0       swap   1     zram0 6f723b6b-6c6a-43f8-a242-58a23322d8ca                [SWAP]
nvme0n1                                                                            
|-nvme0n1p1 vfat   FAT32       A8CD-6652                             656.1M    36% /boot
`-nvme0n1p2 btrfs              e8400dad-bddc-416a-841b-f29640b79938  942.6G     1% /home/.snapshots
                                                                                   /var/log
                                                                                   /home
                                                                                   /var/cache/pacman/pkg
                                                                                   /.snapshots
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
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 001 Device 002: ID 0bda:5411 Realtek Semiconductor Corp. RTS5411 Hub
Bus 001 Device 003: ID 27c6:533c Shenzhen Goodix Technology Co.,Ltd. FingerPrint
Bus 001 Device 004: ID 413c:301c Dell Computer Corp. Dell Universal Receiver
Bus 001 Device 005: ID 8087:0026 Intel Corp. AX201 Bluetooth
Bus 001 Device 006: ID 343c:0000 xxxxxxxx USB Type-C Digital AV Adapter
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 003 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 004 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 004 Device 002: ID 0bda:0411 Realtek Semiconductor Corp. Hub

DMI / System Firmware:
(dmidecode may require root; attempting)
# dmidecode 3.6
Getting SMBIOS data from sysfs.
SMBIOS 3.2 present.

Handle 0x0001, DMI type 0, 26 bytes
BIOS Information
	Vendor: Dell Inc.
	Version: 1.39.0
	Release Date: 08/05/2025
	ROM Size: 32 MB
	Characteristics:
		PCI is supported
		PNP is supported
		BIOS is upgradeable
		BIOS shadowing is allowed
		Boot from CD is supported
		Selectable boot is supported
		EDD is supported
		Print screen service is supported (int 5h)
		8042 keyboard services are supported (int 9h)
		Serial services are supported (int 14h)
		Printer services are supported (int 17h)
		ACPI is supported
		USB legacy is supported
		Smart battery is supported
		BIOS boot specification is supported
		Function key-initiated network boot is supported
		Targeted content distribution is supported
		UEFI is supported
	BIOS Revision: 1.39

Handle 0x0100, DMI type 1, 27 bytes
System Information
	Manufacturer: Dell Inc.
	Product Name: XPS 15 9500
	Version: Not Specified
	Serial Number: 7V03273
	UUID: 4c4c4544-0056-3010-8033-b7c04f323733
	Wake-up Type: Power Switch
	SKU Number: 097D
	Family: XPS

Handle 0x0C00, DMI type 12, 5 bytes
System Configuration Options
	Option 1: J6H1:1-X Boot with Default; J8H1:1-X BIOS RECOVERY

Handle 0x0D00, DMI type 13, 22 bytes
BIOS Language Information
	Language Description Format: Abbreviated
	Installable Languages: 1
		enUS
	Currently Installed Language: enUS

Handle 0x2000, DMI type 32, 11 bytes
System Boot Information
	Status: No errors detected


================================================================================

## Driver Usage & Potential Gaps

<Devices Potentially Missing Drivers>


T:  Bus=01 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=480  MxCh=16
D:  Ver= 2.00 Cls=09(hub  ) Sub=00 Prot=01 MxPS=64 #Cfgs=  1
P:  Vendor=1d6b ProdID=0002 Rev=06.16
S:  Manufacturer=Linux 6.16.8-arch3-1 xhci-hcd
S:  Product=xHCI Host Controller
S:  SerialNumber=0000:00:14.0
C:  #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=0mA
I:  If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   4 Ivl=256ms
---
T:  Bus=01 Lev=01 Prnt=01 Port=09 Cnt=01 Dev#=  3 Spd=12   MxCh= 0
D:  Ver= 2.00 Cls=ff(vend.) Sub=00 Prot=00 MxPS=64 #Cfgs=  1
P:  Vendor=27c6 ProdID=533c Rev=01.00
S:  Manufacturer=Goodix
S:  Product=FingerPrint
C:  #Ifs= 1 Cfg#= 1 Atr=a0 MxPwr=100mA
I:  If#= 0 Alt= 0 #EPs= 2 Cls=ff(vend.) Sub=00 Prot=00 Driver=(none)
E:  Ad=01(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
E:  Ad=83(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
---
T:  Bus=01 Lev=01 Prnt=03 Port=13 Cnt=01 Dev#=  5 Spd=12   MxCh= 0
D:  Ver= 2.01 Cls=e0(wlcon) Sub=01 Prot=01 MxPS=64 #Cfgs=  1
P:  Vendor=8087 ProdID=0026 Rev=00.02
C:  #Ifs= 2 Cfg#= 1 Atr=e0 MxPwr=100mA
I:  If#= 0 Alt= 0 #EPs= 3 Cls=e0(wlcon) Sub=01 Prot=01 Driver=btusb
E:  Ad=02(O) Atr=02(Bulk) MxPS=  64 Ivl=0ms
E:  Ad=81(I) Atr=03(Int.) MxPS=  64 Ivl=1ms
E:  Ad=82(I) Atr=02(Bulk) MxPS=  64 Ivl=0ms
I:  If#= 1 Alt= 0 #EPs= 2 Cls=e0(wlcon) Sub=01 Prot=01 Driver=btusb
E:  Ad=03(O) Atr=01(Isoc) MxPS=   0 Ivl=1ms
E:  Ad=83(I) Atr=01(Isoc) MxPS=   0 Ivl=1ms
---
T:  Bus=01 Lev=01 Prnt=05 Port=03 Cnt=01 Dev#=  2 Spd=480  MxCh= 5
D:  Ver= 2.10 Cls=09(hub  ) Sub=00 Prot=02 MxPS=64 #Cfgs=  1
P:  Vendor=0bda ProdID=5411 Rev=01.01
S:  Manufacturer=Generic
S:  Product=USB2.1 Hub
C:  #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=0mA
I:  If#= 0 Alt= 1 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=02 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   1 Ivl=256ms
---
T:  Bus=01 Lev=02 Prnt=02 Port=02 Cnt=01 Dev#=  4 Spd=12   MxCh= 0
D:  Ver= 2.00 Cls=00(>ifc ) Sub=00 Prot=00 MxPS=32 #Cfgs=  1
P:  Vendor=413c ProdID=301c Rev=02.44
S:  Manufacturer=Dell Computer Corp
S:  Product=Dell Universal Receiver
C:  #Ifs= 3 Cfg#= 1 Atr=a0 MxPwr=100mA
I:  If#= 0 Alt= 0 #EPs= 1 Cls=03(HID  ) Sub=01 Prot=01 Driver=usbhid
E:  Ad=81(I) Atr=03(Int.) MxPS=   8 Ivl=4ms
I:  If#= 1 Alt= 0 #EPs= 1 Cls=03(HID  ) Sub=01 Prot=02 Driver=usbhid
E:  Ad=82(I) Atr=03(Int.) MxPS=   8 Ivl=4ms
I:  If#= 2 Alt= 0 #EPs= 1 Cls=03(HID  ) Sub=00 Prot=00 Driver=usbhid
E:  Ad=83(I) Atr=03(Int.) MxPS=  32 Ivl=1ms
---
T:  Bus=01 Lev=02 Prnt=04 Port=03 Cnt=01 Dev#=  6 Spd=1.5  MxCh= 0
D:  Ver= 2.01 Cls=11(blbrd) Sub=00 Prot=00 MxPS= 8 #Cfgs=  1
P:  Vendor=343c ProdID=0000 Rev=00.00
S:  Manufacturer=xxxxxxxx
S:  Product=USB Type-C Digital AV Adapter
S:  SerialNumber=000000000000
C:  #Ifs= 1 Cfg#= 1 Atr=c0 MxPwr=496mA
I:  If#= 0 Alt= 0 #EPs= 0 Cls=11(blbrd) Sub=00 Prot=00 Driver=(none)
---
T:  Bus=02 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=10000 MxCh=10
D:  Ver= 3.10 Cls=09(hub  ) Sub=00 Prot=03 MxPS= 9 #Cfgs=  1
P:  Vendor=1d6b ProdID=0003 Rev=06.16
S:  Manufacturer=Linux 6.16.8-arch3-1 xhci-hcd
S:  Product=xHCI Host Controller
S:  SerialNumber=0000:00:14.0
C:  #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=0mA
I:  If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   4 Ivl=256ms
---
T:  Bus=03 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=480  MxCh= 2
D:  Ver= 2.00 Cls=09(hub  ) Sub=00 Prot=01 MxPS=64 #Cfgs=  1
P:  Vendor=1d6b ProdID=0002 Rev=06.16
S:  Manufacturer=Linux 6.16.8-arch3-1 xhci-hcd
S:  Product=xHCI Host Controller
S:  SerialNumber=0000:38:00.0
C:  #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=0mA
I:  If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   4 Ivl=256ms
---
T:  Bus=04 Lev=00 Prnt=00 Port=00 Cnt=00 Dev#=  1 Spd=10000 MxCh= 2
D:  Ver= 3.10 Cls=09(hub  ) Sub=00 Prot=03 MxPS= 9 #Cfgs=  1
P:  Vendor=1d6b ProdID=0003 Rev=06.16
S:  Manufacturer=Linux 6.16.8-arch3-1 xhci-hcd
S:  Product=xHCI Host Controller
S:  SerialNumber=0000:38:00.0
C:  #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=0mA
I:  If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=03(Int.) MxPS=   4 Ivl=256ms
---
T:  Bus=04 Lev=01 Prnt=01 Port=00 Cnt=01 Dev#=  2 Spd=5000 MxCh= 4
D:  Ver= 3.20 Cls=09(hub  ) Sub=00 Prot=03 MxPS= 9 #Cfgs=  1
P:  Vendor=0bda ProdID=0411 Rev=01.01
S:  Manufacturer=Generic
S:  Product=USB3.2 Hub
C:  #Ifs= 1 Cfg#= 1 Atr=e0 MxPwr=0mA
I:  If#= 0 Alt= 0 #EPs= 1 Cls=09(hub  ) Sub=00 Prot=00 Driver=hub
E:  Ad=81(I) Atr=13(Int.) MxPS=   2 Ivl=16ms
---

## Current Errors / Warnings

<Current System Errors and Warnings>

journalctl -p err -b (this boot):
Oct 01 21:43:11 nebula kernel: x86/cpu: SGX disabled or unsupported by BIOS.
Oct 01 21:43:11 nebula kernel: 
Oct 01 21:43:12 nebula kernel: psmouse serio1: elantech: elantech_send_cmd query 0x02 failed.
Oct 01 21:43:12 nebula kernel: psmouse serio1: elantech: failed to query capabilities.
Oct 01 21:43:15 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Oct 01 21:43:15 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Oct 01 21:43:15 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Oct 01 21:43:15 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Oct 01 21:43:15 nebula dbus-broker-launch[769]: Ignoring duplicate name 'org.freedesktop.Notifications' in service file '/usr/share/dbus-1/services/org.knopwob.dunst.service'
Oct 01 21:43:16 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Oct 01 21:43:16 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Oct 01 21:43:18 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Oct 01 21:43:18 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Oct 01 21:43:19 nebula dbus-broker-launch[799]: Ignoring duplicate name 'org.freedesktop.Notifications' in service file '/usr/share/dbus-1/services/org.knopwob.dunst.service'
Oct 01 21:44:15 nebula sudo[1883]:   nathan : a password is required ; TTY=pts/0 ; PWD=/home/nathan/25_09_21_xps9500_arch ; USER=root ; COMMAND=/usr/bin/true

journalctl -p warning -b (this boot):
Oct 01 21:43:11 nebula kernel: x86/cpu: SGX disabled or unsupported by BIOS.
Oct 01 21:43:11 nebula kernel: MMIO Stale Data CPU bug present and SMT on, data leak possible. See https://www.kernel.org/doc/html/latest/admin-guide/hw-vuln/processor_mmio_stale_data.html for more details.
Oct 01 21:43:11 nebula kernel: hpet_acpi_add: no address or irqs in _CRS
Oct 01 21:43:11 nebula kernel: i8042: Warning: Keylock active
Oct 01 21:43:11 nebula kernel: ENERGY_PERF_BIAS: Set to 'normal', was 'performance'
Oct 01 21:43:11 nebula kernel: wmi_bus wmi_bus-PNP0C14:03: [Firmware Bug]: WQBC data block query control method not found
Oct 01 21:43:11 nebula kernel: nvidia: loading out-of-tree module taints kernel.
Oct 01 21:43:11 nebula kernel: nvidia: module license 'NVIDIA' taints kernel.
Oct 01 21:43:11 nebula kernel: Disabling lock debugging due to kernel taint
Oct 01 21:43:11 nebula kernel: nvidia: module license taints kernel.
Oct 01 21:43:11 nebula kernel: 
Oct 01 21:43:11 nebula kernel: NVRM: loading NVIDIA UNIX x86_64 Kernel Module  580.82.09  Fri Aug 29 17:44:50 UTC 2025
Oct 01 21:43:12 nebula kernel: nvidia_uvm: module uses symbols nvUvmInterfaceDisableAccessCntr from proprietary module nvidia, inheriting taint.
Oct 01 21:43:12 nebula kernel: platform regulatory.0: Direct firmware load for regulatory.db failed with error -2
Oct 01 21:43:12 nebula kernel: spi-nor spi0.0: supply vcc not found, using dummy regulator
Oct 01 21:43:12 nebula kernel: Bluetooth: hci0: HCI LE Coded PHY feature bit is set, but its usage is not supported.
Oct 01 21:43:12 nebula kernel: psmouse serio1: elantech: elantech_send_cmd query 0x02 failed.
Oct 01 21:43:12 nebula kernel: psmouse serio1: elantech: failed to query capabilities.
Oct 01 21:43:13 nebula systemd-networkd[558]: wlan0: Found matching .network file, based on potentially unpredictable interface name: /etc/systemd/network/20-wlan.network
Oct 01 21:43:13 nebula sddm[719]: Detected locale "C" with character encoding "ANSI_X3.4-1968", which is not UTF-8.
                                  Qt depends on a UTF-8 locale, and has switched to "C.UTF-8" instead.
                                  If this causes problems, reconfigure your locale. See the locale(1) manual
                                  for more information.
Oct 01 21:43:13 nebula kernel: nvidia 0000:01:00.0: [drm] No compatible format found
Oct 01 21:43:15 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Oct 01 21:43:15 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Oct 01 21:43:15 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Oct 01 21:43:15 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Oct 01 21:43:15 nebula sddm[719]: Could not setup default cursor
Oct 01 21:43:15 nebula sddm-helper[753]: Detected locale "C" with character encoding "ANSI_X3.4-1968", which is not UTF-8.
                                         Qt depends on a UTF-8 locale, and has switched to "C.UTF-8" instead.
                                         If this causes problems, reconfigure your locale. See the locale(1) manual
                                         for more information.
Oct 01 21:43:15 nebula dbus-broker-launch[591]: Activation request for 'org.freedesktop.home1' failed: The systemd unit 'dbus-org.freedesktop.home1.service' could not be found.
Oct 01 21:43:15 nebula sddm-greeter-qt6[766]: Detected locale "C" with character encoding "ANSI_X3.4-1968", which is not UTF-8.
                                              Qt depends on a UTF-8 locale, and has switched to "C.UTF-8" instead.
                                              If this causes problems, reconfigure your locale. See the locale(1) manual
                                              for more information.
Oct 01 21:43:15 nebula dbus-broker-launch[769]: Service file '/usr/share/dbus-1/services/fr.emersion.mako.service' is not named after the D-Bus name 'org.freedesktop.Notifications'.
Oct 01 21:43:15 nebula dbus-broker-launch[769]: Service file '/usr/share/dbus-1/services/org.kde.dolphin.FileManager1.service' is not named after the D-Bus name 'org.freedesktop.FileManager1'.
Oct 01 21:43:15 nebula dbus-broker-launch[769]: Service file '/usr/share/dbus-1/services/org.knopwob.dunst.service' is not named after the D-Bus name 'org.freedesktop.Notifications'.
Oct 01 21:43:15 nebula dbus-broker-launch[769]: Ignoring duplicate name 'org.freedesktop.Notifications' in service file '/usr/share/dbus-1/services/org.knopwob.dunst.service'
Oct 01 21:43:15 nebula sddm-greeter-qt6[766]: file:///usr/lib/qt6/qml/SddmComponents/LayoutBox.qml:35:5: QML Connections: Implicitly defined onFoo properties in Connections are deprecated. Use this syntax instead: function onFoo(<arguments>) { ... }
Oct 01 21:43:15 nebula sddm-greeter-qt6[766]: file:///usr/lib/qt6/qml/SddmComponents/ComboBox.qml:105:9: QML Image: Cannot open: file:///usr/lib/qt6/qml/SddmComponents/angle-down.png
Oct 01 21:43:15 nebula sddm-greeter-qt6[766]: file:///usr/lib/qt6/qml/SddmComponents/ComboBox.qml:105:9: QML Image: Cannot open: file:///usr/lib/qt6/qml/SddmComponents/angle-down.png
Oct 01 21:43:16 nebula sddm-greeter-qt6[766]: qrc:/theme/Main.qml:41:5: QML Connections: Implicitly defined onFoo properties in Connections are deprecated. Use this syntax instead: function onFoo(<arguments>) { ... }
Oct 01 21:43:16 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Oct 01 21:43:16 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Oct 01 21:43:18 nebula kernel: ucsi_acpi USBC000:00: unknown error 0
Oct 01 21:43:18 nebula kernel: ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
Oct 01 21:43:19 nebula sddm-greeter-qt6[766]: file:///usr/lib/qt6/qml/SddmComponents/PictureBox.qml:106:13 Parameter "event" is not declared. Injection of parameters into signal handlers is deprecated. Use JavaScript functions with formal parameters instead.
Oct 01 21:43:19 nebula sddm-helper[783]: Detected locale "C" with character encoding "ANSI_X3.4-1968", which is not UTF-8.
                                         Qt depends on a UTF-8 locale, and has switched to "C.UTF-8" instead.
                                         If this causes problems, reconfigure your locale. See the locale(1) manual
                                         for more information.
Oct 01 21:43:19 nebula dbus-broker-launch[799]: Service file '/usr/share/dbus-1/services/fr.emersion.mako.service' is not named after the D-Bus name 'org.freedesktop.Notifications'.
Oct 01 21:43:19 nebula dbus-broker-launch[799]: Service file '/usr/share/dbus-1/services/org.kde.dolphin.FileManager1.service' is not named after the D-Bus name 'org.freedesktop.FileManager1'.
Oct 01 21:43:19 nebula dbus-broker-launch[799]: Service file '/usr/share/dbus-1/services/org.knopwob.dunst.service' is not named after the D-Bus name 'org.freedesktop.Notifications'.
Oct 01 21:43:19 nebula dbus-broker-launch[799]: Ignoring duplicate name 'org.freedesktop.Notifications' in service file '/usr/share/dbus-1/services/org.knopwob.dunst.service'
Oct 01 21:43:20 nebula wireplumber[802]: default: Failed to get percentage from UPower: org.freedesktop.DBus.Error.NameHasNoOwner
Oct 01 21:43:51 nebula kernel: warning: `ThreadPoolForeg' uses wireless extensions which will stop working for Wi-Fi 7 hardware; use nl80211
Oct 01 21:44:15 nebula sudo[1883]:   nathan : a password is required ; TTY=pts/0 ; PWD=/home/nathan/25_09_21_xps9500_arch ; USER=root ; COMMAND=/usr/bin/true

================================================================================

# Section 3 — Files (Tree & Contents)

## File Tree

<File Tree>
files/hyprland/environment.d/10-qtct.conf
files/hyprland/environment.d/20-cursor.conf
files/hyprland/environment.d/30-hypr-nvidia-safe.conf
files/hyprland/foot/foot.ini
files/hyprland/gtk/gtk-3.0/settings.ini
files/hyprland/gtk/gtk-4.0/settings.ini
files/hyprland/hypr/env.conf
files/hyprland/hypr/hyprland.conf
files/hyprland/hypr/monitors.conf
files/hyprland/hypr/startup.conf
files/hyprland/icons/default/index.theme
files/hyprland/mako/config
files/hyprland/sddm/10-wayland.conf
files/hyprland/sddm/20-session.conf
files/hyprland/wallpapers/README.txt
files/hyprland/waybar/config.jsonc
files/hyprland/waybar/style.css
files/hyprland/wofi/config
files/hyprland/wofi/style.css
files/kitty/kitty.conf
files/snapper/home
files/snapper/root
install.sh
modules/10-base.sh
modules/20-snapper-btrfs-grub.sh
modules/30-base-system.sh
modules/40-gpu-setup.sh
modules/50-hyprland-setup.sh
modules/60-app-install.sh

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
ASSUME_YES="${ASSUME_YES:-true}"   # exported to modules; modules decide whether to use it
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
# meta: id=10 name="Base system" desc="Time/locale, vconsole keymap, basic update" needs_root=false
# per Arch Wiki: Installation guide → Post-install configuration; systemd-timesyncd; Locale; Console keymap

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

ASSUME_YES="${ASSUME_YES:-false}"

pac() {
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S "${extra[@]}" "$@"
}
pac_update() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -Syu "${extra[@]}"
}

main() {
  # Defaults — safe, UK-centric; override by exporting before running the module.
  # LOCALE must exist in /etc/locale.gen (we uncomment it below).
  local TIMEZONE="${TIMEZONE:-Europe/London}"
  local LOCALE="${LOCALE:-en_GB.UTF-8}"
  local KEYMAP="${KEYMAP:-uk}"   # NOTE: Arch uses "uk", not "gb"

  # Update packages (honors ASSUME_YES)
  pac_update
  ok "System updated"

  # Time + NTP — per Arch Wiki: systemd-timesyncd
  sudo ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  sudo timedatectl set-timezone "$TIMEZONE"
  sudo timedatectl set-ntp true
  sudo hwclock --systohc
  ok "Timezone + NTP configured ($TIMEZONE)"

  # Locale — per Arch Wiki: Locale
  # 1) Ensure LOCALE is uncommented in /etc/locale.gen
  sudo sed -i "s/^#\s*${LOCALE//\//\\/}[[:space:]]\+UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
  # 2) Write /etc/locale.conf
  printf 'LANG=%s\n' "$LOCALE" | sudo tee /etc/locale.conf >/dev/null
  # 3) Generate
  sudo locale-gen
  ok "Locale generated and set (LANG=$LOCALE)"

  # Console keymap — per Arch Wiki: Linux console/Keyboard configuration
  printf 'KEYMAP=%s\n' "$KEYMAP" | sudo tee /etc/vconsole.conf >/dev/null
  ok "Console keymap set (KEYMAP=$KEYMAP)"

  # Optional: rebuild initramfs so keymap is baked into the keymap hook
  if command -v mkinitcpio >/dev/null 2>&1; then
    sudo mkinitcpio -P
    ok "Initramfs rebuilt (to include keymap)"
  fi
}

main "$@"

--- modules/20-snapper-btrfs-grub.sh ---
#!/usr/bin/env bash
# meta: id=20 name="Snapper (Btrfs) + GRUB" desc="Install snapper/snap-pac/grub-btrfs, create .snapshots, fstab+mount, enable timers+quota, symlink repo configs, rebuild GRUB, and verify with a test snapshot" needs_root=true
# Arch Wiki: Btrfs; Snapper; grub-btrfs

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

ASSUME_YES="${ASSUME_YES:-false}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SNAP_CONF_SRC_DIR="${SNAP_CONF_SRC_DIR:-$REPO_ROOT/files/snapper}"
BTRFS_COMP_OPT="${BTRFS_COMP_OPT:-compress=zstd:3}"
KEEP_VERIFY_SNAPSHOT="${KEEP_VERIFY_SNAPSHOT:-false}"

log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then exec sudo -E -- bash "$0" "$@"; fi
    fail "This module requires root. Install sudo or run as root."
  fi
}

pac() {
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  pacman -S "${extra[@]}" "$@"
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }
fs_is_btrfs() { [[ "$(findmnt -no FSTYPE "$1")" == "btrfs" ]]; }
is_btrfs_subvol() { btrfs subvolume show "$1" >/dev/null 2>&1; }
ensure_dir() { install -d -m 0755 "$1"; }

ensure_subvolume() {
  local path="$1"
  if [[ -e "$path" ]]; then
    is_btrfs_subvol "$path" || fail "$path exists but is not a Btrfs subvolume"
    return 0
  fi
  log "Creating Btrfs subvolume: $path"
  btrfs subvolume create "$path" >/dev/null
}

ensure_fstab_entry() {
  local mnt="$1" leaf="${2:-${1##*/}}"
  local parent
  case "$mnt" in
    "/.snapshots") parent="/" ;;
    "/home/.snapshots") parent="/home" ;;
    *) parent="/" ;;
  esac
  local uuid opts parent_subvol subvol_path
  uuid="$(findmnt -no UUID "$parent" || true)"
  [[ -n "$uuid" ]] || fail "Could not resolve UUID for $parent"
  opts="$(findmnt -no OPTIONS "$parent" || true)"
  parent_subvol="$(sed -n 's/.*subvol=\([^,]*\).*/\1/p' <<<"$opts")"
  if [[ -z "$parent_subvol" || "$parent_subvol" == "/" ]]; then
    subvol_path="${leaf}"
  else
    subvol_path="${parent_subvol%/}/${leaf}"
  fi
  if ! grep -qE "[[:space:]]${mnt}[[:space:]]" /etc/fstab; then
    log "Appending fstab entry for ${mnt} (subvol=${subvol_path})"
    printf 'UUID=%s  %s  btrfs  subvol=%s,%s  0 0\n' "$uuid" "$mnt" "$subvol_path" "$BTRFS_COMP_OPT" >> /etc/fstab
  fi
}

mount_if_needed() {
  local mp="$1"
  mountpoint -q "$mp" || { log "Mounting ${mp}"; mount "$mp"; }
}

deploy_symlink() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || fail "Source config not found: $src"
  if [[ -L "$dest" ]]; then
    local target; target="$(readlink -f "$dest" || true)"
    if [[ "$target" == "$(readlink -f "$src")" ]]; then
      ok "Symlink already correct: $dest → $src"; return 0
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

run_grub_btrfs_generator_if_available() {
  [[ -x /etc/grub.d/41_snapshots-btrfs ]] && /etc/grub.d/41_snapshots-btrfs || true
}

verify_grub_btrfs_cfg_present() {
  [[ -s /boot/grub/grub-btrfs.cfg ]] || run_grub_btrfs_generator_if_available
  [[ -s /boot/grub/grub-btrfs.cfg ]] || fail "/boot/grub/grub-btrfs.cfg missing or empty"
  ok "grub-btrfs configuration present"
}

enable_quota_if_needed() {
  local mnt="$1"
  btrfs qgroup show "$mnt" >/dev/null 2>&1 || { log "Enabling Btrfs quota on $mnt"; btrfs quota enable "$mnt"; }
}

enable_grub_btrfs_daemon() {
  pac inotify-tools
  systemctl enable --now grub-btrfsd.service || true
}

force_grub_btrfs_refresh() {
  enable_grub_btrfs_daemon
  run_grub_btrfs_generator_if_available
}

verify_end_to_end_with_test_snapshot() {
  local desc="install-verify-$(date +%F_%H-%M-%S)"
  log "Creating test snapshot (root): $desc"
  snapper -c root create --type single --description "$desc"
  local sn
  sn="$(snapper -c root list --columns number,description | awk -v d="$desc" '$0 ~ d {print $1}' | tail -n1)"
  [[ -n "$sn" ]] || fail "Could not determine test snapshot number"
  force_grub_btrfs_refresh
  local cfg="/boot/grub/grub-btrfs.cfg"
  local path_regex="/\\.snapshots/${sn}/snapshot"
  local found="false"
  for _ in 1 2 3 4 5; do
    if grep -qE "$path_regex" "$cfg"; then found="true"; break; fi
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
    log "Keeping test snapshot #$sn as requested"
  fi
}

main() {
  require_root "$@"

  ensure_cmd btrfs
  ensure_cmd grub-mkconfig
  ensure_dir /etc/snapper/configs
  ensure_dir "$SNAP_CONF_SRC_DIR"

  fs_is_btrfs / || fail "/ is not on Btrfs"
  [[ -d /home ]] && fs_is_btrfs /home || true

  log "Installing packages: snapper snap-pac grub-btrfs"
  pac snapper snap-pac grub-btrfs

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

  enable_quota_if_needed "/"
  [[ -d /home ]] && enable_quota_if_needed "/home" || true
  ok "Btrfs quota/qgroups enabled where applicable"

  systemctl enable --now snapper-timeline.timer
  systemctl enable --now snapper-cleanup.timer
  ok "snapper timers enabled"

  enable_grub_btrfs_daemon
  ok "grub-btrfs daemon enabled"

  [[ -d /boot/grub ]] || fail "/boot/grub not found (is GRUB installed to this ESP?)"
  grub-mkconfig -o /boot/grub/grub.cfg
  ok "grub.cfg rebuilt"

  force_grub_btrfs_refresh
  verify_grub_btrfs_cfg_present

  deploy_symlink "$SNAP_CONF_SRC_DIR/root" /etc/snapper/configs/root
  verify_snapper_config root
  if [[ -d /home && -f "$SNAP_CONF_SRC_DIR/home" ]]; then
    deploy_symlink "$SNAP_CONF_SRC_DIR/home" /etc/snapper/configs/home
    verify_snapper_config home
  else
    log "Note: skipping /home config (either /home missing or no repo file)"
  fi

  verify_end_to_end_with_test_snapshot
  ok "Snapper + grub-btrfs setup complete and verified"
}

main "$@"

--- modules/30-base-system.sh ---
#!/usr/bin/env bash
# meta: id=30 name="Base system (utils + yay + power + audio + bluetooth)" desc="CLI utilities, yay (AUR), power management (PPD/TLP), PipeWire/WirePlumber audio, and BlueZ" needs_root=false
# Arch Wiki: Pacman; Makepkg; AUR helpers; Power management; PipeWire; WirePlumber; ALSA; RealtimeKit; Bluetooth

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

UTILS_ENABLE_CORE="${UTILS_ENABLE_CORE:-true}"
UTILS_ENABLE_NET_TOOLS="${UTILS_ENABLE_NET_TOOLS:-true}"
UTILS_ENABLE_FS_TOOLS="${UTILS_ENABLE_FS_TOOLS:-true}"
UTILS_ENABLE_SYS_TOOLS="${UTILS_ENABLE_SYS_TOOLS:-true}"
UTILS_ENABLE_DOCS="${UTILS_ENABLE_DOCS:-true}"

AUR_PACKAGES="${AUR_PACKAGES:-}"

PM_BACKEND="${PM_BACKEND:-ppd}"         # 'ppd' or 'tlp'
ENABLE_POWERTOP="${ENABLE_POWERTOP:-false}"

BT_AUTOENABLE="${BT_AUTOENABLE:-true}"
BT_POWER_ON_NOW="${BT_POWER_ON_NOW:-true}"

ASSUME_YES="${ASSUME_YES:-false}"

log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }

ensure_not_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "Run this module as a regular user (it will sudo only for system changes)."
  fi
}

pac() {
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S "${extra[@]}" "$@"
}

pac_update() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -Syu "${extra[@]}"
}

pac_remove() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -Rns "${extra[@]}" "$@"
}

verify_pkgs_installed() {
  local missing=()
  for p in "$@"; do
    pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [[ "${#missing[@]}" -eq 0 ]] || fail "Packages not installed: ${missing[*]}"
}

wait_for_condition() {
  local timeout="$1"; shift
  local t=0
  while ! "$@" >/dev/null 2>&1; do
    ((t++))
    (( t >= timeout )) && return 1
    sleep 1
  done
  return 0
}

install_yay_if_needed() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay present"; return 0
  fi
  pac git base-devel
  ok "Prerequisites installed (git, base-devel)"

  local builddir
  builddir="$(mktemp -d -t aur-yay-XXXXXXXX)"
  git clone https://aur.archlinux.org/yay.git "$builddir/yay" >/dev/null
  pushd "$builddir/yay" >/dev/null

  # Makepkg: honor ASSUME_YES; do NOT disable PGP checks
  local mflags=()
  [[ "$ASSUME_YES" == "true" ]] && mflags+=(--noconfirm)
  makepkg -si "${mflags[@]}"

  popd >/dev/null
  rm -rf -- "$builddir"

  command -v yay >/dev/null 2>&1 || fail "yay not found after build"
  ok "yay installed"
}

collect_util_packages() {
  PKGS=()
  [[ "$UTILS_ENABLE_CORE" == "true" ]] && PKGS+=(vim nano less which tree ripgrep fd jq rsync)
  [[ "$UTILS_ENABLE_NET_TOOLS" == "true" ]] && PKGS+=(curl wget aria2 openssh openbsd-netcat iperf3 mtr)
  [[ "$UTILS_ENABLE_FS_TOOLS" == "true" ]] && PKGS+=(exfatprogs ntfs-3g dosfstools mtools)
  [[ "$UTILS_ENABLE_SYS_TOOLS" == "true" ]] && PKGS+=(htop iotop lsof strace pciutils usbutils dmidecode lm_sensors smartmontools nvme-cli)
  [[ "$UTILS_ENABLE_DOCS" == "true" ]] && PKGS+=(man-db man-pages texinfo)
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
  if [[ "$ASSUME_YES" == "true" ]]; then
    # These suppress edit/diff prompts non-interactively
    yflags+=(--noconfirm --answerdiff=None --answeredit=None)
  fi
  # shellcheck disable=SC2086
  yay -S ${yflags[*]} $AUR_PACKAGES

  local missing=()
  for p in $AUR_PACKAGES; do
    pacman -Qi "$p" >/dev/null 2>&1 || yay -Q "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [[ "${#missing[@]}" -eq 0 ]] || fail "AUR packages not installed: ${missing[*]}"
  ok "AUR packages installed"
}

setup_power_profiles_daemon() {
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
    *)   fail "Unknown PM_BACKEND='$PM_BACKEND' (use 'ppd' or 'tlp')" ;;
  esac
  ok "Power management configured (${PM_BACKEND})"
}

remove_conflicting_jack2_if_needed() {
  if pacman -Qi jack2 >/dev/null 2>&1; then
    log "Removing jack2 (conflicts with pipewire-jack)"
    pac_remove jack2
  fi
}

configure_audio() {
  remove_conflicting_jack2_if_needed
  pac pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rtkit alsa-utils alsa-ucm-conf sof-firmware
  verify_pkgs_installed pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber rtkit alsa-utils alsa-ucm-conf sof-firmware
  sudo systemctl enable --now rtkit-daemon.service
  systemctl is-active --quiet rtkit-daemon || fail "rtkit-daemon not active"
  systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service
  wait_for_condition 5 systemctl --user is-active pipewire    || fail "pipewire (user) not active"
  wait_for_condition 5 systemctl --user is-active wireplumber || fail "wireplumber (user) not active"
  aplay -l >/dev/null 2>&1 || fail "ALSA: no playback devices (aplay -l failed)"
  arecord -l >/dev/null 2>&1 || fail "ALSA: no capture devices (arecord -l failed)"
  command -v pactl >/dev/null 2>&1 || fail "pactl not available"
  local server
  server="$(pactl info 2>/dev/null | awk -F': ' '/Server Name/ {print $2}')"
  if [[ "${server:-}" != PulseAudio\ \(on\ PipeWire* ]]; then
    fail "Pulse shim not active (got: '${server:-none}')"
  fi
  if command -v wpctl >/dev/null 2>&1; then
    wpctl status | grep -q 'Sinks:'   || fail "PipeWire: no sinks detected"
    wpctl status | grep -q 'Sources:' || fail "PipeWire: no sources detected"
  fi
  ok "Audio stack ready (PipeWire/WirePlumber + Pulse/JACK shims, RTKit, ALSA)"
}

bluetooth_requirements() {
  pac linux-firmware bluez bluez-utils util-linux
  verify_pkgs_installed linux-firmware bluez bluez-utils util-linux
  sudo modprobe btusb || true
  if rfkill list 2>/dev/null | grep -A2 -i bluetooth | grep -qi 'Soft blocked: yes'; then
    sudo rfkill unblock bluetooth || fail "rfkill unblock failed"
  fi
}

configure_bluetooth() {
  bluetooth_requirements
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
  wait_for_condition 5 bash -c "bluetoothctl list | grep -q '^Controller'" || fail "No Bluetooth controller detected"
  if [[ "$BT_POWER_ON_NOW" == "true" ]]; then
    if ! bluetoothctl show | grep -q 'Powered: yes'; then
      printf 'power on\nquit\n' | bluetoothctl >/dev/null 2>&1 || true
      wait_for_condition 5 bash -c "bluetoothctl show | grep -q 'Powered: yes'" || fail "Bluetooth controller not powered"
    fi
  fi
  ok "Bluetooth controller present and powered"
}

main() {
  ensure_not_root
  ensure_cmd sudo
  pac_update
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

--- modules/40-gpu-setup.sh ---
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

--- modules/50-hyprland-setup.sh ---
#!/usr/bin/env bash
# meta: id=50 name="Hyprland + SDDM + portals + dotfiles" desc="Install Hyprland stack, configure SDDM (Wayland), portals, fonts/cursor, and symlink repo dotfiles" needs_root=false
#
# Arch Wiki references (keep accurate in comments):
# - Hyprland: https://wiki.archlinux.org/title/Hyprland
# - Wayland: https://wiki.archlinux.org/title/Wayland
# - xdg-desktop-portal: https://wiki.archlinux.org/title/Xdg-desktop-portal
# - Display manager (SDDM): https://wiki.archlinux.org/title/SDDM
# - Fonts: https://wiki.archlinux.org/title/Fonts
#
# Style: boring, explicit, reproducible; no --noconfirm unless ASSUME_YES=true.

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================
# Minimal config
# ================
ASSUME_YES="${ASSUME_YES:-true}"

# Derived repo paths (read-only)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILES_DIR="$REPO_ROOT/files/hyprland"

# Logging
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

ensure_not_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "Run this module as a regular user (it will sudo only for system changes)."
  fi
}
ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }

# Pacman wrappers (official repos)
pac() {
  local extra=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S "${extra[@]}" "$@"
}
pac_remove_if_present() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  for p in "$@"; do
    if pacman -Qi "$p" >/dev/null 2>&1; then
      sudo pacman -Rns "${extra[@]}" "$p"
    fi
  done
}
pac_update() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -Syu "${extra[@]}"
}

# yay wrapper (AUR) — only used if yay is installed already (module 30 handles yay)
yay_install() {
  command -v yay >/dev/null 2>&1 || { log "Note: yay not found — skipping AUR install for: $*"; return 0; }
  local yflags=(--needed)
  if [[ "$ASSUME_YES" == "true" ]]; then
    yflags+=(--noconfirm --answerdiff None --answerclean None --removemake)
    yay --save --answerdiff None --answerclean None --removemake >/dev/null 2>&1 || true
  fi
  yay -S "${yflags[@]}" "$@"
}

# Filesystem helpers
ensure_dir() { install -d -m "${2:-0755}" "$1"; }

symlink_dir_into_config() {
  # symlink_dir_into_config <repo_subdir> <target_subdir_name>
  local repo_sub="$1" name="$2"
  local src="$FILES_DIR/$repo_sub"
  local dest="$HOME/.config/$name"
  [[ -d "$src" ]] || { log "Note: $src not found; skipping $name"; return 0; }
  ensure_dir "$HOME/.config"
  if [[ -L "$dest" || -d "$dest" || -f "$dest" ]]; then
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
      ok "~/.config/$name already linked"
      return 0
    fi
    log "Backing up ~/.config/$name → ~/.config/${name}.bak.$(date +%s)"
    mv -f "$dest" "$HOME/.config/${name}.bak.$(date +%s)"
  fi
  ln -s "$(realpath "$src")" "$dest"
  ok "Linked $name config → $src"
}

symlink_system_file() {
  # symlink_system_file <repo_rel_path> <dest_abs_path> <mode>
  local repo_rel="$1" dest="$2" mode="${3:-0644}"
  local src="$FILES_DIR/$repo_rel"
  [[ -f "$src" ]] || { log "Note: $src not found; skipping $dest"; return 0; }
  # Create parent directory with root privileges when targeting system paths
  sudo install -d -m 0755 "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
      ok "$dest already linked"
      return 0
    fi
  fi
  if [[ -e "$dest" ]]; then
    log "Backing up $dest → ${dest}.bak.$(date +%s)"
    sudo mv -f "$dest" "${dest}.bak.$(date +%s)"
  fi
  sudo ln -s "$(realpath "$src")" "$dest"
  sudo chmod "$mode" "$dest" || true
  ok "Installed link: $dest → $src"
}

# ============================
# Step 1: Update (safe)
# ============================
update_system() {
  pac_update
  ok "System updated"
}

# ============================
# Step 2: Install Hyprland stack (official repos)
# ============================
install_wayland_stack() {
  # Replace 'clipman' with 'cliphist' + 'wl-clipboard' per Wayland best practice.
  pac hyprland waybar wofi mako wl-clipboard cliphist grim slurp swappy swaybg foot brightnessctl ttf-jetbrains-mono \
      xdg-desktop-portal xdg-desktop-portal-hyprland xdg-utils libinput qt6-wayland

  # Fonts (& symbols) from official repos only
  pac noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-nerd-fonts-symbols-mono

  # Optional: small GUI history (commented to keep deps minimal)
  # pac nwg-clipman

  # Verification
  command -v Hyprland >/dev/null 2>&1 || fail "Hyprland not on PATH"
  command -v waybar    >/dev/null 2>&1 || fail "waybar not on PATH"
  command -v cliphist  >/dev/null 2>&1 || fail "cliphist not on PATH"
  ok "Wayland/Hyprland core installed"
}

# ============================
# Step 3: Portals (ensure hyprland backend; remove conflicts)
# ============================
configure_portals() {
  # Remove backends that can hijack default selection on Hyprland sessions
  pac_remove_if_present xdg-desktop-portal-wlr xdg-desktop-portal-gnome xdg-desktop-portal-kde

  # Ensure hyprland backend is present (installed above) and base portal present
  pac xdg-desktop-portal xdg-desktop-portal-hyprland

  # Basic runtime verification (the backend binary presence)
  [[ -x /usr/lib/xdg-desktop-portal-hyprland ]] || log "Note: portal backend binary not found at expected path; it will be socket-activated in-session"
  ok "xdg-desktop-portal configured for Hyprland"
}

# ============================
# Step 4: SDDM (Wayland) → Hyprland session
# ============================
configure_sddm() {
  pac sddm qt6-wayland

  # Use repo-provided SDDM snippets if present
  symlink_system_file "sddm/10-wayland.conf" "/etc/sddm.conf.d/10-wayland.conf" 0644
  symlink_system_file "sddm/20-session.conf" "/etc/sddm.conf.d/20-session.conf" 0644

  # Minimal fallback if repo files are missing: set Session=hyprland
  if [[ ! -e /etc/sddm.conf.d/20-session.conf ]]; then
    sudo install -d -m 0755 /etc/sddm.conf.d
    printf '[Autologin]\n\n[Theme]\n\n[Users]\n\n[Wayland]\nSession=hyprland\n' \
      | sudo tee /etc/sddm.conf.d/20-session.conf >/dev/null
  fi

  # Enable SDDM
  sudo systemctl enable --now sddm.service
  systemctl is-active --quiet sddm || fail "sddm not active"
  ok "SDDM enabled for Wayland (Hyprland session)"
}

# ============================
# Step 5: Cursor theme (AUR: Bibata) — optional if yay is missing
# ============================
install_cursor_theme() {
  # Prefer the prebuilt binary AUR package for speed/reproducibility
  yay_install bibata-cursor-theme-bin || true

  # Install default index.theme from repo if provided (system-wide)
  symlink_system_file "icons/default/index.theme" "/usr/share/icons/default/index.theme" 0644
  ok "Cursor theme configured (Bibata if AUR available)"
}

# ============================
# Step 6: System environment snippets (Wayland-friendly)
# ============================
install_environment_snippets() {
  # Per Hyprland & Qt/GTK on Wayland guidance; repo provides environment.d files
  if [[ -d "$FILES_DIR/environment.d" ]]; then
    for f in "$FILES_DIR"/environment.d/*; do
      [[ -f "$f" ]] || continue
      local base; base="$(basename "$f")"
      symlink_system_file "environment.d/$base" "/etc/environment.d/$base" 0644
    done
    ok "System environment.d snippets installed"
  else
    log "Note: $FILES_DIR/environment.d not found — skipping environment snippets"
  fi
}

# ============================
# Step 7: User dotfiles (Hyprland, Waybar, etc.)
# ============================
install_user_dotfiles() {
  symlink_dir_into_config "hypr" "hypr"
  symlink_dir_into_config "waybar" "waybar"
  symlink_dir_into_config "wofi" "wofi"
  symlink_dir_into_config "mako" "mako"
  symlink_dir_into_config "foot" "foot"
  # Optional kitty config if you use it
  if [[ -d "$REPO_ROOT/files/kitty" ]]; then
    ensure_dir "$HOME/.config"
    if [[ -e "$HOME/.config/kitty" && ! -L "$HOME/.config/kitty" ]]; then
      log "Backing up ~/.config/kitty → ~/.config/kitty.bak.$(date +%s)"
      mv -f "$HOME/.config/kitty" "$HOME/.config/kitty.bak.$(date +%s)"
    fi
    ln -snf "$(realpath "$REPO_ROOT/files/kitty")" "$HOME/.config/kitty"
    ok "Linked kitty config"
  fi

  # Clipboard history — ensure Hyprland autostart stores history (if included in your startup.conf)
  # Verify cliphist exists:
  command -v cliphist >/dev/null 2>&1 || fail "cliphist missing (unexpected)"
  ok "Dotfiles linked under ~/.config"
}

# ============================
# Step 8: Verification (non-destructive)
# ============================
verify_end_to_end() {
  # Hyprland session file (from package) should exist
  [[ -f /usr/share/wayland-sessions/hyprland.desktop ]] || fail "Hyprland session .desktop missing"
  # Portal service files
  systemctl status xdg-desktop-portal.service >/dev/null 2>&1 || true
  ok "Basic verification complete (Hyprland session present; portals installed)"
}

# ================
# Main
# ================
main() {
  ensure_not_root
  ensure_cmd sudo

  update_system
  install_wayland_stack
  configure_portals
  configure_sddm
  install_cursor_theme
  install_environment_snippets
  install_user_dotfiles
  verify_end_to_end

  ok "Hyprland + SDDM setup complete"
}

main "$@"

--- modules/60-app-install.sh ---
#!/usr/bin/env bash
# meta: id=60 name="Desktop apps (pkg lists + symlinks)" desc="Install pacman & AUR packages from lists; create repo→user/system symlinks" needs_root=false
#
# Arch Wiki refs:
# - Pacman: https://wiki.archlinux.org/title/Pacman
# - Makepkg/AUR helpers: https://wiki.archlinux.org/title/AUR_helpers
# - XDG utils (defaults): https://wiki.archlinux.org/title/Xdg-utils
#
# Style: boring & explicit. No --noconfirm unless ASSUME_YES=true.
# Run as a regular user (yay/makepkg must not run as root).

set -Eeuo pipefail
nt=$'\n\t'; IFS=$nt

# ================================
# Config (override via env)
# ================================
ASSUME_YES="${ASSUME_YES:-true}"

# Repo root (auto-detect based on script location, like other modules)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# 1) Official repo packages (pacman)
#    Add as many as you like (space-separated). Example includes kitty.
PACMAN_PKGS="${PACMAN_PKGS:-kitty}"

# 2) AUR packages (yay)
#    Add as many as you like (space-separated). Example includes brave-bin.
YAY_PKGS="${YAY_PKGS:-brave-bin}"

# 3) Symlink spec: repo → dest pairs.
#    Format: each entry "RELATIVE_OR_ABS_SRC :: ABS_DEST"
#    - If SRC is relative, it's resolved against $REPO_ROOT.
#    - Dest directories are created if needed.
#    Example (commented):
#      SYMLINK_SPEC+=("files/hyprland/kitty/kitty.conf :: $HOME/.config/kitty/kitty.conf")
#      SYMLINK_SPEC+=("files/hyprland/environment.d/20-cursor.conf :: $HOME/.config/environment.d/20-cursor.conf")
declare -a SYMLINK_SPEC=(
  "files/kitty/kitty.conf :: $HOME/.config/kitty/kitty.conf"
)

# Optional: set a default browser desktop ID after installs (leave empty to skip)
# e.g., "brave-browser.desktop" or "firefox.desktop"
DEFAULT_BROWSER_DESKTOP_ID="${DEFAULT_BROWSER_DESKTOP_ID:-brave-browser.desktop}"

# ================================
# Logging / helpers
# ================================
log()  { printf '[%(%F %T)T] %s\n' -1 "$*" >&2; }
ok()   { log "OK: $*"; }
fail() { log "FAIL: $*"; exit 1; }

ensure_not_root() {
  # per Arch Wiki: makepkg must NOT run as root (yay uses makepkg)
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "Run this module as a regular user; it will sudo only for system changes."
  fi
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"; }

pac() {
  local extra=()
  [[ "$ASSUME_YES" == "true" ]] && extra+=(--noconfirm)
  sudo pacman -S --needed "${extra[@]}" "$@"
}

verify_pkgs_installed() {
  local missing=()
  for p in "$@"; do
    # accept either pacman-managed binaries or actual executables on PATH
    pacman -Qi "$p" >/dev/null 2>&1 || command -v "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [[ ${#missing[@]} -eq 0 ]] || fail "Packages not installed/available: ${missing[*]}"
}

ensure_dir() { install -d -m 0755 "$1"; }

symlink_overwrite() {
  # symlink_overwrite <source> <dest> ; creates parent dir of dest; replaces target
  local src="$1" dst="$2"
  [[ -e "$src" || -L "$src" ]] || fail "Symlink source missing: $src"
  ensure_dir "$(dirname -- "$dst")"
  ln -sfT -- "$src" "$dst"
}

resolve_src() {
  # Turn relative SRC into absolute path under $REPO_ROOT
  local src="$1"
  if [[ "$src" == /* ]]; then
    printf '%s\n' "$src"
  else
    printf '%s/%s\n' "$REPO_ROOT" "$src"
  fi
}

# ================================
# Package installation
# ================================
install_pacman_list() {
  [[ -n "${PACMAN_PKGS// /}" ]] || { ok "No pacman packages requested"; return 0; }
  log "Installing pacman packages: $PACMAN_PKGS"
  pac $PACMAN_PKGS
  # Verify using pacman -Qi; do not rely on PATH names (some are libraries)
  local miss=()
  for p in $PACMAN_PKGS; do pacman -Qi "$p" >/dev/null 2>&1 || miss+=("$p"); done
  [[ ${#miss[@]} -eq 0 ]] || fail "pacman packages missing after install: ${miss[*]}"
  ok "pacman packages installed"
}

install_yay_list() {
  [[ -n "${YAY_PKGS// /}" ]] || { ok "No AUR packages requested"; return 0; }
  ensure_cmd yay
  local yflags=(--needed)
  [[ "$ASSUME_YES" == "true" ]] && yflags+=(--noconfirm)
  log "Installing AUR packages: $YAY_PKGS"
  # shellcheck disable=SC2086
  yay -S ${yflags[*]} $YAY_PKGS
  # Verify via yay -Q (falls back to pacman -Qi in case of repo transitions)
  local miss=()
  for p in $YAY_PKGS; do
    yay -Q "$p" >/dev/null 2>&1 || pacman -Qi "$p" >/dev/null 2>&1 || miss+=("$p")
  done
  [[ ${#miss[@]} -eq 0 ]] || fail "AUR packages missing after install: ${miss[*]}"
  ok "AUR packages installed"
}

# ================================
# Symlink deployment
# ================================
deploy_symlinks() {
  [[ ${#SYMLINK_SPEC[@]} -gt 0 ]] || { ok "No symlinks requested"; return 0; }

  for pair in "${SYMLINK_SPEC[@]}"; do
    # Expect "SRC :: DST"
    IFS=':' read -r a b c <<<"$pair" || true
    # Rejoin to keep any extra ':' in paths; then split on ' :: '
    local src dst
    src="$(printf '%s:%s:%s' "$a" "$b" "$c" | sed -E 's/ :: .*$//')"
    dst="$(printf '%s:%s:%s' "$a" "$b" "$c" | sed -E 's/^.* :: //')"
    [[ -n "$src" && -n "$dst" ]] || fail "Bad SYMLINK_SPEC entry (expect 'SRC :: DST'): $pair"

    local abs_src; abs_src="$(resolve_src "$src")"
    symlink_overwrite "$abs_src" "$dst"
    ok "Symlinked: $dst → $abs_src"
  done

  ok "All requested symlinks applied"
}

# ================================
# Optional: set default browser
# ================================
maybe_set_default_browser() {
  [[ -n "$DEFAULT_BROWSER_DESKTOP_ID" ]] || { ok "Skipping default browser (none requested)"; return 0; }
  if command -v xdg-settings >/dev/null 2>&1 && command -v xdg-mime >/dev/null 2>&1; then
    xdg-settings set default-web-browser "$DEFAULT_BROWSER_DESKTOP_ID" || true
    xdg-mime default "$DEFAULT_BROWSER_DESKTOP_ID" x-scheme-handler/http
    xdg-mime default "$DEFAULT_BROWSER_DESKTOP_ID" x-scheme-handler/https
    ok "Default browser set to $DEFAULT_BROWSER_DESKTOP_ID (desktop/portals may override)"
  else
    log "Note: xdg-utils not present; default browser not set"
  fi
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

  install_pacman_list
  install_yay_list
  deploy_symlinks
  maybe_set_default_browser

  ok "Desktop apps + symlinks module complete"
}

main "$@"

--- files/hyprland/environment.d/10-qtct.conf ---
# Make Qt apps respect qt6ct in Wayland sessions
QT_QPA_PLATFORMTHEME=qt6ct

--- files/hyprland/environment.d/20-cursor.conf ---
# Cursor theme for Wayland/XWayland apps
XCURSOR_THEME=Bibata-Modern-Classic
XCURSOR_SIZE=24

--- files/hyprland/environment.d/30-hypr-nvidia-safe.conf ---
# NVIDIA "safe mode" for Wayland (disabled by default)
# Uncomment if you see cursor glitches/tearing:
# WLR_NO_HARDWARE_CURSORS=1
# __GLX_VENDOR_LIBRARY_NAME=nvidia
# __NV_PRIME_RENDER_OFFLOAD=1
# __VK_LAYER_NV_optimus=NVIDIA_only

--- files/hyprland/foot/foot.ini ---
# Minimal Foot terminal config
font=JetBrains Mono,monospace 11
dpi-aware=yes
pad=8x8
[cursor]
style=beam
blink=yes
[colors]
# Keep defaults; dark-friendly

--- files/hyprland/gtk/gtk-3.0/settings.ini ---
[Settings]
gtk-theme-name=Adwaita-dark
gtk-font-name=JetBrains Mono,monospace 11
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1

--- files/hyprland/gtk/gtk-4.0/settings.ini ---
[Settings]
gtk-theme-name=Adwaita-dark
gtk-font-name=JetBrains Mono,monospace 11
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1

--- files/hyprland/hypr/env.conf ---
# Session environment for Hyprland (sourced by hyprland.conf)
# Keep minimal; prefer /etc/environment.d or ~/.config/environment.d for globals.

# XDG portal: prefer hyprland backend (socket-activated)
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export GTK_THEME=Adwaita-dark

# NVIDIA "safe mode" (commented by default):
# export WLR_NO_HARDWARE_CURSORS=1
# export __GLX_VENDOR_LIBRARY_NAME=nvidia
# export __NV_PRIME_RENDER_OFFLOAD=1
# export __VK_LAYER_NV_optimus=NVIDIA_only

--- files/hyprland/hypr/hyprland.conf ---
# Hyprland minimal, safe-by-default config
# - Dark theme, Waybar, Wofi, Mako, Foot
# - Input via libinput (Wayland-native)
# - No NVIDIA hacks by default (see env.conf / environment.d)
#
# Key notation: SUPER = Mod key
# Per Arch Wiki: Hyprland (configuration basics)

# === Appearance ===
general {
  gaps_in = 8
  gaps_out = 16
  border_size = 2
  col.active_border = rgba(88aaffee)
  col.inactive_border = rgba(222222aa)
  layout = dwindle
}

decoration {
  active_opacity = 1.0
  inactive_opacity = 0.95
  rounding = 8

  blur {
    enabled = true
    size = 6
    passes = 1
  }
}

input {
  kb_layout = uk
  follow_mouse = 1

  touchpad {
    natural_scroll = true
    tap-to-click = true
    tap_button_map = lrm
    scroll_factor = 0.9
  }
}

animations {
  enabled = yes
  # keep defaults; nothing fancy
}

# === Input (libinput via Hyprland) ===
input {
  kb_layout = us
  follow_mouse = 1
  touchpad {
    natural_scroll = true
    tap = true
    tap_button_map = lrm
    scroll_factor = 0.9
  }
}

# === Monitors ===
# See files/hyprland/hypr/monitors.conf for examples
source = ~/.config/hypr/monitors.conf

# === Environment (per-user session) ===
# Place toggles (e.g., NVIDIA safe mode) in env.conf; we source it here.
source = ~/.config/hypr/env.conf

# === Autostart ===
# Lightweight Wayland stack: wallpaper, bar, notif daemon, portal compat if needed
source = ~/.config/hypr/startup.conf

# === Keybinds ===
$mod = SUPER

# Launchers
bind = $mod, Return, exec, foot
bind = $mod, D, exec, wofi --show drun

# Session controls
bind = $mod, Q, killactive,
bind = $mod SHIFT, E, exit,

# Tiling
bind = $mod, H, movefocus, l
bind = $mod, L, movefocus, r
bind = $mod, K, movefocus, u
bind = $mod, J, movefocus, d

# Workspaces
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5

# Screenshots (grim + slurp + swappy)
bind = , Print, exec, grim -g "$(slurp)" - | swappy -f -

# Volume (PipeWire/Pulse via wpctl)
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# Brightness (intel_backlight via brightnessctl, to be installed later if desired)
# bind = , XF86MonBrightnessUp,   exec, brightnessctl set +5%
# bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-


--- files/hyprland/hypr/monitors.conf ---
# Example monitor layout (leave empty to let Hyprland auto-detect)
# monitor=name, resolution@hz, position, scale
# To list names: hyprctl monitors
# monitor=eDP-1,1920x1200@60,0x0,1

--- files/hyprland/hypr/startup.conf ---
# Autostart for Hyprland (exec-once is recommended)
# Wallpaper
exec-once = swaybg -m fill -i ~/.config/wallpapers/default.jpg

# Bar + notifications
exec-once = waybar
exec-once = mako

# Clipboard
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store

--- files/hyprland/icons/default/index.theme ---
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=Bibata-Modern-Classic

--- files/hyprland/mako/config ---
# Dark mako notifications
font=JetBrains Mono 11
background-color=#1e1e2e
text-color=#cdd6f4
border-color=#89b4fa
width=350
height=140
default-timeout=5000
anchor=top-right
margin=10,10,0,0

--- files/hyprland/sddm/10-wayland.conf ---
[General]
DisplayServer=x11
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=/usr/bin/sddm-greeter

--- files/hyprland/sddm/20-session.conf ---
[Autologin]
# Optional: AutologinUser=
# Optional: AutologinSession=hyprland.desktop

[General]
# Default session shown in greeter
Session=hyprland.desktop

--- files/hyprland/wallpapers/README.txt ---
Put your wallpaper here as "default.jpg".
The setup module will reference: ~/.config/wallpapers/default.jpg

--- files/hyprland/waybar/config.jsonc ---
// Minimal dark Waybar config (JSONC)
{
  "layer": "top",
  "position": "top",
  "height": 28,
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network", "battery"],
  "clock": { "format": "{:%a %d %b  %H:%M}" },
  "pulseaudio": { "tooltip": true, "scroll-step": 5 },
  "network": { "format-wifi": "  {essid}", "format-ethernet": "  {ipaddr}", "format-disconnected": "" },
  "battery": { "format": "{capacity}% {icon}", "format-icons": ["","","","",""] }
}

--- files/hyprland/waybar/style.css ---
/* Dark, no external theme */
* { border: none; border-radius: 0; font-family: JetBrains Mono, monospace; font-size: 12pt; min-height: 0; }
window { background: #1e1e2e; color: #cdd6f4; }
#workspaces button { padding: 0 8px; color: #a6adc8; }
#workspaces button.active { color: #cdd6f4; border-bottom: 2px solid #89b4fa; }
#clock, #battery, #network, #pulseaudio { padding: 0 10px; }

--- files/hyprland/wofi/config ---
show=drun
prompt=Run:
allow_images=true
matching=fuzzy
insensitive=true
term=foot
hide_scroll=true
width=40%
height=40%

--- files/hyprland/wofi/style.css ---
window { margin: 0px; background-color: #1e1e2e; color: #cdd6f4; }
#input { margin: 8px; border: none; padding: 8px; background-color: #313244; }
#inner-box { margin: 8px; }
#entry { padding: 6px; }
#entry:selected { background-color: #45475a; }

--- files/kitty/kitty.conf ---
# Kitty minimal config (boring defaults, easy to extend)
# Docs: https://sw.kovidgoyal.net/kitty/conf/

font_family      JetBrains Mono
font_size        11.0

cursor_shape     beam
cursor_blink     yes
enable_audio_bell no

tab_bar_style    powerline
tab_bar_min_tabs 2
remember_window_size yes
confirm_os_window_close 0

# Copy/paste shortcuts
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard

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

