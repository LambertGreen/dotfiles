#!/usr/bin/env python3
"""
Package Manager Configuration Module

Configure which package managers are enabled/disabled for the system.
Saves configuration to environment variables.
"""

import sys
from pathlib import Path
from typing import List, Tuple

from .pm_detect import detect_all_pms
from .pm_select import select_pms


def configure_pms() -> Tuple[List[str], List[str]]:
    """
    Configure package managers - detect all and let user select which to enable.

    Returns:
        Tuple of (enabled_pms, disabled_pms)
    """
    print("\n📦 Package Manager Configuration")
    print("=" * 33)

    # Detect all available package managers
    all_pms = detect_all_pms()

    if not all_pms:
        print("❌ No package managers detected on this system")
        return [], []

    print(f"\n🔍 Detected {len(all_pms)} package managers on this system")

    # Use the selection interface with a longer timeout for configuration
    print("\n📋 Select which package managers to enable:")
    enabled_pms = select_pms(all_pms, timeout=30)

    # Calculate disabled PMs
    disabled_pms = [pm for pm in all_pms if pm not in enabled_pms]

    return enabled_pms, disabled_pms


def save_pm_config(enabled_pms: List[str], disabled_pms: List[str], config_file: Path):
    """
    Save PM configuration to dotfiles.env file.

    Args:
        enabled_pms: List of enabled package managers
        disabled_pms: List of disabled package managers
        config_file: Path to configuration file
    """
    # Read existing config if it exists
    existing_lines = []
    if config_file.exists():
        with open(config_file, 'r') as f:
            existing_lines = f.readlines()

    # Remove any existing PM configuration lines
    new_lines = []
    for line in existing_lines:
        if not any(key in line for key in [
            'DOTFILES_PM_ENABLED',
            'DOTFILES_PM_DISABLED',
            'DOTFILES_PACKAGE_MANAGERS',
            'DOTFILES_PACKAGE_MANAGERS_DISABLED'
        ]):
            new_lines.append(line)

    # Add new PM configuration
    new_lines.append('\n# Package Manager Configuration\n')

    if enabled_pms:
        enabled_str = ','.join(enabled_pms)
        new_lines.append(f'export DOTFILES_PM_ENABLED="{enabled_str}"\n')
        # Also set legacy variable for backward compatibility
        new_lines.append(f'export DOTFILES_PACKAGE_MANAGERS="{enabled_str}"\n')
    else:
        new_lines.append('export DOTFILES_PM_ENABLED=""\n')
        new_lines.append('export DOTFILES_PACKAGE_MANAGERS=""\n')

    if disabled_pms:
        disabled_str = ','.join(disabled_pms)
        new_lines.append(f'export DOTFILES_PM_DISABLED="{disabled_str}"\n')
        # Also set legacy variable for backward compatibility
        new_lines.append(f'export DOTFILES_PACKAGE_MANAGERS_DISABLED="{disabled_str}"\n')

    # Write updated config
    with open(config_file, 'w') as f:
        f.writelines(new_lines)

    print(f"\n💾 Configuration saved to {config_file}")


def main():
    """CLI entry point for PM configuration."""
    import argparse

    parser = argparse.ArgumentParser(description='Configure package managers')
    parser.add_argument(
        '--save-to',
        type=Path,
        default=Path.home() / '.dotfiles.env',
        help='Configuration file to save to (default: ~/.dotfiles.env)'
    )
    parser.add_argument(
        '--no-save',
        action='store_true',
        help='Do not save configuration, just output selection'
    )

    args = parser.parse_args()

    # Configure PMs
    enabled_pms, disabled_pms = configure_pms()

    # Display results
    print("\n📊 Configuration Summary")
    print("=" * 25)

    if enabled_pms:
        print(f"✅ Enabled ({len(enabled_pms)}): {', '.join(enabled_pms)}")
    else:
        print("⚠️ No package managers enabled")

    if disabled_pms:
        print(f"❌ Disabled ({len(disabled_pms)}): {', '.join(disabled_pms)}")

    # Save configuration unless --no-save
    if not args.no_save:
        save_pm_config(enabled_pms, disabled_pms, args.save_to)
    else:
        # Output in format that can be sourced by bash
        print("\n# Environment variables (not saved):")
        if enabled_pms:
            print(f'export DOTFILES_PM_ENABLED="{",".join(enabled_pms)}"')
        else:
            print('export DOTFILES_PM_ENABLED=""')

        if disabled_pms:
            print(f'export DOTFILES_PM_DISABLED="{",".join(disabled_pms)}"')

    return 0


if __name__ == '__main__':
    sys.exit(main())
