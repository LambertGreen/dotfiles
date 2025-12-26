#!/usr/bin/env python3
"""
Package Manager Selection Module

Interactive selection of package managers with timeout for unattended operation.
"""

import sys
import os
from typing import List, Optional
from pathlib import Path

# Platform-specific imports for input timeout
# win32 = native Windows Python, msys/cygwin = MSYS2/Cygwin Python (POSIX-like)
if sys.platform == 'win32':
    import msvcrt
else:
    import select  # Works on msys, cygwin, linux, darwin

# Add current directory to path for imports (when run as module)
sys.path.insert(0, str(Path(__file__).parent))


def _input_with_timeout(prompt: str, timeout: int) -> Optional[str]:
    """
    Read input with a timeout. Returns None if timeout is reached.
    
    Uses platform-specific implementation:
    - Windows: msvcrt for keyboard polling
    - Unix/Linux/macOS: select.select() on stdin
    
    Args:
        prompt: The prompt to display
        timeout: Timeout in seconds
        
    Returns:
        User input string, or None if timeout reached
    """
    print(prompt, end='', flush=True)
    
    if sys.platform == 'win32':
        # Windows implementation using msvcrt
        import time
        chars = []
        start_time = time.time()
        
        while True:
            # Check if timeout reached
            if time.time() - start_time >= timeout:
                return None
            
            # Check if a key is available
            if msvcrt.kbhit():
                char = msvcrt.getwch()
                if char == '\r' or char == '\n':
                    print()  # Echo newline
                    return ''.join(chars)
                elif char == '\x03':  # Ctrl+C
                    raise KeyboardInterrupt
                elif char == '\x04':  # Ctrl+D (EOF)
                    raise EOFError
                elif char == '\b':  # Backspace
                    if chars:
                        chars.pop()
                        # Erase character from display
                        print('\b \b', end='', flush=True)
                else:
                    chars.append(char)
                    print(char, end='', flush=True)
            else:
                # Small sleep to avoid busy-waiting
                time.sleep(0.05)
    else:
        # Unix/Linux/macOS implementation using select
        ready, _, _ = select.select([sys.stdin], [], [], timeout)
        if ready:
            return input()
        return None


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
    test_selection = os.environ.get('DOTFILES_PM_UI_SELECT')

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
        print(f"TEST MODE: Using selection from DOTFILES_PM_UI_SELECT='{test_selection}'")
        user_input = test_selection
    else:
        # Wait for input with timeout (platform-specific implementation)
        try:
            user_input = _input_with_timeout("Selection: ", timeout)
            if user_input is None:
                # Timeout reached
                print("\n⏱️ Timeout - selecting all package managers")
                return available_pms
            user_input = user_input.strip()

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
