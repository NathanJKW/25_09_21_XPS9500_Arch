<File Tree>
main.py
modules/00_core/module.py
modules/fonts/module.py
modules/github/module.py
modules/i3/module.py
modules/polybar/module.py
modules/sddm/module.py
modules/system/module.py
modules/x11/module.py
utils/module_loader.py
utils/pacman.py
utils/sudo_session.py
utils/symlinker.py
utils/yay.py

<Contents of included files>

--- main.py ---
from utils.sudo_session import start_sudo_session
from utils.module_loader import run_all

if __name__ == "__main__":
    run, close = start_sudo_session()
    try:
        run_all(run)  # will abort entirely if any duplicate order numbers are found
    finally:
        close()


--- modules/00_core/module.py ---


--- modules/fonts/module.py ---


--- modules/github/module.py ---


--- modules/i3/module.py ---


--- modules/polybar/module.py ---


--- modules/sddm/module.py ---


--- modules/system/module.py ---


--- modules/x11/module.py ---


--- utils/module_loader.py ---
# utils/module_loader.py
#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import sys
from pathlib import Path
from typing import List, Tuple, Any, Dict

MODULES_DIR = Path(__file__).resolve().parent.parent / "modules"

def _parse_order(folder_name: str) -> int | None:
    try:
        return int(folder_name.split("_", 1)[0])
    except (ValueError, IndexError):
        return None

def discover_modules() -> List[Tuple[int, str, Any]]:
    """
    Discover and import all `module.py` files under `modules/`.

    Returns:
        List of (order_number, folder_name, imported_module), sorted by order_number ASC.

    Duplicate order numbers are NOT filtered here—use `validate_no_duplicates`
    to enforce uniqueness before running.
    """
    discovered: List[Tuple[int, str, Any]] = []

    if not MODULES_DIR.exists():
        print(f"⚠️  Modules directory not found: {MODULES_DIR}")
        return discovered

    for folder in MODULES_DIR.iterdir():
        if not folder.is_dir():
            continue

        order = _parse_order(folder.name)
        if order is None:
            # Skip folders without a numeric prefix
            continue

        module_file = folder / "module.py"
        if not module_file.exists():
            continue

        module_name = f"modules.{folder.name}"
        spec = importlib.util.spec_from_file_location(module_name, module_file)
        if spec is None or spec.loader is None:
            print(f"⚠️  Could not load spec for {module_file}")
            continue

        mod = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = mod
        spec.loader.exec_module(mod)

        discovered.append((order, folder.name, mod))

    discovered.sort(key=lambda t: t[0])
    return discovered

def validate_no_duplicates(discovered: List[Tuple[int, str, Any]]) -> bool:
    """
    Check for duplicate order numbers. If found, print errors and return False.
    """
    by_order: Dict[int, List[str]] = {}
    for order, name, _ in discovered:
        by_order.setdefault(order, []).append(name)

    duplicates = {k: v for k, v in by_order.items() if len(v) > 1}
    if duplicates:
        print("❌ Duplicate module order numbers detected. Aborting without running any modules.")
        for order, names in sorted(duplicates.items()):
            print(f"   - {order}: {', '.join(sorted(names))}")
        return False
    return True

def run_all(run_callable) -> None:
    """
    Discover modules, ensure unique order numbers, and call `install(run_callable)`
    on each module in order. Modules without an `install` callable are skipped.

    If duplicates are detected, nothing is run.
    """
    discovered = discover_modules()

    if not validate_no_duplicates(discovered):
        return  # Do not run anything when duplicates exist.

    for order, name, mod in discovered:
        fn = getattr(mod, "install", None)
        if callable(fn):
            print(f"▶ [{order}] Running {name}.install()")
            fn(run_callable)
        else:
            print(f"⚠️  [{order}] Skipping {name}: no callable install() found.")


