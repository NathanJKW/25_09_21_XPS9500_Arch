#!/usr/bin/env python3
"""
040_fonts — System-wide Nerd Font defaults (Option A)
Version: 1.0.1 (fix: ensure fc-cache available on minimal installs)

What this module does
---------------------
- Installs prerequisites (fontconfig) so `fc-cache` exists on minimal systems.
- Installs a Nerd Font family (JetBrainsMono Nerd Font) system-wide.
- Installs Nerd Fonts Symbols for robust glyph/icon fallback.
- Sets **JetBrainsMono Nerd Font** as the **system default for `monospace`** via Fontconfig.
- Enables Nerd Symbols fallback (so apps automatically get Nerd icons when base fonts lack glyphs).
- Refreshes font cache and prints a quick verification.

Notes
-----
- We intentionally only set the **monospace** generic family (Option A, recommended).
- A commented-out alternative (Option B) is provided to force Nerd Font for
  **monospace, sans-serif, and serif** — not recommended for desktop UI, but
  you can enable it by swapping the XML below.
"""
from __future__ import annotations

from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Callable

from utils.pacman import install_packages


FONTCONF_DIR = Path("/etc/fonts")
FONTCONF_LOCAL = FONTCONF_DIR / "local.conf"
FONTCONF_D = FONTCONF_DIR / "conf.d"
NERD_SYMBOLS_AVAIL = Path("/usr/share/fontconfig/conf.avail/10-nerd-font-symbols.conf")
NERD_SYMBOLS_LINK = FONTCONF_D / "10-nerd-font-symbols.conf"

# --- Fontconfig XML (Option A: monospace only) ---------------------------------
XML_OPTION_A = """<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <!-- Default monospace font -> JetBrainsMono Nerd Font -->
  <match target="pattern">
    <test qual="any" name="family"><string>monospace</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
</fontconfig>
"""

# --- Fontconfig XML (Option B: force all generics to Nerd Font) ----------------
# NOTE: This will make UI text monospace. Usually undesirable; use with care.
XML_OPTION_B_COMMENTED = """\n<!--
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any"><string>monospace</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
  <match target="pattern">
    <test name="family" qual="any"><string>sans-serif</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
  <match target="pattern">
    <test name="family" qual="any"><string>serif</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>JetBrainsMono Nerd Font</string>
    </edit>
  </match>
</fontconfig>
-->
"""


def _print_action(text: str) -> None:
    print(f"$ {text}")


def _ensure_dirs(run: Callable) -> bool:
    try:
        for d in (FONTCONF_DIR, FONTCONF_D):
            _print_action(f"mkdir -p {d}")
            res = run(["mkdir", "-p", str(d)], check=False, capture_output=True)
            if res.returncode != 0:
                if res.stdout:
                    print(res.stdout.rstrip())
                if res.stderr:
                    print(res.stderr.rstrip())
                return False
        return True
    except Exception as exc:
        print(f"ERROR: failed to ensure fontconfig dirs: {exc}")
        return False


def _write_local_conf(xml: str, run: Callable) -> bool:
    """Write XML to /etc/fonts/local.conf atomically using sudo runner."""
    try:
        with NamedTemporaryFile("w", delete=False, encoding="utf-8") as tmp:
            tmp.write(xml)
            tmp_path = Path(tmp.name)
        _print_action(f"install -m 0644 {tmp_path} {FONTCONF_LOCAL}")
        res = run(["install", "-m", "0644", str(tmp_path), str(FONTCONF_LOCAL)], check=False, capture_output=True)
        try:
            tmp_path.unlink(missing_ok=True)
        except Exception:
            pass
        if res.returncode != 0:
            if res.stdout:
                print(res.stdout.rstrip())
            if res.stderr:
                print(res.stderr.rstrip())
            return False
        return True
    except Exception as exc:
        print(f"ERROR: failed to write {FONTCONF_LOCAL}: {exc}")
        return False


