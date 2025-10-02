#!/usr/bin/env python3
"""
Package Manager Check Module

Check for outdated packages across multiple package managers.
"""

import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Any

# Add current directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from pm_detect import detect_all_pms
from pm_select import select_pms
from terminal_executor import spawn_tracked, _save_terminal_registry
from command_executor import run_command


def check_pm_outdated(pm_name: str) -> Dict[str, Any]:
    """
    Check for outdated packages using a specific package manager.

    Args:
        pm_name: Name of the package manager

    Returns:
        Dict with status, output, and error information
    """
    from .pm_executor import execute_pm_command

    # Use unified executor for non-interactive check
    result = execute_pm_command(pm_name, 'check', interactive=False)

    # Convert to expected format and add count
    if result['success'] and result['output']:
        lines = [line for line in result['output'].split('\n') if line.strip()]
        result['outdated_count'] = len(lines)
    else:
        result['outdated_count'] = 0

    # Add pm name for compatibility
    result['pm'] = pm_name

    return result


def check_pm_outdated_parallel(pm_name: str) -> Dict[str, Any]:
    """
    Launch a package manager check in a terminal window.

    Args:
        pm_name: Name of the package manager

    Returns:
        Dict with spawn status and tracking information
    """
    from .pm_executor import execute_pm_command

    # Use unified executor for interactive check
    result = execute_pm_command(pm_name, 'check', interactive=True)

    # Convert to expected format for compatibility
    if result['success']:
        return {
            'pm': pm_name,
            'status': 'spawned',
            'log_file': result.get('log_file'),
            'status_file': result.get('status_file'),
            'command': result.get('command'),
            'error': ''
        }
    else:
        return {
            'pm': pm_name,
            'status': 'failed',
            'log_file': None,
            'status_file': None,
            'error': result.get('error', 'Unknown error')
        }


