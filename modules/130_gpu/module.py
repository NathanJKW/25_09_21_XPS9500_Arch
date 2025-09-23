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
options nvidia "NVreg_DynamicPowerManagement=0x02"
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
