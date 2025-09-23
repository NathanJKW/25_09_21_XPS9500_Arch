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
