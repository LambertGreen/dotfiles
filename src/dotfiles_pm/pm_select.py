#!/usr/bin/env python3
"""
Package Manager Selection Module

Interactive selection of package managers with timeout for unattended operation.
"""

import sys
import select
from typing import List, Optional
from pathlib import Path

# Add current directory to path for imports (when run as module)
sys.path.insert(0, str(Path(__file__).parent))


def select_pms(available_pms: List[str], timeout: int = 10) -> List[str]:
    """
    Interactive selection of package managers.

    Package managers are displayed sorted by priority (system PMs first).
    Selection preserves this priority order.

    Args:
        available_pms: List of available package managers
        timeout: Seconds to wait for input before selecting all (default: 10)

    Returns:
        List of selected package managers in priority order
    """
    if not available_pms:
        return []

    # Sort PMs by priority for display and selection
    from pm_executor import get_pm_priority
    available_pms = sorted(available_pms, key=get_pm_priority)

    # Check for test mode override first
    import os
    test_selection = os.environ.get('DOTFILES_PM_SELECT')

    # Check if we're in interactive mode (unless test mode is enabled)
    if not test_selection and (not sys.stdin.isatty() or not sys.stdout.isatty()):
        # Non-interactive mode - select all
        print(f"Non-interactive mode - selecting all PMs: {', '.join(available_pms)}")
        return available_pms

    print("\n📋 Select package managers to process (sorted by priority):\n")

    # Display numbered list
    for i, pm in enumerate(available_pms, 1):
        priority = get_pm_priority(pm)
        priority_label = "system" if priority == 0 else "user"
        print(f"  {i}. {pm} ({priority_label})")

    print("\nOptions:")
    print("  • Enter numbers (e.g., '1 3 5') to select specific PMs")
    print("  • Enter 'all' or press ENTER to select all (default)")
    print("  • Enter 'none' to skip")
    print(f"  • Timeout: {timeout} seconds (defaults to 'all')\n")

    # Check for test mode override (already imported os and got test_selection above)
    if test_selection:
        print(f"TEST MODE: Using selection from DOTFILES_PM_SELECT='{test_selection}'")
        user_input = test_selection
    else:
        # Wait for input with timeout
        try:
            # Check if input is available within timeout
            ready, _, _ = select.select([sys.stdin], [], [], timeout)

            if ready:
                user_input = input("Selection: ").strip()
            else:
                # Timeout reached
                print("\n⏱️ Timeout - selecting all package managers")
                return available_pms

        except (KeyboardInterrupt, EOFError):
            print("\n⚠️ Interrupted - selecting none")
            return []

    # Parse user input
    if not user_input or user_input.lower() == 'all':
        print(f"✅ Selected all: {', '.join(available_pms)}")
        return available_pms

    if user_input.lower() == 'none':
        print("⏭️ Skipping - no package managers selected")
        return []

    # Parse numbers - maintain priority order
    selected = []
    for token in user_input.split():
        try:
            index = int(token) - 1
            if 0 <= index < len(available_pms):
                selected.append(available_pms[index])
            else:
                print(f"⚠️ Invalid number: {token} (out of range)")
        except ValueError:
            print(f"⚠️ Invalid input: {token} (not a number)")

    if selected:
        print(f"✅ Selected: {', '.join(selected)}")
    else:
        print("⚠️ No valid selections - defaulting to all")
        selected = available_pms

    return selected


def main():
    """CLI entry point for testing selection."""
    # For testing, create a sample list
    test_pms = ['brew', 'npm', 'pip', 'cargo']

    print("🧪 Testing PM Selection Interface")
    print("=" * 40)

    selected = select_pms(test_pms)

    print("\n📊 Results:")
    print(f"  Available: {test_pms}")
    print(f"  Selected: {selected}")


if __name__ == '__main__':
    main()
