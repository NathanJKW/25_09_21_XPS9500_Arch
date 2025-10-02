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
