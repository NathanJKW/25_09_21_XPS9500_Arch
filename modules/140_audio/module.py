# modules/140_audio/module.py
#!/usr/bin/env python3
"""
140_audio — PipeWire/WirePlumber + SOF firmware (Intel cAVS) with optional Bluetooth
Version: 1.0.0

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


def _verify_stack() -> bool:
    """
    Basic verification:
    - pactl info -> Server Name mentions PipeWire
    - wpctl status -> has at least one Sink that is not 'auto_null' (best-effort)
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

    # wpctl status check (best-effort)
    try:
        ws = _run_user(["wpctl", "status"], check=False)
        if ws.returncode == 0 and ws.stdout:
            has_device = any(
                ("Sinks:" in line or "Audio" in line) and "auto_null" not in line
                for line in ws.stdout.splitlines()
            )
            if not has_device:
                print("⚠️  Verification: wpctl did not show a non-null sink; continuing but mark as warning.")
        else:
            print("⚠️  Verification: wpctl status unavailable.")
    except FileNotFoundError:
        print("⚠️  Verification: 'wpctl' not found (pipewire-cli not installed?)")

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
            "wireplumber",
            "alsa-utils",
            "alsa-ucm-conf",
            "sof-firmware",
            # handy mixers/inspectors
            "pavucontrol",
            #"pipewire-cli",  # provides wpctl
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

        # Enable system Bluetooth daemon if requested
        if enable_bt:
            if not _enable_system_units(["bluetooth.service"], run):
                _print("⚠️  Could not enable 'bluetooth.service'. You can enable it later with: sudo systemctl enable --now bluetooth.service")

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
