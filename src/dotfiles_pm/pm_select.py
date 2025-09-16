#!/usr/bin/env python3
"""
Package Manager Selection Module

Interactive selection of package managers with timeout for unattended operation.
"""

import sys
import select
from typing import List, Optional


def select_pms(available_pms: List[str], timeout: int = 10) -> List[str]:
    """
    Interactive selection of package managers.

    Args:
        available_pms: List of available package managers
        timeout: Seconds to wait for input before selecting all (default: 10)

    Returns:
        List of selected package managers
    """
    if not available_pms:
        return []

    # Check if we're in interactive mode
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        # Non-interactive mode - select all
        print(f"Non-interactive mode - selecting all PMs: {', '.join(available_pms)}")
        return available_pms

    print("\n📋 Select package managers to process:\n")

    # Display numbered list
    for i, pm in enumerate(available_pms, 1):
        print(f"  {i}. {pm}")

    print("\nOptions:")
    print("  • Enter numbers (e.g., '1 3 5') to select specific PMs")
    print("  • Enter 'all' or press ENTER to select all (default)")
    print("  • Enter 'none' to skip")
    print(f"  • Timeout: {timeout} seconds (defaults to 'all')\n")

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

    # Parse numbers
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
