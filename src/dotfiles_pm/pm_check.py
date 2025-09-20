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
from terminal_executor import spawn_tracked
from command_executor import run_command


def check_pm_outdated(pm_name: str) -> Dict[str, Any]:
    """
    Check for outdated packages using a specific package manager.

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
        'outdated_count': 0
    }

    # Define commands for different package managers
    commands = {
        'brew': ['brew', 'outdated', '--verbose'],
        'npm': ['npm', 'outdated', '-g'],
        'pip': ['pip3', 'list', '--outdated'],
        'pipx': ['pipx', 'list', '--short'],
        'cargo': ['cargo', 'install-update', '--list'],
        'gem': ['gem', 'outdated'],
        'fake-pm1': ['fake-pm1', 'outdated'],
        'fake-pm2': ['fake-pm2', 'outdated'],
    }

    if pm_name not in commands:
        result['error'] = f"No check command defined for {pm_name}"
        return result

    try:
        cmd = commands[pm_name]

        # Special handling for brew - run update first in terminal
        if pm_name == 'brew':
            update_cmd = 'brew update'
            print(f"🚀 Updating brew formulae from GitHub...")
            print(f"  💻 Command: {update_cmd}")
            print(f"  🖥️  Executing in new terminal window...")

            update_result = spawn_tracked(
                update_cmd,
                operation='brew-update',
                auto_close=True  # Auto-close after 3 seconds on success
            )

            if update_result['status'] == 'spawned':
                print(f"  📄 Log: {update_result.get('log_file')}")
                # Wait for completion by polling status file
                import time
                from terminal_executor import create_terminal_executor

                status_file = update_result.get('status_file')
                if status_file:
                    executor = create_terminal_executor()

                    # Poll until completion (like in upgrade)
                    print(f"  ⏳ Waiting for brew update to complete...")
                    while True:
                        status_info = executor.check_status(status_file)
                        if status_info.get('status') == 'completed':
                            break
                        elif status_info.get('status') == 'error':
                            break
                        else:
                            # Still running, wait a bit
                            time.sleep(2)

                    if status_info.get('exit_code') != 0:
                        print(f"  ❌ brew update failed (exit code: {status_info.get('exit_code')})")
                        print(f"  📋 Error output:")
                        # Read and display the log
                        log_file = update_result.get('log_file')
                        log_content = ""
                        if log_file:
                            try:
                                from pathlib import Path
                                log_content = Path(log_file).read_text().strip()
                                if log_content:
                                    for line in log_content.split('\n'):
                                        print(f"     {line}")
                                else:
                                    print("     (no output)")
                            except Exception as e:
                                print(f"     Could not read log: {e}")

                        # Check if it's a lock issue and offer solutions
                        if "already locked" in log_content:
                            print(f"\n  🔒 Another brew process is running.")
                            print(f"  What would you like to do?")
                            print(f"    1) Wait and retry (kill lock, then retry update)")
                            print(f"    2) Continue without update (skip to package check)")
                            print(f"    3) Abort")

                            while True:
                                choice = input(f"  Choose [1-3]: ").strip()
                                if choice == '1':
                                    print(f"  🔓 Clearing brew lock and retrying...")
                                    try:
                                        import subprocess
                                        subprocess.run(['rm', '-f', '/opt/homebrew/var/homebrew/locks/update'], check=False)
                                        subprocess.run(['rm', '-f', '/usr/local/var/homebrew/locks/update'], check=False)
                                        print(f"  🔄 Retrying brew update...")
                                        retry_result = spawn_tracked('brew update', 'brew-update-retry', auto_close=True)
                                        print(f"  📄 Retry log: {retry_result.get('log_file')}")
                                        time.sleep(6)
                                    except Exception as e:
                                        print(f"  ❌ Failed to clear lock: {e}")
                                    break
                                elif choice == '2':
                                    print(f"  ⏭️  Skipping brew update, continuing with package check...")
                                    break
                                elif choice == '3':
                                    print(f"  ❌ Aborting brew check")
                                    result['success'] = False
                                    result['error'] = "User aborted due to lock issue"
                                    return result
                                else:
                                    print(f"  Invalid choice. Please enter 1, 2, or 3.")
                    else:
                        print(f"  ✅ brew update completed successfully")
            else:
                print(f"  ❌ Failed to spawn terminal: {update_result.get('error', 'Unknown error')}")

        # Now check for outdated packages
        proc = run_command(cmd, timeout=30)

        result['output'] = proc.stdout.strip()
        result['error'] = proc.stderr.strip()
        result['success'] = proc.returncode == 0

        # Count outdated packages (simple line count for now)
        if result['success'] and result['output']:
            lines = [line for line in result['output'].split('\n') if line.strip()]
            result['outdated_count'] = len(lines)

    except subprocess.TimeoutExpired:
        result['error'] = f"Command timed out after 30 seconds"
    except FileNotFoundError:
        result['error'] = f"Command not found: {' '.join(cmd)}"
    except Exception as e:
        result['error'] = f"Unexpected error: {str(e)}"

    return result


def check_pm_outdated_parallel(pm_name: str) -> Dict[str, Any]:
    """
    Launch a package manager check in a terminal window.

    Args:
        pm_name: Name of the package manager

    Returns:
        Dict with spawn status and tracking information
    """
    result = {
        'pm': pm_name,
        'status': 'failed',
        'log_file': None,
        'status_file': None,
        'error': ''
    }

    # Define commands for different package managers
    commands = {
        'brew': ['brew', 'outdated', '--verbose'],
        'npm': ['npm', 'outdated', '-g'],
        'pip': ['pip3', 'list', '--outdated'],
        'pipx': ['pipx', 'list', '--short'],
        'cargo': ['cargo', 'install-update', '--list'],
        'gem': ['gem', 'outdated'],
        'fake-pm1': ['fake-pm1', 'outdated'],
        'fake-pm2': ['fake-pm2', 'outdated'],
    }

    if pm_name not in commands:
        result['error'] = f"No check command defined for {pm_name}"
        return result

    cmd = commands[pm_name]
    cmd_str = ' '.join(cmd)

    # Special handling for brew - run update first
    if pm_name == 'brew':
        cmd_str = 'brew update && ' + cmd_str

    print(f"  💻 Command: {cmd_str}")
    print(f"  🖥️  Executing in new terminal window...")

    from terminal_executor import spawn_tracked

    try:
        terminal_result = spawn_tracked(
            cmd_str,
            operation=f'{pm_name}-check',
            auto_close=False  # Keep terminals open for review
        )

        if terminal_result['status'] == 'spawned':
            result['status'] = 'spawned'
            result['log_file'] = terminal_result.get('log_file')
            result['status_file'] = terminal_result.get('status_file')
            print(f"  📄 Log: {terminal_result.get('log_file')}")
        else:
            result['error'] = terminal_result.get('error', 'Failed to spawn terminal')
            print(f"  ❌ Failed to spawn terminal: {result['error']}")

    except Exception as e:
        result['error'] = f"Unexpected error: {str(e)}"
        print(f"  ❌ Error: {result['error']}")

    return result


def check_all_pms(selected_pms: List[str]) -> List[Dict[str, Any]]:
    """
    Check all selected package managers for outdated packages in parallel pipeline.

    Args:
        selected_pms: List of selected package manager names

    Returns:
        List of check results for each PM
    """
    if not selected_pms:
        return []

    import time
    from terminal_executor import create_terminal_executor

    # Phase 1: Launch all terminals simultaneously
    print(f"🚀 Launching {len(selected_pms)} package manager checks in parallel...")
    print()

    spawned_operations = []
    for pm in selected_pms:
        print(f"🔍 Launching {pm} check...")
        result = check_pm_outdated_parallel(pm)
        if result['status'] == 'spawned':
            spawned_operations.append(result)
            print(f"  ✅ Spawned successfully")
        else:
            print(f"  ❌ Failed to spawn: {result.get('error', 'Unknown error')}")
            # Keep failed spawns for result processing
            spawned_operations.append(result)

    print(f"\n⏳ Waiting for all {len(spawned_operations)} checks to complete...")

    # Phase 2: Poll all operations concurrently until completion
    executor = create_terminal_executor()
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
                final_result = {
                    'pm': pm,
                    'success': exit_code == 0,
                    'output': '',
                    'error': '',
                    'outdated_count': 0
                }

                if exit_code == 0:
                    # Read log file to get output and count outdated packages
                    try:
                        from pathlib import Path
                        log_content = Path(operation['log_file']).read_text().strip()
                        final_result['output'] = log_content

                        if log_content:
                            lines = [line for line in log_content.split('\n') if line.strip()]
                            final_result['outdated_count'] = len(lines)
                    except Exception as e:
                        final_result['error'] = f"Could not read log: {e}"
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
                'error': 'Unknown - result not found',
                'outdated_count': 0
            })

    return ordered_results


def main():
    """CLI entry point for package checking."""
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

    # Summary
    print("\n📊 Check Summary")
    print("================")

    total_outdated = 0
    successful_checks = 0

    for result in results:
        status = "✅" if result['success'] else "❌"
        pm = result['pm']

        if result['success']:
            successful_checks += 1
            count = result['outdated_count']
            total_outdated += count
            print(f"{status} {pm}: {count} outdated packages")
        else:
            print(f"{status} {pm}: Check failed")

    print()
    print(f"📈 Total outdated packages: {total_outdated}")
    print(f"🎯 Successful checks: {successful_checks}/{len(selected_pms)}")

    # Offer to close spawned terminals
    from terminal_executor import prompt_close_terminals
    prompt_close_terminals()

    return 0


if __name__ == '__main__':
    sys.exit(main())
