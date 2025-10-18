#!/usr/bin/env python3
"""
Unified Package Manager Module

Single entry point for all package management operations.
Replaces the various shell scripts with a consistent Python interface.
"""

import argparse
import sys
from pathlib import Path
from typing import List, Optional

from .pm_detect import detect_all_pms
from .pm_select import select_pms
from .pm_check import check_all_pms
from .pm_upgrade import upgrade_all_pms
from .pm_configure import configure_pms, save_pm_config
from .terminal_executor import _save_terminal_registry


def cmd_list(args):
    """List available package managers with selection numbers."""
    from .pm_executor import get_pm_priority

    pms = detect_all_pms()

    if not pms:
        print("No package managers detected")
        return 1

    # Sort by priority (same order as selection interface)
    pms = sorted(pms, key=get_pm_priority)

    print("📋 Available Package Managers")
    print("============================")
    print()
    print("Selection numbers for DOTFILES_PM_SELECT:")
    print()

    for i, pm in enumerate(pms, 1):
        priority = get_pm_priority(pm)
        pm_type = "(system)" if priority == 0 else "(user)"
        print(f"  {i}. {pm} {pm_type}")

    print()
    print(f"📊 Summary: {len(pms)} package managers detected")
    print()
    print("💡 Usage:")
    print("   export DOTFILES_PM_SELECT=\"1 3 5\"  # Select specific PMs")
    print("   just update                         # Run with selection")
    return 0


def cmd_check(args):
    """Check for outdated packages."""
    # Clear terminal registry at start of new session
    _save_terminal_registry([])

    print("🔍 Package Manager Check")
    print("=" * 25)

    # Detect available package managers
    available_pms = detect_all_pms()

    if not available_pms:
        print("❌ No package managers detected")
        return 1

    print(f"\n📋 Detected {len(available_pms)} package managers")

    # Filter by specific PMs if requested
    if args.pms:
        selected_pms = [pm for pm in args.pms if pm in available_pms]
        if not selected_pms:
            print(f"❌ None of the specified PMs are available: {args.pms}")
            return 1
    else:
        # Interactive selection
        selected_pms = select_pms(available_pms)

    if not selected_pms:
        print("⏭️ No package managers selected - nothing to check")
        return 0

    print(f"\n🎯 Checking {len(selected_pms)} package managers...")
    print()

    # Check all selected package managers (parallel by default)
    results = check_all_pms(selected_pms, parallel=True)

    # Summary with raw output
    print("\n📊 Outdated Packages")
    print("=" * 20)
    print()

    successful_checks = 0
    has_outdated = False

    for result in results:
        pm = result['pm']

        if result['success']:
            successful_checks += 1
            output = result.get('output', '').strip()

            if output:
                has_outdated = True
                print(f"📦 {pm}:")
                print("-" * 40)
                # Show raw output indented
                for line in output.split('\n'):
                    print(f"  {line}")
                print()
            else:
                print(f"✅ {pm}: All packages up to date")
                print()
        else:
            print(f"❌ {pm}: Check failed - {result.get('error', 'Unknown error')}")
            print()

    if not has_outdated:
        print("🎉 All packages are up to date!")

    print(f"\n🎯 Successful checks: {successful_checks}/{len(selected_pms)}")

    # Offer to close spawned terminals
    from .terminal_executor import prompt_close_terminals
    prompt_close_terminals()

    return 0


def cmd_upgrade(args):
    """Upgrade packages."""
    # Clear terminal registry at start of new session
    _save_terminal_registry([])

    print("⬆️ Package Manager Upgrade")
    print("=" * 27)

    # Detect available package managers
    available_pms = detect_all_pms()

    if not available_pms:
        print("❌ No package managers detected")
        return 1

    print(f"\n📋 Detected {len(available_pms)} package managers")

    # Filter by specific PMs if requested
    if args.pms:
        selected_pms = [pm for pm in args.pms if pm in available_pms]
        if not selected_pms:
            print(f"❌ None of the specified PMs are available: {args.pms}")
            return 1
    else:
        # Interactive selection
        selected_pms = select_pms(available_pms)

    if not selected_pms:
        print("⏭️ No package managers selected - nothing to upgrade")
        return 0

    print(f"\n🎯 Upgrading {len(selected_pms)} package managers...")
    print()

    # Upgrade all selected package managers (sequential by default for safety)
    results = upgrade_all_pms(selected_pms, parallel=False)

    # Summary
    print("\n📊 Upgrade Summary")
    print("==================")

    successful_upgrades = 0

    for result in results:
        status = "✅" if result['success'] else "❌"
        pm = result['pm']

        if result['success']:
            successful_upgrades += 1
            print(f"{status} {pm}: Upgrade completed")
        else:
            print(f"{status} {pm}: Upgrade failed")

    print()
    print(f"🎯 Successful upgrades: {successful_upgrades}/{len(selected_pms)}")

    # Offer to close spawned terminals
    from .terminal_executor import prompt_close_terminals
    prompt_close_terminals()

    return 0


def cmd_configure(args):
    """Configure package managers."""
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

    # Save configuration
    config_file = Path.home() / '.dotfiles.env'
    save_pm_config(enabled_pms, disabled_pms, config_file)

    return 0


