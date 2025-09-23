<File Tree>
01 New Setup/main.py
01 New Setup/modules/00_core/module.py
01 New Setup/modules/fonts/module.py
01 New Setup/modules/github/module.py
01 New Setup/modules/i3/module.py
01 New Setup/modules/polybar/module.py
01 New Setup/modules/sddm/module.py
01 New Setup/modules/system/module.py
01 New Setup/modules/x11/module.py
01 New Setup/utils/module_loader.py
01 New Setup/utils/pacman.py
01 New Setup/utils/sudo_session.py
01 New Setup/utils/symlinker.py
01 New Setup/utils/yay.py
scripts/audio.sh
scripts/fonts.sh
scripts/sddminstall.sh
scripts/symlinker.sh
scripts/system_context.sh

<Contents of included files>

--- 01 New Setup/main.py ---
# main.py
#!/usr/bin/env python3
"""
Dotfiles / System Provisioning Entry Point
Version: 1.0.0

What the module does
--------------------
This is the main entry point for running all provisioning "modules" located
under the ./modules directory. It:

1) Starts a sudo keep-alive session (without keeping your password in memory).
2) Discovers and validates modules by their numeric order (e.g., 00_core, 10_foo).
3) Executes each module's `install(run)` function in ascending order.
4) Cleanly tears down the sudo session.

Behavior & Safety
-----------------
- Idempotent by design: individual modules are expected to use safe flags
  (e.g., pacman/yay `--needed`) and/or create backups before overwriting.
- Robust error handling: execution prints clear shell-like actions and
  returns a success/failure code (printed), without unhandled crashes.
"""

from __future__ import annotations

from utils.sudo_session import start_sudo_session
from utils.module_loader import run_all


def main() -> bool:
    """
    Orchestrate the provisioning run.

    Returns:
        True if all modules ran successfully, False otherwise.
    """
    # Start the sudo session (asks for your password once, then keeps it alive).
    run, close = start_sudo_session()

    try:
        # Run all discovered modules. The loader handles duplicate order detection
        # and will abort early in that case.
        success = run_all(run)
        print(f"\n✅ Overall result: {'SUCCESS' if success else 'FAILURE'}")
        return success
    except Exception as exc:
        # Catch-all to ensure we don't crash without context.
        print(f"ERROR: Unexpected exception in main(): {exc}")
        return False
    finally:
        # Always close the sudo session to clear timestamps.
        close()


if __name__ == "__main__":
    # Running as a script.
    ok = main()
    # Exit code mirrors success/failure so this can be scripted.
    import sys
    sys.exit(0 if ok else 1)


--- 01 New Setup/modules/00_core/module.py ---
# modules/00_core/module.py
#!/usr/bin/env python3
"""
Core Bootstrap Module
Version: 1.0.0

What the module does
--------------------
Sets up essentials required by other modules. Keep this minimal and safe.
Typical tasks (examples; uncomment/implement as needed):
- Ensure base packages are present.
- Create foundational directories.
- Seed configs used by subsequent modules.

This file is intentionally conservative—fill in real tasks once you define them.
"""

from __future__ import annotations
from pathlib import Path
from typing import Callable


def install(run: Callable) -> bool:
    """
    Perform core bootstrap steps.

    Arguments:
        run:
            The sudo-runner returned from `start_sudo_session()`. Call it with a
            list[str] command to run as root non-interactively.

    Returns:
        True on success, False on failure.
    """
    try:
        print("▶ [00_core] Starting core bootstrap...")

        # Example: create a common directory (idempotent).
        # We print our action like a shell command for clarity.
        target_dir = Path("/etc/dotfiles")
        print(f"$ mkdir -p {target_dir}")
        res = run(["mkdir", "-p", str(target_dir)], check=False, capture_output=True)
        if res.returncode != 0:
            print("ERROR: Failed to create /etc/dotfiles")
            if res.stdout:
                print(res.stdout.rstrip())
            if res.stderr:
                print(res.stderr.rstrip())
            return False

        # Example: you could install baseline packages (commented until you decide).
        # from utils.pacman import install_packages
        # if not install_packages(["git", "curl"], run):
        #     return False

        print("✔ [00_core] Core bootstrap complete.")
        return True
    except Exception as exc:
        print(f"ERROR: 00_core.install failed: {exc}")
        return False


--- 01 New Setup/modules/fonts/module.py ---


