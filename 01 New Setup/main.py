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