def check_all_pms(selected_pms: List[str], parallel: bool = True) -> List[Dict[str, Any]]:
    """
    Check all selected package managers for outdated packages.

    Package managers requiring sudo are run sequentially first, then
    non-sudo PMs are run in parallel to avoid conflicts.

    Args:
        selected_pms: List of selected package manager names
        parallel: Whether to run checks in parallel (True) or sequentially (False)

    Returns:
        List of check results for each PM
    """
    if not selected_pms:
        return []

    import time
    from terminal_executor import create_terminal_executor
    from .pm_executor import requires_sudo

    # Separate sudo-requiring PMs from non-sudo PMs
    # Selected PMs are already sorted by priority from pm_select
    sudo_pms = [pm for pm in selected_pms if requires_sudo(pm, 'check')]
    non_sudo_pms = [pm for pm in selected_pms if not requires_sudo(pm, 'check')]

    print(f"🚀 Checking {len(selected_pms)} package managers...")
    if sudo_pms:
        print(f"   ⚠️  {len(sudo_pms)} require sudo (will run sequentially by priority): {', '.join(sudo_pms)}")
    if non_sudo_pms and parallel:
        print(f"   ⚡ {len(non_sudo_pms)} will run in parallel: {', '.join(non_sudo_pms)}")
    print()

    all_results = {}
    executor = create_terminal_executor()

    # Phase 1: Run sudo PMs sequentially (they need user interaction for password)
    if sudo_pms:
        print(f"📋 Running {len(sudo_pms)} sudo-requiring PM(s) sequentially...")
        for pm in sudo_pms:
            print(f"\n🔍 Checking {pm} (requires sudo)...")
            result = check_pm_outdated_parallel(pm)

            if result['status'] == 'spawned':
                print(f"  💻 Command: {result.get('command', 'Unknown command')}")
                print(f"  🖥️  Executing in new terminal window...")
                print(f"  📄 Log: {result.get('log_file')}")
                print(f"  ⏳ Waiting for {pm} to complete (you may need to enter sudo password)...")

                # Wait for this sudo operation to complete
                status_file = result.get('status_file')
                if status_file:
                    while True:
                        status_info = executor.check_status(status_file)
                        if status_info.get('status') == 'completed':
                            exit_code = status_info.get('exit_code', 0)

                            # Read log file
                            log_content = ''
                            try:
                                from pathlib import Path
                                log_content = Path(result['log_file']).read_text().strip()
                            except Exception:
                                pass

                            # Check success
                            from .pm_executor import is_success_exit_code
                            is_success = is_success_exit_code(pm, 'check', exit_code, bool(log_content))

                            final_result = {
                                'pm': pm,
                                'success': is_success,
                                'output': log_content if is_success else '',
                                'error': f"Check failed with exit code {exit_code}" if not is_success else '',
                                'outdated_count': 0
                            }

                            if is_success and log_content:
                                lines = [line for line in log_content.split('\n') if line.strip()]
                                final_result['outdated_count'] = len(lines)

                            all_results[pm] = final_result

                            if final_result['success']:
                                if final_result['outdated_count'] > 0:
                                    print(f"  ✅ {pm}: {final_result['outdated_count']} outdated packages")
                                else:
                                    print(f"  ✅ {pm}: All packages up to date")
                            else:
                                print(f"  ❌ {pm}: Check failed")
                            break

                        elif status_info.get('status') == 'error':
                            all_results[pm] = {
                                'pm': pm,
                                'success': False,
                                'output': '',
                                'error': status_info.get('error', 'Unknown error'),
                                'outdated_count': 0
                            }
                            print(f"  ❌ {pm}: Check failed")
                            break
                        else:
                            time.sleep(1)
            else:
                print(f"  ❌ Failed to spawn: {result.get('error', 'Unknown error')}")
                all_results[pm] = {
                    'pm': pm,
                    'success': False,
                    'output': '',
                    'error': result.get('error', 'Failed to spawn terminal'),
                    'outdated_count': 0
                }

        print(f"\n✅ Sudo PM(s) completed\n")

    # Phase 2: Run non-sudo PMs (in parallel if enabled)
    spawned_operations = []
    if non_sudo_pms:
        if parallel:
            print(f"🚀 Launching {len(non_sudo_pms)} package manager checks in parallel...")
        else:
            print(f"🚀 Running {len(non_sudo_pms)} package manager checks sequentially...")
        print()

    if parallel and non_sudo_pms:
        # Launch all at once
        for pm in non_sudo_pms:
            print(f"🔍 Launching {pm} check...")
            result = check_pm_outdated_parallel(pm)
            if result['status'] == 'spawned':
                print(f"  💻 Command: {result.get('command', 'Unknown command')}")
                print(f"  🖥️  Executing in new terminal window...")
                print(f"  📄 Log: {result.get('log_file')}")
                spawned_operations.append(result)
                print(f"  ✅ Spawned successfully")
            else:
                print(f"  ❌ Failed to spawn: {result.get('error', 'Unknown error')}")
                # Keep failed spawns for result processing
                spawned_operations.append(result)

        print(f"\n⏳ Waiting for all {len(spawned_operations)} checks to complete...")
    else:
        # Launch and wait for each one sequentially
        completed_results = {}
        for pm in selected_pms:
            print(f"🔍 Checking {pm}...")
            result = check_pm_outdated_parallel(pm)

            if result['status'] == 'spawned':
                print(f"  💻 Command: {result.get('command', 'Unknown command')}")
                print(f"  🖥️  Executing in new terminal window...")
                print(f"  📄 Log: {result.get('log_file')}")
                print(f"  ⏳ Waiting for {pm} to complete...")

                # Wait for this specific operation to complete
                status_file = result.get('status_file')
                if status_file:
                    while True:
                        status_info = executor.check_status(status_file)
                        if status_info.get('status') == 'completed':
                            exit_code = status_info.get('exit_code', 0)

                            # Read log file first to check for output
                            log_content = ''
                            try:
                                from pathlib import Path
                                log_content = Path(result['log_file']).read_text().strip()
                            except Exception as e:
                                pass

                            # Use exit code helper to determine success
                            from .pm_executor import is_success_exit_code
                            is_success = is_success_exit_code(pm, 'check', exit_code, bool(log_content))

                            final_result = {
                                'pm': pm,
                                'success': is_success,
                                'output': '',
                                'error': '',
                                'outdated_count': 0
                            }

                            if is_success:
                                # Store the output
                                final_result['output'] = log_content

                                # Simple line count for packages (non-empty lines)
                                if log_content:
                                    lines = [line for line in log_content.split('\n') if line.strip()]
                                    final_result['outdated_count'] = len(lines)
                            else:
                                final_result['error'] = f"Check failed with exit code {exit_code}"

                            completed_results[pm] = final_result

                            # Print completion status
                            if final_result['success']:
                                if final_result['outdated_count'] > 0:
                                    print(f"  ✅ {pm}: {final_result['outdated_count']} outdated packages")
                                else:
                                    print(f"  ✅ {pm}: All packages up to date")
                            else:
                                print(f"  ❌ {pm}: Check failed")
                            break

                        elif status_info.get('status') == 'error':
                            final_result = {
                                'pm': pm,
                                'success': False,
                                'output': '',
                                'error': status_info.get('error', 'Unknown error'),
                                'outdated_count': 0
                            }
                            completed_results[pm] = final_result
                            print(f"  ❌ {pm}: Check failed")
                            break
                        else:
                            # Still running, wait a bit
                            time.sleep(1)
            else:
                print(f"  ❌ Failed to spawn: {result.get('error', 'Unknown error')}")
                completed_results[pm] = {
                    'pm': pm,
                    'success': False,
                    'output': '',
                    'error': result.get('error', 'Failed to spawn terminal'),
                    'outdated_count': 0
                }

            print()  # Add spacing between sequential operations

        # For sequential mode, return results immediately
        return [completed_results.get(pm, {
            'pm': pm,
            'success': False,
            'output': '',
            'error': 'Unknown - result not found',
            'outdated_count': 0
        }) for pm in selected_pms]

    # Phase 2: Poll all operations concurrently until completion (parallel mode only)
    completed_results = {}  # pm_name -> result
    pending_operations = spawned_operations.copy()

    while pending_operations:
        completed_this_round = []

        for operation in pending_operations:
            pm = operation['pm']

            # Skip if already failed to spawn
            if operation['status'] != 'spawned':
                final_result = {
                    'pm': pm,
                    'success': False,
                    'output': '',
                    'error': operation.get('error', 'Failed to spawn terminal'),
                    'outdated_count': 0
                }
                completed_results[pm] = final_result
                completed_this_round.append(operation)
                print(f"  ❌ {pm}: Failed to spawn")
                continue

            status_file = operation.get('status_file')
            if not status_file:
                continue

            status_info = executor.check_status(status_file)

            if status_info.get('status') == 'completed':
                exit_code = status_info.get('exit_code', 0)

                # Read log file first to check for output
                log_content = ''
                try:
                    from pathlib import Path
                    log_content = Path(operation['log_file']).read_text().strip()
                except Exception as e:
                    pass

                # Use exit code helper to determine success
                from .pm_executor import is_success_exit_code
                is_success = is_success_exit_code(pm, 'check', exit_code, bool(log_content))

                final_result = {
                    'pm': pm,
                    'success': is_success,
                    'output': '',
                    'error': '',
                    'outdated_count': 0
                }

                if is_success:
                    # Store the output
                    final_result['output'] = log_content

                    # Simple line count for packages (non-empty lines)
                    if log_content:
                        lines = [line for line in log_content.split('\n') if line.strip()]
                        final_result['outdated_count'] = len(lines)
                    else:
                        final_result['outdated_count'] = 0
                else:
                    final_result['error'] = f"Check failed with exit code {exit_code}"

                completed_results[pm] = final_result
                completed_this_round.append(operation)

                # Print completion status
                if final_result['success']:
                    if final_result['outdated_count'] > 0:
                        print(f"  ✅ {pm}: {final_result['outdated_count']} outdated packages")
                    else:
                        print(f"  ✅ {pm}: All packages up to date")
                else:
                    print(f"  ❌ {pm}: Check failed")

            elif status_info.get('status') == 'error':
                final_result = {
                    'pm': pm,
                    'success': False,
                    'output': '',
                    'error': status_info.get('error', 'Unknown error'),
                    'outdated_count': 0
                }
                completed_results[pm] = final_result
                completed_this_round.append(operation)
                print(f"  ❌ {pm}: Check failed")

        # Remove completed operations
        for completed_op in completed_this_round:
            pending_operations.remove(completed_op)

        # Brief pause before next poll cycle (only if there are still pending)
        if pending_operations:
            time.sleep(1)

    # Phase 3: Merge all results (sudo + non-sudo) and return in original order
    # Merge completed_results from non-sudo PMs with all_results from sudo PMs
    all_completed_results = {**all_results, **completed_results}

    ordered_results = []
    for pm in selected_pms:
        if pm in all_completed_results:
            ordered_results.append(all_completed_results[pm])
        else:
            # This shouldn't happen, but add a fallback
            ordered_results.append({
                'pm': pm,
                'success': False,
                'output': '',
                'error': 'Unknown - result not found',
                'outdated_count': 0
            })

    return ordered_results


def main():
    """CLI entry point for package checking."""
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

    # Select package managers to check
    selected_pms = select_pms(available_pms)

    if not selected_pms:
        print("⏭️ No package managers selected - nothing to check")
        return 0

    print(f"\n🎯 Checking {len(selected_pms)} package managers...")
    print()

    # Check all selected package managers
    results = check_all_pms(selected_pms)

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
    from terminal_executor import prompt_close_terminals
    prompt_close_terminals()

    return 0


if __name__ == '__main__':
    sys.exit(main())