--- 01 New Setup/modules/github/module.py ---


--- 01 New Setup/modules/i3/module.py ---


--- 01 New Setup/modules/polybar/module.py ---


--- 01 New Setup/modules/sddm/module.py ---


--- 01 New Setup/modules/system/module.py ---


--- 01 New Setup/modules/x11/module.py ---


--- 01 New Setup/utils/module_loader.py ---
# utils/module_loader.py
# utils/module_loader.py
#!/usr/bin/env python3
"""
Module Discovery and Runner
Version: 2.0.0

What the module does
--------------------
- Discovers `module.py` files inside ./modules/* folders that start with a
  numeric order prefix (e.g., 00_core, 10_fonts).
- Validates there are no duplicate order numbers (strictly enforced).
- Imports each module safely, and sequentially calls its `install(run)` function.

Behavior
--------
- Prints shell-like actions and status markers.
- Robust error handling: continues discovery despite individual import issues,
  aborts run if duplicate orders are detected, stops on the first install failure.
- Returns True if all ran successfully, False otherwise.
"""

from __future__ import annotations
import importlib.util
import sys
from pathlib import Path
from typing import List, Tuple, Any, Dict, Optional

MODULES_DIR = Path(__file__).resolve().parent.parent / "modules"


def _print_action(text: str) -> None:
    """Print a shell-like action line."""
    print(f"$ {text}")


def _parse_order(folder_name: str) -> Optional[int]:
    """
    Extract the numeric order prefix from a folder name like '10_fonts'.

    Returns:
        The integer order, or None if the name doesn't start with a number.
    """
    try:
        return int(folder_name.split("_", 1)[0])
    except (ValueError, IndexError):
        return None


def discover_modules() -> List[Tuple[int, str, Any]]:
    """
    Discover and import all `module.py` files under `modules/`.

    Returns:
        A list of (order_number, folder_name, imported_module), sorted by order ASC.

    Notes:
        - Duplicate order numbers are NOT filtered here—use `validate_no_duplicates`
          before running to enforce uniqueness.
        - Import errors are reported but do not stop discovery of other modules.
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
            print(f"⚠️  [{folder.name}] Skipping: module.py not found.")
            continue

        module_name = f"modules.{folder.name}"
        try:
            _print_action(f"import {module_name}  # from {module_file}")
            spec = importlib.util.spec_from_file_location(module_name, module_file)
            if spec is None or spec.loader is None:
                print(f"⚠️  Could not load spec for {module_file}")
                continue

            mod = importlib.util.module_from_spec(spec)
            sys.modules[module_name] = mod
            spec.loader.exec_module(mod)  # noqa: S102 - trusted local file
            discovered.append((order, folder.name, mod))
        except Exception as exc:
            print(f"ERROR: Failed to import {module_file}: {exc}")
            continue

    discovered.sort(key=lambda t: t[0])
    return discovered


def validate_no_duplicates(discovered: List[Tuple[int, str, Any]]) -> bool:
    """
    Check for duplicate order numbers.

    Arguments:
        discovered: Output from `discover_modules()`.

    Returns:
        True if no duplicates, False otherwise (and prints diagnostics).
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


def run_all(run_callable) -> bool:
    """
    Discover modules, ensure unique order numbers, and call `install(run_callable)`
    on each module in order.

    Arguments:
        run_callable:
            The sudo-runner returned by `start_sudo_session()`.

    Returns:
        True if all modules ran successfully, False otherwise.

    Behavior:
        - If duplicates are detected, nothing is run and False is returned.
        - Stops on the first install() failure to avoid partial configuration.
        - Modules without an `install` callable are skipped with a warning.
    """
    try:
        discovered = discover_modules()

        if not validate_no_duplicates(discovered):
            return False  # Do not run anything when duplicates exist.

        for order, name, mod in discovered:
            fn = getattr(mod, "install", None)
            if callable(fn):
                print(f"▶ [{order}] Running {name}.install()")
                ok = False
                try:
                    ok = bool(fn(run_callable))
                except Exception as exc:
                    print(f"ERROR: Exception while running {name}.install(): {exc}")
                    ok = False

                if not ok:
                    print(f"❌ Stopping: {name}.install() reported failure.")
                    return False
                print(f"✔ [{order}] {name}.install() completed.")
            else:
                print(f"⚠️  [{order}] Skipping {name}: no callable install() found.")
        return True
    except Exception as exc:
        print(f"ERROR: Unexpected failure in run_all(): {exc}")
        return False


