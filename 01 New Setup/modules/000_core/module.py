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
            "--download-timeout", "20",    # avoid premature timeouts
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