--- utils/pacman.py ---
# utils/pacman.py
#!/usr/bin/env python3
"""
Pacman install helper that uses a provided sudo session runner.
Version: 2.0.0

What the module does
--------------------
Provides a tiny, safe wrapper to install packages with the Arch `pacman`
package manager. It **expects** you to pass the `run` function returned by
`utils.sudo_session.start_sudo_session()`, so all commands are executed with
root privileges via `sudo -n`.

Key behavior
------------
- Uses: pacman -S --needed --noconfirm <packages...>
  * `--needed` makes the operation idempotent (already-installed packages are skipped).
- Prints shell-like actions before running, surfaces useful output on success/failure.
- Robust error handling: exceptions are caught, clear messages are printed,
  and the function returns `True` (success) or `False` (failure).

Public API
----------
install_packages(packages: list[str], run: Callable) -> bool
    Install one or more packages using the provided sudo runner.

Example
-------
from utils.sudo_session import start_sudo_session
from utils.pacman import install_packages

run, close = start_sudo_session()
try:
    ok = install_packages(["git", "vim"], run)
    if not ok:
        print("Failed to install required packages")
finally:
    close()
"""

from __future__ import annotations

from typing import Callable, Iterable, List
import sys


def _print_action(command_like: str) -> None:
    """Print a shell-like command to the terminal to show what is happening."""
    print(f"$ {command_like}")


def _print_error(message: str) -> None:
    """Print a clear error message to stderr so it stands out in logs."""
    print(f"ERROR: {message}", file=sys.stderr)


def _join(cmd: Iterable[str]) -> str:
    """Join a command list into a readable shell-like string (for logging only)."""
    return " ".join(str(part) for part in cmd)


def install_packages(packages: List[str], run: Callable) -> bool:
    """
    Install one or more packages using pacman in an idempotent way.

    Arguments:
        packages:
            A list of package names (strings), e.g., ["vim", "git", "curl"].
        run:
            The sudo runner callable returned by `start_sudo_session()`.
            It must accept a list[str] command and execute it with sudo.

    Returns:
        True if the installation command completed successfully, False otherwise.

    Behavior:
        - Treats empty input as a successful no-op.
        - Uses 'pacman -S --needed --noconfirm' to avoid reinstalling present packages.
        - Prints actions, captures and prints output on errors.
    """
    try:
        # Sanitize input first: drop non-strings/empties; allow empty list as no-op.
        cleaned = [p.strip() for p in packages if isinstance(p, str) and p.strip()]
        if not cleaned:
            _print_action("pacman -S --needed --noconfirm  # (no packages provided; nothing to do)")
            return True

        cmd = ["pacman", "-S", "--needed", "--noconfirm", *cleaned]
        _print_action(_join(cmd))

        # Use the sudo-session runner (executes `sudo -n <cmd>` under the hood).
        result = run(cmd, check=False, capture_output=True)

        if result.returncode != 0:
            _print_error("pacman failed with a non-zero exit status.")
            if result.stdout:
                print(result.stdout.rstrip())
            if result.stderr:
                _print_error(result.stderr.rstrip())
            return False

        # On success, print any stdout (pacman can be chatty).
        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            # pacman may warn to stderr even on success.
            print(result.stderr.rstrip(), file=sys.stderr)

        return True

    except Exception as exc:
        _print_error(f"Unexpected error running pacman: {exc}")
        return False


# Backward-compat alias for code that imported the old name.
installpackage = install_packages


if __name__ == "__main__":
    # Demonstration of usage with the sudo session.
    from utils.sudo_session import start_sudo_session

    run, close = start_sudo_session()
    try:
        print("👟 Demo: installing 'htop' (idempotent).")
        success = install_packages(["htop"], run)
        print(f"Result: {'success' if success else 'failure'}")
    finally:
        close()


--- utils/sudo_session.py ---
#!/usr/bin/env python3
from __future__ import annotations
import atexit
import getpass
import subprocess
import threading
from typing import Iterable, Optional