--- 01 New Setup/utils/pacman.py ---
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


--- 01 New Setup/utils/sudo_session.py ---
# utils/sudo_session.py
#!/usr/bin/env python3
"""
Sudo Session Manager (Keep-Alive)
Version: 2.0.0

What the module does
--------------------
Creates a safe, short-lived sudo "session" without holding your password in
memory. It:

1) Prompts once for your password and seeds sudo's timestamp cache (`sudo -S -v`).
2) Starts a background thread to refresh the timestamp (`sudo -n -v`) periodically.
3) Exposes a `run(cmd, ...)` callable that executes commands as root using `sudo -n`.
4) Exposes a `close()` callable that stops the keep-alive and clears credentials.

Design notes
------------
- The password is only passed to `sudo -S -v` and then discarded immediately.
- All subsequent calls use `-n` (non-interactive). If the timestamp expires,
  commands will fail instead of blocking for a password.
"""

from __future__ import annotations

import atexit
import getpass
import subprocess
import threading
from typing import Iterable, Optional


def _print_action(text: str) -> None:
    """Print a shell-like action description."""
    print(f"$ {text}")


def _seed_sudo_timestamp() -> bool:
    """
    Prompt once and seed sudo's timestamp cache; drop password immediately.

    Returns:
        True if seeding succeeded, False otherwise.
    """
    try:
        # Ask for the password once. This is the only place we accept input.
        pw = getpass.getpass("sudo password: ")
        _print_action("sudo -S -v  # seed sudo timestamp")
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
            # Ensure we drop the reference, even if run() raises.
            pw = None
        return True
    except Exception as exc:
        print(f"ERROR: Failed to seed sudo timestamp: {exc}")
        return False


def _keepalive_loop(stop_evt: threading.Event, interval: int) -> None:
    """Background loop to refresh sudo's timestamp non-interactively."""
    while not stop_evt.is_set():
        # Use -n to avoid blocking if the timestamp ever expires.
        subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        stop_evt.wait(interval)


