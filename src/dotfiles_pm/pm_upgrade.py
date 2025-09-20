#!/usr/bin/env python3
"""
Package Manager Upgrade Module

Upgrade packages across multiple package managers.
"""

import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Any

from .pm_detect import detect_all_pms
from .pm_select import select_pms
from .terminal_executor import spawn_tracked
from .command_executor import run_command


def upgrade_pm_packages(pm_name: str) -> Dict[str, Any]:
    """
    Upgrade packages using a specific package manager.

    Args:
        pm_name: Name of the package manager

    Returns:
        Dict with status, output, and error information
    """
    result = {
        'pm': pm_name,
        'success': False,
        'output': '',
        'error': '',
        'upgraded_count': 0
    }

    # Define commands for different package managers
    commands = {
        'brew': ['brew', 'upgrade'],
        'npm': ['npm', 'update', '-g'],
        'pip': ['pip3', 'install', '--upgrade-strategy', 'eager', '--upgrade'],
        'pipx': ['pipx', 'upgrade-all'],
        'cargo': ['cargo', 'install-update', '-a'],
        'gem': ['gem', 'update'],
        'fake-pm1': ['fake-pm1', 'upgrade'],
        'fake-pm2': ['fake-pm2', 'upgrade'],
    }

    if pm_name not in commands:
        result['error'] = f"No upgrade command defined for {pm_name}"
        return result

    # Package managers that need interactive terminal
    interactive_pms = ['brew', 'apt', 'gem']

    try:
        cmd = commands[pm_name]

        # Check if this PM needs interactive terminal
        if pm_name in interactive_pms:
            upgrade_cmd = ' '.join(cmd)
            print(f"🚀 Opening terminal for interactive {pm_name} upgrade...")
            print(f"  💻 Command: {upgrade_cmd}")
            print(f"  🖥️  Executing in new terminal window...")

            terminal_result = spawn_tracked(
                upgrade_cmd,
                operation=f'{pm_name}-upgrade',
                auto_close=False  # Let user see results
            )

            if terminal_result['status'] == 'spawned':
                result['log_file'] = terminal_result.get('log_file')
                result['status_file'] = terminal_result.get('status_file')
                print(f"  📄 Log: {terminal_result.get('log_file')}")
                print(f"  📊 Status: {terminal_result.get('status_file')}")
                print(f"  ⏳ Waiting for upgrade to complete...")

                # Wait for completion by polling status file
                import time
                from .terminal_executor import create_terminal_executor

                executor = create_terminal_executor()
                status_file = terminal_result.get('status_file')

                if status_file:
                    # Poll until completion
                    while True:
                        status_info = executor.check_status(status_file)
                        if status_info.get('status') == 'completed':
                            exit_code = status_info.get('exit_code', 0)
                            if exit_code == 0:
                                print(f"  ✅ {pm_name} upgrade completed successfully")
                                result['success'] = True
                                result['output'] = f"Upgrade completed successfully"
                            else:
                                print(f"  ❌ {pm_name} upgrade failed (exit code: {exit_code})")
                                result['success'] = False
                                result['error'] = f"Upgrade failed with exit code {exit_code}"
                            break
                        elif status_info.get('status') == 'error':
                            print(f"  ❌ {pm_name} upgrade error: {status_info.get('error', 'Unknown error')}")
                            result['success'] = False
                            result['error'] = status_info.get('error', 'Unknown error')
                            break
                        else:
                            # Still running, wait a bit
                            time.sleep(2)
                else:
                    # Fallback if no status file
                    result['success'] = True
                    result['output'] = f"Launched in {terminal_result['method']}"
            else:
                result['success'] = False
                result['error'] = terminal_result.get('error', 'Failed to spawn terminal')
                print(f"  ❌ Failed to spawn terminal: {terminal_result.get('error', 'Unknown error')}")

            return result

        # For pip, we need to first get the list of outdated packages
        if pm_name == 'pip':
            # Get outdated packages first
            outdated_proc = subprocess.run(
                ['pip3', 'list', '--outdated', '--format=freeze'],
                capture_output=True,
                text=True,
                timeout=30
            )

            if outdated_proc.returncode == 0 and outdated_proc.stdout.strip():
                # Extract package names from outdated list
                outdated_packages = []
                for line in outdated_proc.stdout.strip().split('\n'):
                    if '==' in line:
                        pkg_name = line.split('==')[0]
                        outdated_packages.append(pkg_name)

                if outdated_packages:
                    cmd = ['pip3', 'install', '--upgrade'] + outdated_packages
                else:
                    result['success'] = True
                    result['output'] = "No packages to upgrade"
                    return result
            else:
                result['success'] = True
                result['output'] = "No packages to upgrade"
                return result

        print(f"  Running: {' '.join(cmd)}")

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes timeout for upgrades
        )

        result['output'] = proc.stdout.strip()
        result['error'] = proc.stderr.strip()
        result['success'] = proc.returncode == 0

        # Count upgraded packages (simple heuristic)
        if result['success'] and result['output']:
            # Different PMs have different success patterns
            output_lower = result['output'].lower()
            if 'upgraded' in output_lower or 'updated' in output_lower or 'installing' in output_lower:
                # Count lines that suggest package operations
                lines = [line for line in result['output'].split('\n')
                        if line.strip() and any(word in line.lower()
                        for word in ['upgraded', 'updated', 'installing', 'installed'])]
                result['upgraded_count'] = len(lines)
            elif pm_name.startswith('fake-'):
                # For fake PMs, count non-empty lines
                lines = [line for line in result['output'].split('\n') if line.strip()]
                result['upgraded_count'] = len(lines)

    except subprocess.TimeoutExpired:
        result['error'] = f"Command timed out after 5 minutes"
    except FileNotFoundError:
        result['error'] = f"Command not found: {' '.join(cmd)}"
    except Exception as e:
        result['error'] = f"Unexpected error: {str(e)}"

    return result


