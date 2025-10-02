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