def _seed_sudo_timestamp() -> None:
    """Prompt once and seed sudo's timestamp cache; drop password immediately."""
    pw = getpass.getpass("sudo password: ")
    try:
        subprocess.run(
            ["sudo", "-S", "-v"],
            input=pw + "\n",
            text=True,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    finally:
        pw = None  # drop reference ASAP

def _keepalive_loop(stop_evt: threading.Event, interval: int) -> None:
    while not stop_evt.is_set():
        # Use -n to avoid blocking if the timestamp ever expires.
        subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        stop_evt.wait(interval)

def start_sudo_session(keepalive_interval_sec: int = 60):
    """
    Start a sudo session that never stores the password in memory.
    Returns (run, close).

    run(cmd, *, check=True, capture_output=False, cwd=None, env=None, input_text=None)
      -> subprocess.CompletedProcess
    """
    _seed_sudo_timestamp()

    stop_evt = threading.Event()
    t = threading.Thread(
        target=_keepalive_loop,
        args=(stop_evt, max(10, keepalive_interval_sec)),
        name="sudo-keepalive",
        daemon=True,
    )
    t.start()

    def close() -> None:
        if not stop_evt.is_set():
            stop_evt.set()
            t.join(timeout=2)
        subprocess.run(["sudo", "-K"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    atexit.register(close)

    def run(cmd: Iterable[str],
            *,
            check: bool = True,
            capture_output: bool = False,
            cwd: Optional[str] = None,
            env: Optional[dict] = None,
            input_text: Optional[str] = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["sudo", "-n", *cmd],
            check=check,
            capture_output=capture_output,
            text=True,
            cwd=cwd,
            env=env,
            input=input_text
        )

    return run, close


--- utils/symlinker.py ---
# utils/symlinker.py
#!/usr/bin/env python3
"""
Symlink utility that can use your sudo session runner for privileged paths.
Version: 2.0.0

What the module does
--------------------
Provides two high-level helpers for creating symlinks safely:

1) symlink_directory(source_dir, link_path, *, run=None, use_relative=False)
   - Creates ONE symlink that points to an entire directory.

2) symlink_tree_files(source_dir, dest_dir, *, run=None, use_relative=False)
   - Mirrors a directory tree by creating real directories in the destination,
     and placing symlinks for files inside those directories.

Sudo-session compatibility
--------------------------
If you pass `run` (from `start_sudo_session()`), *all filesystem actions that
need privileges* are performed via shell commands executed by that runner
(e.g., `mkdir -p`, `mv`, `ln -s`).  
If `run` is omitted, the module uses Python's `os`/`shutil` APIs and will require
the current process to have sufficient permissions.

Key behavior
------------
- Per-run backups:
  Existing destinations are moved to:
    <this_module_dir>/backup/<YYYYmmdd-HH%M%S>/<original/absolute/path/without/leading/slash>
- Idempotent by design: destinations are backed up then recreated consistently.
- Clear printed actions; robust error handling with True/False returns.

Example
-------
from utils.sudo_session import start_sudo_session
from utils.symlinker import symlink_directory, symlink_tree_files

run, close = start_sudo_session()
try:
    symlink_directory("/opt/myrepo/app", "/etc/myapp", run=run)
    symlink_tree_files("/opt/myrepo/config", "/etc/myapp", run=run)
finally:
    close()
"""

from __future__ import annotations

import os
import sys
import shutil
from pathlib import Path
from datetime import datetime
from typing import Callable, Optional, Tuple


# Timestamp used to group all backups for one execution.
RUN_TIMESTAMP = datetime.now().strftime("%Y%m%d-%H%M%S")


# ------------------------------ Printing helpers ------------------------------

def _print_action(command_like: str) -> None:
    """Print a shell-like command to the terminal to show what is happening."""
    print(f"$ {command_like}")


def _print_error(message: str) -> None:
    """Print a clear error message to stderr so it stands out in logs."""
    print(f"ERROR: {message}", file=sys.stderr)


def _script_dir() -> Path:
    """Return the absolute path to the directory where this script lives."""
    return Path(__file__).resolve().parent


# ------------------------------ Runner helpers ------------------------------

def _run_or_os(run: Optional[Callable], cmd: list[str]) -> Tuple[bool, Optional[str], Optional[str]]:
    """
    Execute a command either through the provided sudo-session runner or via subprocess.

    Returns:
        (ok, stdout_or_none, stderr_or_none)
    """
    try:
        if run is None:
            # No sudo runner provided -> use subprocess directly.
            import subprocess
            res = subprocess.run(cmd, check=False, text=True, capture_output=True)
            return (res.returncode == 0, res.stdout, res.stderr)
        else:
            # Use provided sudo runner (already wraps command with 'sudo -n').
            res = run(cmd, check=False, capture_output=True)
            return (res.returncode == 0, res.stdout, res.stderr)
    except Exception as exc:
        return (False, None, str(exc))


def _ensure_dir_exists(path: Path, *, run: Optional[Callable]) -> bool:
    try:
        if path.exists():
            if path.is_dir():
                return True
            _print_error(f"Path exists but is not a directory: {path}")
            return False
        _print_action(f"mkdir -p {path}")
        if run is None:
            path.mkdir(parents=True, exist_ok=True)
        else:
            ok, out, err = _run_or_os(run, ["mkdir", "-p", str(path)])
            if not ok:
                if out: print(out.rstrip())
                if err: _print_error(err.rstrip())
                return False
        return True
    except Exception as exc:
        _print_error(f"Failed to create directory '{path}': {exc}")
        return False

def _backup_root_dir() -> Path:
    """Compute backup root folder for this run."""
    return _script_dir() / "backup" / RUN_TIMESTAMP


def _backup_existing_path(target: Path, *, run: Optional[Callable]) -> bool:
    """
    Move an existing path (file/dir/symlink) into the per-run backup directory.
    Returns True if moved (or nothing to move), False on failure.
    """
    try:
        if not target.exists() and not target.is_symlink():
            return True  # Nothing to back up.

        backup_root = _backup_root_dir()
        backup_dest = backup_root / Path(str(target).lstrip(os.sep))

        if not _ensure_dir_exists(backup_dest.parent, run=run):
            return False

        _print_action(f"mv {target} {backup_dest}")
        if run is None:
            # Use shutil.move to handle files/dirs/symlinks.
            backup_root.mkdir(parents=True, exist_ok=True)
            shutil.move(str(target), str(backup_dest))
        else:
            # Ensure backup root exists via runner too.
            ok, out, err = _run_or_os(run, ["mkdir", "-p", str(backup_dest.parent)])
            if not ok:
                if out:
                    print(out.rstrip())
                if err:
                    _print_error(err.rstrip())
                return False
            ok, out, err = _run_or_os(run, ["mv", str(target), str(backup_dest)])
            if not ok:
                if out:
                    print(out.rstrip())
                if err:
                    _print_error(err.rstrip())
                return False

        return True
    except Exception as exc:
        _print_error(f"Failed to back up '{target}': {exc}")
        return False


def _compute_symlink_target(source: Path, link: Path, use_relative: bool) -> str:
    """Compute absolute/relative path to store in the symlink."""
    if use_relative:
        return os.path.relpath(source.resolve(), start=link.parent.resolve())
    return str(source.resolve())


def _create_symlink(source: Path, link: Path, *, run: Optional[Callable], use_relative: bool) -> bool:
    """Create the symlink (backing up an existing path first)."""
    try:
        if not source.exists() and not source.is_symlink():
            _print_error(f"Source does not exist: {source}")
            return False

        if not _ensure_dir_exists(link.parent, run=run):
            return False

        # Backup existing destination, if present.
        if link.exists() or link.is_symlink():
            if not _backup_existing_path(link, run=run):
                return False

        target = _compute_symlink_target(source, link, use_relative)
        _print_action(f"ln -s {target} {link}")

        if run is None:
            os.symlink(target, str(link))
        else:
            ok, out, err = _run_or_os(run, ["ln", "-s", target, str(link)])
            if not ok:
                if out:
                    print(out.rstrip())
                if err:
                    _print_error(err.rstrip())
                return False

        return True
    except FileExistsError:
        _print_error(f"Destination already exists and could not be replaced: {link}")
        return False
    except Exception as exc:
        _print_error(f"Failed to create symlink '{link}': {exc}")
        return False


# ------------------------------ Public API ------------------------------

def symlink_directory(
    source_dir: Path | str,
    link_path: Path | str,
    *,
    run: Optional[Callable] = None,
    use_relative: bool = False
) -> bool:
    """
    Create a single symlink that points to an entire directory.

    Arguments:
        source_dir:
            Directory the symlink should point to.
        link_path:
            Path of the symlink to create (e.g., /etc/myapp -> /opt/myrepo/myapp).
        run:
            Optional sudo-session runner. If provided, shell commands are executed
            via `sudo -n`. If omitted, Python's filesystem APIs are used.
        use_relative:
            If True, create a relative symlink; otherwise absolute (default).

    Returns:
        True if the symlink was created successfully, False otherwise.
    """
    src = Path(source_dir)
    dst = Path(link_path)

    if not src.exists() and not src.is_symlink():
        _print_error(f"Source directory does not exist: {src}")
        return False
    if src.exists() and not src.is_dir():
        _print_error(f"Source path exists but is not a directory: {src}")
        return False

    return _create_symlink(src, dst, run=run, use_relative=use_relative)


def symlink_tree_files(
    source_dir: Path | str,
    dest_dir: Path | str,
    *,
    run: Optional[Callable] = None,
    use_relative: bool = False
) -> bool:
    """
    Mirror a directory tree by creating real directories under `dest_dir` and
    placing symlinks for files found under `source_dir`.

    Arguments:
        source_dir:
            Root directory to read files from.
        dest_dir:
            Root directory to mirror into (directories are real; files are symlinks).
        run:
            Optional sudo-session runner. If provided, operations use shell commands
            through `sudo -n`. If omitted, Python's filesystem APIs are used.
        use_relative:
            If True, create relative symlinks for files; otherwise absolute.

    Returns:
        True if ALL files were processed successfully, False if ANY step failed.
    """
    try:
        src_root = Path(source_dir).resolve()
        dst_root = Path(dest_dir).resolve()

        if not src_root.exists() or not src_root.is_dir():
            _print_error(f"Source directory does not exist or is not a directory: {src_root}")
            return False

        if not _ensure_dir_exists(dst_root, run=run):
            return False

        overall_ok = True

        for root, _dirs, files in os.walk(src_root):
            root_path = Path(root)
            relative = root_path.relative_to(src_root)
            mirrored_dir = dst_root / relative

            if not _ensure_dir_exists(mirrored_dir, run=run):
                overall_ok = False
                continue

            for filename in files:
                src_file = root_path / filename
                dst_link = mirrored_dir / filename

                if not src_file.exists() and not src_file.is_symlink():
                    _print_error(f"Source file missing, skipping: {src_file}")
                    overall_ok = False
                    continue

                if not _create_symlink(src_file, dst_link, run=run, use_relative=use_relative):
                    overall_ok = False

        return overall_ok
    except Exception as exc:
        _print_error(f"Unexpected error while mirroring symlinks: {exc}")
        return False


if __name__ == "__main__":
    # Demonstration using sudo-session for system paths (adjust paths for your machine).
    from utils.sudo_session import start_sudo_session

    run, close = start_sudo_session()
    try:
        print("👟 Demo: create /tmp/demo-target and link it to /etc/demo-link (requires sudo).")
        # Setup a safe demo directory in /tmp as the "source".
        src = Path("/tmp/demo-target")
        if not src.exists():
            _print_action(f"mkdir -p {src}")
            src.mkdir(parents=True, exist_ok=True)
            (src / "example.txt").write_text("hello\n", encoding="utf-8")

        ok1 = symlink_directory(src, "/etc/demo-link", run=run)
        print(f"Directory link result: {'success' if ok1 else 'failure'}")

        ok2 = symlink_tree_files(src, "/etc/demo-tree", run=run)
        print(f"Tree mirror result: {'success' if ok2 else 'failure'}")
    finally:
        close()


--- utils/yay.py ---
# utils/yay.py
#!/usr/bin/env python3
"""
Yay install helper (AUR) that is compatible with your sudo session flow.
Version: 2.0.0

What the module does
--------------------
Installs packages via the AUR helper `yay` in an idempotent way.

Sudo-session compatibility
--------------------------
This function accepts a `run` parameter for API symmetry with `pacman`, but
**intentionally ignores it** and runs `yay` as the **current normal user**.
That's because `yay` should *not* be invoked with sudo; it elevates internally
when necessary. If your process has an active sudo timestamp (seeded by your
`sudo_session`), yay's internal `sudo` calls will be non-interactive.

Key behavior
------------
- Uses: yay -S --needed --noconfirm <packages...>
  * `--needed` makes the operation idempotent (already-installed packages are skipped).
- Prints shell-like actions before running.
- Catches exceptions, prints clear errors, returns True/False.
- Preflight note: we warn if non-interactive sudo is not yet available, so the user
  understands a prompt might occur (useful outside your main flow).

Public API
----------
install_packages(packages: list[str], run=None) -> bool
    Install one or more packages using yay as the current user.

Example
-------
# Normal usage (yay runs as your user; sudo timestamp seeded elsewhere)
from utils.yay import install_packages
ok = install_packages(["google-chrome", "visual-studio-code-bin"])
"""

from __future__ import annotations

from typing import Iterable, List
import shutil
import subprocess
import sys


def _print_action(command_like: str) -> None:
    """Print a shell-like command to the terminal to show what is happening."""
    print(f"$ {command_like}")


def _print_error(message: str) -> None:
    """Print a clear error message to stderr so it stands out in logs."""
    print(f"ERROR: {message}", file=sys.stderr)


def _join(cmd: Iterable[str]) -> str:
    """Join a command list into a readable shell-like string (for logging only)."""
    return " ".join(str(part) for part in cmd)


def _check_yay_available() -> bool:
    """
    Verify that the 'yay' binary is available in PATH.

    Returns:
        True if yay is found; False otherwise (with an error printed).
    """
    yay_path = shutil.which("yay")
    if yay_path is None:
        _print_error("The 'yay' command was not found in PATH. Install yay before using this module.")
        return False
    return True


def _noninteractive_sudo_available() -> bool:
    """
    Return True if sudo can be used without prompting (timestamp valid or NOPASSWD).
    We probe with a harmless no-op: `sudo -n true`.
    """
    try:
        res = subprocess.run(["sudo", "-n", "true"], check=False, capture_output=True, text=True)
        return res.returncode == 0
    except Exception:
        return False


def install_packages(packages: List[str], run=None) -> bool:
    """
    Install one or more packages using yay (AUR helper) in an idempotent way.

    Arguments:
        packages:
            A list of package names (strings), e.g., ["google-chrome", "visual-studio-code-bin"].
        run:
            Ignored (accepted for API symmetry with pacman). yay must run as a normal user.

    Returns:
        True on success (including no-op for empty list), False on failure.

    Behavior:
        - Treats empty input as a successful no-op.
        - Uses 'yay -S --needed --noconfirm' to avoid reinstalling present packages.
        - Prints actions and surfaces diagnostics on failure.
    """
    try:
        if not _check_yay_available():
            return False

        cleaned = [p.strip() for p in packages if isinstance(p, str) and p.strip()]
        if not cleaned:
            _print_action("yay -S --needed --noconfirm  # (no packages provided; nothing to do)")
            return True

        # Helpful heads-up when running outside your main seeded flow.
        if not _noninteractive_sudo_available():
            print(
                "ℹ️  Non-interactive sudo is not active yet. "
                "If yay needs elevation, it may prompt unless a sudo timestamp is seeded."
            )

        cmd = ["yay", "-S", "--needed", "--noconfirm", *cleaned]
        _print_action(_join(cmd))

        # Run as the current user (NOT via sudo). yay will escalate internally if needed.
        result = subprocess.run(cmd, check=False, text=True, capture_output=True)

        if result.returncode != 0:
            _print_error("yay failed with a non-zero exit status.")
            if result.stdout:
                print(result.stdout.rstrip())
            if result.stderr:
                _print_error(result.stderr.rstrip())
            return False

        if result.stdout:
            print(result.stdout.rstrip())
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)

        return True

    except Exception as exc:
        _print_error(f"Unexpected error running yay: {exc}")
        return False


# Backward-compat alias for code that imported the old name.
installpackage = install_packages


if __name__ == "__main__":
    # Demonstration (runs as your normal user).
    print("👟 Demo: installing 'bat' via yay (idempotent).")
    ok = install_packages(["bat"])
    print(f"Result: {'success' if ok else 'failure'}")