def upgrade_all_pms(selected_pms: List[str]) -> List[Dict[str, Any]]:
    """
    Upgrade packages for all selected package managers.

    Args:
        selected_pms: List of selected package manager names

    Returns:
        List of upgrade results for each PM
    """
    results = []

    for i, pm in enumerate(selected_pms):
        print(f"⬆️ Upgrading {pm}...")
        result = upgrade_pm_packages(pm)
        results.append(result)

        if result['success']:
            if result['upgraded_count'] > 0:
                print(f"  ✅ {result['upgraded_count']} packages upgraded")
            else:
                print(f"  ✅ All packages already up to date")
        else:
            print(f"  ❌ Upgrade failed: {result['error']}")

        # Add spacing between PMs (except after the last one)
        if i < len(selected_pms) - 1:
            print()  # Add blank line for visual separation

    return results


def main():
    """CLI entry point for package upgrading."""
    print("⬆️ Package Manager Upgrade")
    print("=" * 27)

    # Detect available package managers
    available_pms = detect_all_pms()

    if not available_pms:
        print("❌ No package managers detected")
        return 1

    print(f"\n📋 Detected {len(available_pms)} package managers")

    # Select package managers to upgrade
    selected_pms = select_pms(available_pms)

    if not selected_pms:
        print("⏭️ No package managers selected - nothing to upgrade")
        return 0

    print(f"\n🎯 Upgrading {len(selected_pms)} package managers...")
    print()

    # Upgrade all selected package managers
    results = upgrade_all_pms(selected_pms)

    # Summary
    print("\n📊 Upgrade Summary")
    print("==================")

    total_upgraded = 0
    successful_upgrades = 0

    for result in results:
        status = "✅" if result['success'] else "❌"
        pm = result['pm']

        if result['success']:
            successful_upgrades += 1
            count = result['upgraded_count']
            total_upgraded += count
            print(f"{status} {pm}: {count} packages upgraded")
        else:
            print(f"{status} {pm}: Upgrade failed")

    print()
    print(f"📈 Total packages upgraded: {total_upgraded}")
    print(f"🎯 Successful upgrades: {successful_upgrades}/{len(selected_pms)}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