def start_sudo_session(keepalive_interval_sec: int = 60):
    """
    Start a sudo session that never stores the password in memory.

    Arguments:
        keepalive_interval_sec:
            Seconds between timestamp refreshes. Minimum enforced to 10 seconds.

    Returns:
        (run, close) where:

        - run(cmd, *, check=True, capture_output=False, cwd=None, env=None, input_text=None)
            -> subprocess.CompletedProcess
          Executes `sudo -n <cmd...>` so it never prompts. If the sudo timestamp
          is invalid, the command will fail quickly (non-zero return code).

        - close() -> None
          Stops keep-alive and clears sudo credentials (`sudo -K`).

    Behavior:
        - Prints shell-style actions for visibility.
    """
    if not _seed_sudo_timestamp():
        # We still return a run/close pair, but `run` will fail if sudo is unusable.
        print("⚠️  Continuing without a valid sudo timestamp. Commands may fail (-n).")

    stop_evt = threading.Event()
    interval = max(10, int(keepalive_interval_sec))
    _print_action(f"(keepalive) sudo -n -v every {interval}s")
    t = threading.Thread(
        target=_keepalive_loop,
        args=(stop_evt, interval),
        name="sudo-keepalive",
        daemon=True,
    )
    t.start()

    def close() -> None:
        """Stop keep-alive thread and clear sudo credentials."""
        try:
            if not stop_evt.is_set():
                stop_evt.set()
                t.join(timeout=2)
            _print_action("sudo -K  # clear cached credentials")
            subprocess.run(["sudo", "-K"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as exc:
            print(f"ERROR: Failed to close sudo session cleanly: {exc}")

    atexit.register(close)

    def run(
        cmd: Iterable[str],
        *,
        check: bool = True,
        capture_output: bool = False,
        cwd: Optional[str] = None,
        env: Optional[dict] = None,
        input_text: Optional[str] = None,
    ) -> subprocess.CompletedProcess:
        """
        Execute a command as root using non-interactive sudo.

        Arguments:
            cmd: The command as an iterable of strings, e.g., ["ls", "/root"].
            check: If True, raises CalledProcessError on non-zero exit status.
            capture_output: If True, captures stdout/stderr as text.
            cwd: Working directory for the command.
            env: Environment variables to provide.
            input_text: Optional text to pass to the process's stdin.

        Returns:
            subprocess.CompletedProcess with `returncode`, `stdout`, and `stderr`.

        Notes:
            - Uses `sudo -n` to ensure no interactive prompts occur.
            - If the sudo timestamp is invalid, return code will be non-zero.
        """
        try:
            _print_action("sudo -n " + " ".join(cmd))
            return subprocess.run(
                ["sudo", "-n", *cmd],
                check=check,
                capture_output=capture_output,
                text=True,
                cwd=cwd,
                env=env,
                input=input_text,
            )
        except Exception:
            # Let callers see stack in their try/except if they opted `check=True`.
            # We still re-raise to preserve expected subprocess semantics.
            raise

    return run, close


--- 01 New Setup/utils/symlinker.py ---
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


--- 01 New Setup/utils/yay.py ---
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


--- scripts/audio.sh ---
#!/usr/bin/env bash
# setup-audio.sh - simple PipeWire audio setup for Arch Linux

set -e

echo "[*] Updating system..."
sudo pacman -Syu --noconfirm

echo "[*] Installing PipeWire stack..."
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol

if pacman -Qq pulseaudio &>/dev/null; then
  echo "[*] Removing PulseAudio (conflicts with PipeWire)..."
  sudo pacman -Rns --noconfirm pulseaudio
fi

echo "[*] Enabling PipeWire user services..."
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

echo "[*] Verifying setup..."
systemctl --user status pipewire.service --no-pager -l | grep "Active:"
systemctl --user status pipewire-pulse.service --no-pager -l | grep "Active:"
systemctl --user status wireplumber.service --no-pager -l | grep "Active:"

echo
echo "[*] Listing audio devices (ALSA):"
aplay -l || true

echo
echo "[*] PipeWire info:"
pactl info || true

echo
echo "[*] Done! Use 'pavucontrol' to pick your output device (HDMI, speakers, etc)."


--- scripts/fonts.sh ---
#!/usr/bin/env bash
#
# setup-jetbrains-nerd-font.sh
#
# Install JetBrainsMono Nerd Font system-wide and set it as the default monospace font.
#

set -euo pipefail

FONT_PKG="ttf-jetbrains-mono-nerd"
FONTCONF="/etc/fonts/local.conf"

echo "[*] Installing JetBrainsMono Nerd Font..."
sudo pacman -S --needed --noconfirm "$FONT_PKG"

echo "[*] Refreshing font cache..."
sudo fc-cache -f -v

echo "[*] Detecting JetBrains Nerd Font family name..."
FAMILY=$(fc-list | grep -m1 "JetBrainsMono Nerd Font" | sed -E 's/.*: "([^"]+)".*/\1/')

if [[ -z "$FAMILY" ]]; then
  echo "[!] Could not detect JetBrainsMono Nerd Font in fc-list!"
  exit 1
fi

echo "[*] Detected family: $FAMILY"

echo "[*] Writing fontconfig rule to $FONTCONF..."
sudo tee "$FONTCONF" >/dev/null <<EOF
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <!-- Default monospace font -->
  <match target="pattern">
    <test qual="any" name="family">
      <string>monospace</string>
    </test>
    <edit name="family" mode="assign" binding="strong">
      <string>$FAMILY</string>
    </edit>
  </match>
</fontconfig>
EOF

echo "[*] Rebuilding font cache..."
sudo fc-cache -f -v

echo "[*] Verifying default monospace font..."
fc-match monospace

echo "[✓] JetBrainsMono Nerd Font is now the default monospace font system-wide."


--- scripts/sddminstall.sh ---
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install_sddm.sh  v1.0
#
# Minimal installer for SDDM on Arch Linux.
#
# - Installs the `sddm` package
# - Disables LightDM if present
# - Enables SDDM service
#
# Intended for use on a brand new minimal install where checks are unnecessary.
# -----------------------------------------------------------------------------

set -euo pipefail

# Install SDDM
sudo pacman -S --noconfirm --needed sddm

# Enable SDDM
sudo systemctl enable sddm.service --now

echo "✓ SDDM installed and enabled."


--- scripts/symlinker.sh ---
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# bootstrap_symlinks.sh  v1.5
#
# Create symlinks from your dotfiles repo into the correct locations.
# - Creates parent directories as needed
# - Backs up existing targets (user files to ~/.dotfiles_backup/<ts>/…,
#   system files to "<dest>.bak.<ts>" alongside the file)
# - Automatically uses sudo for non-writable/system paths (e.g. /etc/*)
#
# Repo root (edit if you move the repo):
#   REPO="/home/nathan/repos/25_09_21_XPS9500_Arch"
#
# What it links (adjust to taste):
#   $REPO/i3/config                      ->  ~/.config/i3/config
#   $REPO/git/gitconfig                  ->  ~/.gitconfig
#   $REPO/X11/xorg.conf.d/90-libinput.conf  ->  ~/.config/xorg.conf.d/90-libinput.conf
#   (optional system path)
#   $REPO/X11/xorg.conf.d/90-libinput.conf  ->  /etc/X11/xorg.conf.d/90-libinput.conf
# -----------------------------------------------------------------------------

set -euo pipefail

REPO="/home/nathan/repos/25_09_21_XPS9500_Arch"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="${HOME}/.dotfiles_backup/${timestamp}"

# ----- helpers ---------------------------------------------------------------

need_sudo() {
  # return 0 if we need sudo to write the DEST's parent dir
  local dest="$1"
  local parent; parent="$(dirname "$dest")"
  [ -w "$parent" ] || { [ -e "$parent" ] && [ ! -w "$parent" ]; } && return 0
  # parent not existing? test writability of its nearest existing ancestor
  while [ ! -d "$parent" ]; do parent="$(dirname "$parent")"; done
  [ -w "$parent" ] || return 0
  return 1
}

ensure_parent() {
  local dest="$1"
  local parent; parent="$(dirname "$dest")"
  if need_sudo "$dest"; then
    sudo mkdir -p "$parent"
  else
    mkdir -p "$parent"
  fi
}

backup_target() {
  # create a backup of existing dest (file/dir/link)
  local dest="$1"
  if need_sudo "$dest"; then
    local bk="${dest}.bak.${timestamp}"
    echo "↪ backing up (root): $dest -> $bk"
    sudo cp -a --no-preserve=ownership "$dest" "$bk" 2>/dev/null || sudo mv -f "$dest" "$bk"
  else
    local rel="${dest#${HOME}/}"
    local bk="${backup_root}/${rel}"
    echo "↪ backing up: $dest -> $bk"
    mkdir -p "$(dirname "$bk")"
    mv -f "$dest" "$bk"
  fi
}

same_symlink_target() {
  # returns 0 if dest is a symlink pointing to src
  local src="$1" dest="$2"
  [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]
}

link_one() {
  local src="$1" dest="$2"

  # sanity
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    echo "⚠  missing source: $src"
    return 0
  fi

  ensure_parent "$dest"

  # if exists and not already the same link, back it up
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if same_symlink_target "$src" "$dest"; then
      echo "✓ already linked: $dest → $(readlink -f "$dest")"
      return 0
    fi
    backup_target "$dest"
  fi

  if need_sudo "$dest"; then
    echo "→ linking (root): $dest -> $src"
    sudo ln -sfn "$src" "$dest"
  else
    echo "→ linking: $dest -> $src"
    ln -sfn "$src" "$dest"
  fi
}

# ----- user-scope links (no sudo) -------------------------------------------

link_one "$REPO/i3/config"                          "${HOME}/.config/i3/config"
link_one "$REPO/git/gitconfig"                      "${HOME}/.gitconfig"
link_one "$REPO/X11/xorg.conf.d/90-libinput.conf"   "/etc/X11/xorg.conf.d/90-libinput.conf"
link_one "$REPO/etc/sddm.conf.d/00-autologin.conf"  "/etc/sddm.conf.d/00-autologin.conf"
link_one "$REPO/etc/sddm.conf.d/10-theme.conf"     "/etc/sddm.conf.d/10-theme.conf"

# Uncomment if/when you want these managed too:
# link_one "$REPO/X11/xprofile"                      "${HOME}/.xprofile"
# link_one "$REPO/shell/bashrc"                       "${HOME}/.bashrc"
# link_one "$REPO/shell/zshrc"                        "${HOME}/.zshrc"

# ----- wrap up ---------------------------------------------------------------

# Show where user backups (if any) landed
[ -d "$backup_root" ] && echo "User backups (if any) are in: $backup_root"
echo "Done."


--- scripts/system_context.sh ---
#!/usr/bin/env bash
# sys_prompt.sh — generate a concise, ChatGPT-friendly summary of this Linux system

set -euo pipefail

# Helpers
has() { command -v "$1" >/dev/null 2>&1; }
line() { printf '%*s\n' "${1:-60}" '' | tr ' ' '-'; }
kv() { printf "%s: %s\n" "$1" "${2:-N/A}"; }
run() { # run if available; trim trailing spaces/newlines
  if has "$1"; then shift; "$@" 2>/dev/null | sed -e 's/[[:space:]]*$//' || true
  fi
}

header() { echo; line 80; echo "# $*"; line 80; }

# Basic
HOSTNAME="$(hostname 2>/dev/null || echo N/A)"
KERNEL="$(uname -r 2>/dev/null || echo N/A)"
UNAME="$(uname -a 2>/dev/null || echo N/A)"
UPTIME="$(awk -v s="$(cut -d. -f1 /proc/uptime 2>/dev/null)" 'BEGIN{
d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60);
printf("%dd %dh %dm", d,h,m)}' 2>/dev/null || echo N/A)"

