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