def cmd_audit(args):
    """Audit package managers for consistency."""
    from .pm_audit import audit_package_managers, recommend_actions, print_audit_report

    print("🔍 Package Manager Audit")
    print("=" * 25)
    print()

    # Perform audit
    audit_results = audit_package_managers()
    recommendations = recommend_actions(audit_results)

    # Print report
    print_audit_report(audit_results, recommendations)

    return 0


def cmd_install(args):
    """Install packages."""
    from .pm_install import install_all_pms

    # Clear terminal registry at start of new session
    _save_terminal_registry([])

    print("📦 Package Manager Installation")
    print("=" * 32)

    # Detect available package managers
    available_pms = detect_all_pms()

    if not available_pms:
        print("❌ No package managers detected")
        return 1

    # Filter out self-bootstrapping app PMs (they don't need install, just update/upgrade)
    self_bootstrapping_pms = {'emacs', 'zinit', 'neovim'}
    available_pms = [pm for pm in available_pms if pm not in self_bootstrapping_pms]

    if not available_pms:
        print("❌ No package managers need installation (app PMs bootstrap themselves)")
        return 0

    # Filter by category if specified
    if args.category:
        category_pms = {
            'system': ['brew', 'apt', 'pacman', 'dnf', 'zypper', 'choco', 'winget', 'scoop'],
            'dev': ['npm', 'pip', 'pipx', 'cargo', 'gem'],
            'app': ['emacs', 'zinit', 'neovim']
        }
        available_pms = [pm for pm in available_pms if pm in category_pms.get(args.category, [])]

    print(f"\n📋 Detected {len(available_pms)} package managers")

    # Filter by specific PMs if requested
    if args.pms:
        selected_pms = [pm for pm in args.pms if pm in available_pms]
        if not selected_pms:
            print(f"❌ None of the specified PMs are available: {args.pms}")
            return 1
    else:
        # Interactive selection
        selected_pms = select_pms(available_pms)

    if not selected_pms:
        print("⏭️ No package managers selected - nothing to install")
        return 0

    print(f"\n🎯 Installing packages for {len(selected_pms)} package managers...")
    print()

    # Install packages for all selected package managers
    level = getattr(args, 'level', 'all')
    results = install_all_pms(selected_pms, level)

    # Summary
    print("\n📊 Installation Summary")
    print("=====================")

    total_installed = 0
    successful_installs = 0

    for result in results:
        status = "✅" if result['success'] else "❌"
        pm = result['pm']

        if result['success']:
            successful_installs += 1
            count = result['installed_count']
            total_installed += count
            print(f"{status} {pm}: {count} packages installed")
            # Show warning message if present (e.g., no configuration)
            if result.get('output') and '⚠️' in result['output']:
                print(f"    {result['output']}")
        else:
            print(f"{status} {pm}: Installation failed")

    print()
    print(f"📈 Total packages installed: {total_installed}")
    print(f"🎯 Successful installations: {successful_installs}/{len(selected_pms)}")

    # Offer to close spawned terminals
    from .terminal_executor import prompt_close_terminals
    prompt_close_terminals()

    return 0 if successful_installs == len(selected_pms) else 1


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Unified Package Manager Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  pm list                    # List all available package managers
  pm audit                   # Audit PMs for consistency (manifests vs installed)
  pm check                   # Check for outdated packages (interactive)
  pm check brew npm          # Check specific package managers
  pm upgrade                 # Upgrade packages (interactive)
  pm upgrade --all           # Upgrade all available PMs
  pm configure               # Configure enabled/disabled PMs
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # List command
    parser_list = subparsers.add_parser('list', help='List available package managers')

    # Check command
    parser_check = subparsers.add_parser('check', help='Check for outdated packages')
    parser_check.add_argument('pms', nargs='*', help='Specific PMs to check (optional)')

    # Upgrade command
    parser_upgrade = subparsers.add_parser('upgrade', help='Upgrade packages')
    parser_upgrade.add_argument('pms', nargs='*', help='Specific PMs to upgrade (optional)')
    parser_upgrade.add_argument('--all', action='store_true', help='Upgrade all available PMs')

    # Configure command
    parser_configure = subparsers.add_parser('configure', help='Configure package managers')

    # Audit command
    parser_audit = subparsers.add_parser('audit', help='Audit package managers for consistency')

    # Install command
    parser_install = subparsers.add_parser('install', help='Install packages')
    parser_install.add_argument('pms', nargs='*', help='Specific PMs to install for (optional)')
    parser_install.add_argument('--category', choices=['system', 'dev', 'app'],
                                help='Package category to install')
    parser_install.add_argument('--level', choices=['user', 'admin', 'all'],
                                default='all', help='Installation level for system packages')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    # Dispatch to command handlers
    commands = {
        'list': cmd_list,
        'check': cmd_check,
        'upgrade': cmd_upgrade,
        'configure': cmd_configure,
        'audit': cmd_audit,
        'install': cmd_install,
    }

    handler = commands.get(args.command)
    if handler:
        return handler(args)
    else:
        print(f"❌ Unknown command: {args.command}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