# OS info
if [ -r /etc/os-release ]; then
  . /etc/os-release
  OS_NAME="${PRETTY_NAME:-$NAME $VERSION_ID}"
else
  OS_NAME="$(run lsb_release lsb_release -d | cut -f2)"
fi

# CPU
CPU_MODEL="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')"
CPU_CORES="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo N/A)"
CPU_ARCH="$(uname -m 2>/dev/null || echo N/A)"
CPU_FLAGS="$(grep -m1 ^flags /proc/cpuinfo 2>/dev/null | cut -d: -f2- | tr ' ' ' ' | sed -e 's/^ //' )"

# Memory
MEM_TOTAL="$(grep -m1 MemTotal /proc/meminfo 2>/dev/null | awk '{printf "%.1f GiB",$2/1024/1024}')"
MEM_FREE="$(free -h 2>/dev/null | awk '/Mem:/ {print $7" (available)"}')"

# Disks & FS
DISK_LAYOUT="$(lsblk -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT -r 2>/dev/null | sed -e 's/^/  /')"
DISK_USAGE="$(df -hT -x tmpfs -x devtmpfs 2>/dev/null | sed -e 's/^/  /')"

# GPU / Graphics
GPU_LSPCI="$(lspci 2>/dev/null | grep -E 'VGA|3D|Display' || true)"
GPU_RENDERER="$(run glxinfo glxinfo | awk -F': ' '/OpenGL renderer string/ {print $2; exit}')"
DISPLAY_SERVER="$(printf '%s' "${XDG_SESSION_TYPE:-$(loginctl show-session $XDG_SESSION_ID 2>/dev/null | awk -F= '/Type=/{print $2}')}")"

