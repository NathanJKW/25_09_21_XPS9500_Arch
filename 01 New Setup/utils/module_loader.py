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