def _enable_nerd_symbols(run: Callable) -> bool:
    """Symlink 10-nerd-fonts-symbols.conf into /etc/fonts/conf.d/ if available."""
    try:
        if not NERD_SYMBOLS_AVAIL.exists():
            print(f"⚠️  Nerd Symbols fontconfig file not found: {NERD_SYMBOLS_AVAIL}")
            return True  # Non-fatal; the main default still works.
        _print_action(f"ln -sf {NERD_SYMBOLS_AVAIL} {NERD_SYMBOLS_LINK}")
        res = run(["ln", "-sf", str(NERD_SYMBOLS_AVAIL), str(NERD_SYMBOLS_LINK)], check=False, capture_output=True)
        if res.returncode != 0:
            if res.stdout:
                print(res.stdout.rstrip())
            if res.stderr:
                print(res.stderr.rstrip())
            return False
        return True
    except Exception as exc:
        print(f"ERROR: failed to enable Nerd Symbols fallback: {exc}")
        return False


def _refresh_cache(run: Callable) -> bool:
    """
    Refresh the font cache. If fc-cache is missing (very minimal base),
    ensure fontconfig is installed or skip with a warning.
    """
    try:
        # Quick presence check (in case someone removed fontconfig after install)
        res_chk = run(["bash", "-lc", "command -v fc-cache || true"], check=False, capture_output=True)
        if "fc-cache" not in (res_chk.stdout or ""):
            print("⚠️  'fc-cache' not found. Is 'fontconfig' installed?")
            return False

        _print_action("fc-cache -f -v")
        res = run(["fc-cache", "-f", "-v"], check=False, capture_output=True)
        # fc-cache can be chatty; print on success/failure.
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
        return res.returncode == 0
    except Exception as exc:
        print(f"ERROR: failed to refresh font cache: {exc}")
        return False


def _verify(run: Callable) -> None:
    try:
        _print_action("fc-match monospace")
        res = run(["fc-match", "monospace"], check=False, capture_output=True)
        if res.stdout:
            print(res.stdout.rstrip())
        if res.stderr:
            print(res.stderr.rstrip())
    except Exception:
        pass


def install(run: Callable) -> bool:
    try:
        print("▶ [040_fonts] Installing and configuring system fonts (Nerd Font as monospace)…")

        # 1) Install required fonts + **fontconfig** so fc-cache exists on minimal installs
        packages = [
            "fontconfig",                 # provides fc-cache
            "ttf-jetbrains-mono-nerd",    # base monospace font
            "ttf-nerd-fonts-symbols",     # symbols-only fallback for icons
            # Optional: better emoji fallback (uncomment if desired)
            # "noto-fonts-emoji",
        ]
        if not install_packages(packages, run):
            print("ERROR: Failed to install required font packages")
            return False

        # 2) Ensure /etc/fonts and /etc/fonts/conf.d exist
        if not _ensure_dirs(run):
            return False

        # 3) Write /etc/fonts/local.conf (Option A)
        if not _write_local_conf(XML_OPTION_A, run):
            return False

        # (Optional) If you want Option B instead, replace above with XML_OPTION_B_COMMENTED content
        # and remove the surrounding HTML comment markers.

        # 4) Enable Nerd Symbols fallback rule
        if not _enable_nerd_symbols(run):
            return False

        # 5) Refresh cache and verify
        if not _refresh_cache(run):
            # Still attempt verification; but warn so user can `sudo pacman -S fontconfig`
            print("⚠️  Could not refresh font cache (fc-cache missing?). You can run: sudo pacman -S fontconfig && fc-cache -f -v")
        _verify(run)

        print("✔ [040_fonts] Font configuration complete. JetBrainsMono Nerd Font is the system monospace default.")
        return True
    except Exception as exc:
        print(f"ERROR: 040_fonts.install failed: {exc}")
        return False