# Network
IP_BRIEF="$(run ip ip -br a | sed -e 's/^/  /')"
DNS_RESOLV="$(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | paste -sd, -)"
DEFAULT_ROUTE="$(run ip ip route | awk '/default/ {print $3; exit}')"

# Userspace / DE-WM / Shell
SHELL_NAME="${SHELL:-$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)}"
DESKTOP="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-$(echo "${GDMSESSION:-}" )}}"
WINDOW_MANAGER="$(run wmctrl wmctrl -m | awk -F': ' '/Name:/ {print $2}')"
if [ -z "${WINDOW_MANAGER:-}" ]; then
  WINDOW_MANAGER="$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | awk '{print $5}' | xargs -r -I{} xprop -id {} _NET_WM_NAME 2>/dev/null | awk -F\" '{print $2}' )"
fi

# Kernel modules of interest (graphics/network)
KMODS="$(run lsmod lsmod | awk 'NR==1 || /(^i915|^amdgpu|^nouveau|^nvidia|^iwlwifi|^ath9k|^rtw|^r8169|^e1000|^tg3|^ax2|^mt76)/' 2>/dev/null | sed -e 's/^/  /')"

# Package management (Arch-aware with fallbacks)
PKG_MGR=""
PKG_COUNT=""
PKG_EXPLICIT=""
PKG_AUR=""
if has pacman; then
  PKG_MGR="pacman"
  PKG_COUNT="$(pacman -Q 2>/dev/null | wc -l | tr -d ' ')"
  PKG_EXPLICIT="$(pacman -Qe 2>/dev/null | head -n 60 | awk '{print $1}' | paste -sd' ' -)"
  [ "$(pacman -Qe 2>/dev/null | wc -l)" -gt 60 ] && PKG_EXPLICIT="$PKG_EXPLICIT …"
  PKG_AUR="$(pacman -Qm 2>/dev/null | head -n 40 | awk '{print $1}' | paste -sd' ' -)"
  [ "$(pacman -Qm 2>/dev/null | wc -l)" -gt 40 ] && PKG_AUR="$PKG_AUR …"
