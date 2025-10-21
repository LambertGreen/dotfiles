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
    import os
    from .pm_executor import execute_pm_command

    # Use non-interactive mode for brew when in test mode or when it has lock recovery
    interactive = True
    if pm_name == 'brew' and os.getenv('DOTFILES_TEST_MODE'):
        interactive = False

    result = execute_pm_command(pm_name, 'upgrade', interactive=interactive)

    # Convert to expected format for compatibility
    if result['success']:
        return {
            'pm': pm_name,
            'success': True,
            'output': 'Upgrade completed',
            'error': '',
            'log_file': result.get('log_file'),
            'status_file': result.get('status_file')
        }
    else:
        return {
            'pm': pm_name,
            'success': False,
            'output': '',
            'error': result.get('error', 'Upgrade failed'),
            'log_file': None,
            'status_file': None
        }


def upgrade_all_pms(selected_pms: List[str], parallel: bool = False) -> List[Dict[str, Any]]:
    """
    Upgrade packages for all selected package managers.

    Package managers are sorted by priority (system PMs like apt first),
    then run sequentially to ensure sudo prompts are handled properly.

    Args:
        selected_pms: List of selected package manager names
        parallel: Whether to run upgrades in parallel (False by default for safety)

    Returns:
        List of upgrade results for each PM
    """
    if not selected_pms:
        return []

    import time
    from .terminal_executor import create_terminal_executor

    # Selected PMs are already sorted by priority from pm_select
    # Phase 1: Launch terminals (all at once if parallel, one by one if sequential)
    if parallel:
        print(f"🚀 Launching {len(selected_pms)} package manager upgrades in parallel...")
    else:
        print(f"🚀 Running {len(selected_pms)} package manager upgrades sequentially by priority...")
    print()

    spawned_operations = []
    executor = create_terminal_executor()

    if parallel:
        # Launch all at once
        for pm in selected_pms:
            print(f"⬆️ Launching {pm} upgrade...")
            result = upgrade_pm_packages(pm)

            if result.get('status_file'):
                # Successfully spawned
                print(f"  🖥️  Executing in new terminal window...")
                print(f"  📄 Log: {result.get('log_file')}")
                spawned_operations.append(result)
                print(f"  ✅ Spawned successfully")
            else:
                # Failed to spawn or doesn't need terminal
                print(f"  ❌ Failed: {result.get('error', 'Unknown error')}")
                spawned_operations.append(result)

        print(f"\n⏳ Waiting for all {len(spawned_operations)} upgrades to complete...")
    else:
        # Sequential mode - launch and wait for each one
        completed_results = {}
        for i, pm in enumerate(selected_pms):
            print(f"⬆️ Upgrading {pm} ({i+1}/{len(selected_pms)})...")
            result = upgrade_pm_packages(pm)

            if result.get('status_file'):
                print(f"  🖥️  Executing in new terminal window...")
                print(f"  📄 Log: {result.get('log_file')}")
                print(f"  ⏳ Waiting for {pm} upgrade to complete...")

                # Wait for this specific operation to complete
                status_file = result.get('status_file')
                while True:
                    status_info = executor.check_status(status_file)
                    if status_info.get('status') == 'completed':
                        exit_code = status_info.get('exit_code', 0)
                        final_result = {
                            'pm': pm,
                            'success': exit_code == 0,
                            'output': 'Upgrade completed' if exit_code == 0 else '',
                            'error': '' if exit_code == 0 else f"Upgrade failed with exit code {exit_code}"
                        }
                        completed_results[pm] = final_result

                        # Print completion status
                        if final_result['success']:
                            print(f"  ✅ {pm}: Upgrade completed successfully")
                        else:
                            print(f"  ❌ {pm}: Upgrade failed")
                        break

                    elif status_info.get('status') == 'error':
                        final_result = {
                            'pm': pm,
                            'success': False,
                            'output': '',
                            'error': status_info.get('error', 'Unknown error')
                        }
                        completed_results[pm] = final_result
                        print(f"  ❌ {pm}: Upgrade failed")
                        break
                    else:
                        # Still running, wait a bit
                        time.sleep(1)
            else:
                print(f"  ❌ Failed: {result.get('error', 'Unknown error')}")
                completed_results[pm] = {
                    'pm': pm,
                    'success': False,
                    'output': '',
                    'error': result.get('error', 'Failed to spawn terminal')
                }

            print()  # Add spacing between sequential operations

        # For sequential mode, return results immediately
        return [completed_results.get(pm, {
            'pm': pm,
            'success': False,
            'output': '',
            'error': 'Unknown - result not found'
        }) for pm in selected_pms]

    # Phase 2: Poll all operations concurrently until completion (parallel mode only)
    completed_results = {}  # pm_name -> result
    pending_operations = spawned_operations.copy()

    while pending_operations:
        completed_this_round = []

        for operation in pending_operations:
            pm = operation['pm']

            # Skip if already failed to spawn
            if not operation.get('status_file'):
                final_result = {
                    'pm': pm,
                    'success': False,
                    'output': '',
                    'error': operation.get('error', 'Failed to spawn terminal')
                }
                completed_results[pm] = final_result
                completed_this_round.append(operation)
                print(f"  ❌ {pm}: Failed to spawn")
                continue

            status_file = operation.get('status_file')
            status_info = executor.check_status(status_file)

            if status_info.get('status') == 'completed':
                exit_code = status_info.get('exit_code', 0)
                final_result = {
                    'pm': pm,
                    'success': exit_code == 0,
                    'output': 'Upgrade completed' if exit_code == 0 else '',
                    'error': '' if exit_code == 0 else f"Upgrade failed with exit code {exit_code}"
                }
                completed_results[pm] = final_result
                completed_this_round.append(operation)

                # Print completion status
                if final_result['success']:
                    print(f"  ✅ {pm}: Upgrade completed successfully")
                else:
                    print(f"  ❌ {pm}: Upgrade failed")

            elif status_info.get('status') == 'error':
                final_result = {
                    'pm': pm,
                    'success': False,
                    'output': '',
                    'error': status_info.get('error', 'Unknown error')
                }
                completed_results[pm] = final_result
                completed_this_round.append(operation)
                print(f"  ❌ {pm}: Upgrade failed")

        # Remove completed operations
        for completed_op in completed_this_round:
            pending_operations.remove(completed_op)

        # Brief pause before next poll cycle (only if there are still pending)
        if pending_operations:
            time.sleep(1)

    # Phase 3: Return results in original order
    ordered_results = []
    for pm in selected_pms:
        if pm in completed_results:
            ordered_results.append(completed_results[pm])
        else:
            # This shouldn't happen, but add a fallback
            ordered_results.append({
                'pm': pm,
                'success': False,
                'output': '',
                'error': 'Unknown - result not found'
            })

    return ordered_results


def main():
    """CLI entry point for package upgrading."""
    print("⬆️ Package Manager Upgrade")
    print("=" * 27)

    # Detect available package managers
    # Detect available package managers for upgrade operations
    available_pms = detect_all_pms(operation='upgrade')

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


if __name__ == '__main__':
    sys.exit(main())
