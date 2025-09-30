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