elif has dpkg; then
  PKG_MGR="dpkg/apt"
  PKG_COUNT="$(dpkg -l 2>/dev/null | awk '/^ii/ {c++} END{print c+0}')"
elif has rpm; then
  PKG_MGR="rpm"
  PKG_COUNT="$(rpm -qa 2>/dev/null | wc -l | tr -d ' ')"
fi

# Kernel params (useful for GPU, virtualization, etc.)
KCMDLINE="$(cat /proc/cmdline 2>/dev/null | sed -e 's/initramfs\.img[^ ]*//g')"

# Virtualization / Firmware
VIRT="$(systemd-detect-virt 2>/dev/null || true)"
FW="$(run fwupdmgr fwupdmgr get-devices | awk -F': ' '/^├─|^└─/ {print $2}' | paste -sd', ' -)"

# Audio
AUDIO="$(run pactl pactl info | awk -F': ' '/Server Name|Default Sink|Default Source/ {print $1": "$2}')"
if [ -z "$AUDIO" ]; then
  AUDIO="$(run aplay aplay -l | sed -e 's/^/  /')"
fi

# Compose Output
header "SYSTEM CONTEXT (for ChatGPT)"
kv "Hostname" "$HOSTNAME"
kv "OS" "$OS_NAME"
kv "Kernel" "$KERNEL"
kv "Uptime" "$UPTIME"
kv "Architecture" "$CPU_ARCH"
kv "Virtualization" "${VIRT:-N/A}"

header "CPU"
kv "Model" "${CPU_MODEL:-N/A}"
kv "Cores (online)" "${CPU_CORES:-N/A}"
if [ -n "${CPU_FLAGS:-}" ]; then
  kv "Key flags" "$(echo "$CPU_FLAGS" | grep -oE '(avx512|avx2|avx|sse4_2|sse4_1|aes|vmx|svm)' | sort -u | paste -sd',' -)"
fi

header "MEMORY"
kv "Total" "${MEM_TOTAL:-N/A}"
kv "Available" "${MEM_FREE:-N/A}"

header "GRAPHICS"
kv "GPU (lspci)" "${GPU_LSPCI:-N/A}"
kv "Renderer (OpenGL)" "${GPU_RENDERER:-N/A}"
kv "Display Server" "${DISPLAY_SERVER:-N/A}"
echo "Kernel Modules:"
echo "${KMODS:-  N/A}"

header "DISKS"
echo "Block Devices:"
echo "${DISK_LAYOUT:-  N/A}"
echo
echo "Mounted Filesystems:"
echo "${DISK_USAGE:-  N/A}"

header "NETWORK"
kv "Default Gateway" "${DEFAULT_ROUTE:-N/A}"
kv "DNS" "${DNS_RESOLV:-N/A}"
echo "Interfaces (brief):"
echo "${IP_BRIEF:-  N/A}"

header "USER ENVIRONMENT"
kv "Shell" "${SHELL_NAME:-N/A}"
kv "Desktop Environment" "${DESKTOP:-N/A}"
kv "Window Manager" "${WINDOW_MANAGER:-N/A}"

header "AUDIO"
if [ -n "${AUDIO:-}" ]; then
  echo "$AUDIO"
else
  echo "  N/A"
fi

header "PACKAGES"
kv "Manager" "${PKG_MGR:-N/A}"
kv "Installed Count" "${PKG_COUNT:-N/A}"
if [ "$PKG_MGR" = "pacman" ]; then
  kv "Explicit (sample)" "${PKG_EXPLICIT:-N/A}"
  kv "AUR/Foreign (sample)" "${PKG_AUR:-N/A}"
fi

header "KERNEL CMDLINE (trimmed)"
echo "  $KCMDLINE"

echo
line 80
echo "# NOTES"
echo "- Lists are truncated to keep this summary compact. If you need full lists, let me know."
echo "- Safe, read-only commands were used; no system changes were made."
line 80

