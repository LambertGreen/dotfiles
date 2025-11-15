#!/usr/bin/env python3
"""
Unified Package Manager Command Executor

Single place for all package manager command execution - no special cases!
"""

import sys
import subprocess
from typing import Dict, Any, List
from pathlib import Path

# Add current directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from terminal_executor import spawn_tracked
from pm_registry import PM_REGISTRY, get_pm


def get_pm_commands() -> Dict[str, Dict[str, Any]]:
    """
    Get package manager configuration from PM_REGISTRY.

    Returns:
        Dict mapping pm_name -> {
            'check': command_list,
            'upgrade': command_list,
            'install': command_list,
            'sudo_required': bool,
            'priority': int
        }
    """
    result = {}
    for pm_name, pm_instance in PM_REGISTRY.items():
        result[pm_name] = {
            'check': pm_instance.check_command,
            'upgrade': pm_instance.upgrade_command,
            'install': pm_instance.install_command,
            'sudo_required': pm_instance.requires_sudo,
            'priority': pm_instance.priority
        }
    return result


def get_pm_priority(pm_name: str) -> int:
    """
    Get the priority for a package manager from configuration.
    Lower numbers run first.

    Priority levels:
    - 0: System package managers (apt, yum, dnf, pacman)
    - 10: User-level package managers (brew, cargo, gem, etc.)

    Args:
        pm_name: Package manager name

    Returns:
        Priority level (lower runs first), defaults to 10 if not found
    """
    commands = get_pm_commands()

    if pm_name not in commands:
        return 10  # Default to user-level priority

    # Get priority from config, default to 10 if not specified
    return commands[pm_name].get('priority', 10)


def requires_sudo(pm_name: str, operation: str = 'check') -> bool:
    """
    Check if a package manager requires sudo for operations.

    Uses explicit 'sudo_required' metadata field, not command inference.
    This is correct because PMs may run sudo internally in scripts.

    Args:
        pm_name: Package manager name
        operation: Operation being performed (unused, kept for compatibility)

    Returns:
        True if the PM requires sudo
    """
    commands = get_pm_commands()

    if pm_name not in commands:
        return False

    # Use explicit sudo_required flag from metadata
    return commands[pm_name].get('sudo_required', False)


def is_success_exit_code(pm_name: str, operation: str, exit_code: int, has_output: bool) -> bool:
    """
    Determine if an exit code indicates success for a given PM and operation.

    Some package managers return non-zero exit codes in valid scenarios:
    - npm outdated returns 1 when packages are outdated
    - pip list --outdated returns 0 always

    Args:
        pm_name: Package manager name
        operation: Operation being performed
        exit_code: The exit code from the command
        has_output: Whether the command produced output

    Returns:
        True if this exit code indicates success
    """
    # Standard success
    if exit_code == 0:
        return True

    # npm outdated returns 1 when there are outdated packages (which is success)
    if pm_name == 'npm' and operation == 'check' and exit_code == 1 and has_output:
        return True

    # pacman -Qu returns 1 when there are no updates (which is success - all up to date)
    if pm_name == 'pacman' and operation == 'check' and exit_code == 1:
        return True  # Exit code 1 means no updates available, which is success

    # All other non-zero exit codes are failures
    return False


def execute_pm_command(pm_name: str, operation: str, interactive: bool = True) -> Dict[str, Any]:
    """
    Execute a package manager command in a unified way.

    Args:
        pm_name: Name of package manager (brew, npm, pip, etc.)
        operation: Operation to perform (check, upgrade, install)
        interactive: Whether to run in terminal (True) or capture output (False)

    Returns:
        Dict with execution results
    """
    commands = get_pm_commands()

    if pm_name not in commands:
        return {
            'success': False,
            'error': f"Package manager '{pm_name}' not supported",
            'output': ''
        }

    if operation not in commands[pm_name]:
        return {
            'success': False,
            'error': f"Operation '{operation}' not supported for {pm_name}",
            'output': ''
        }

    cmd_list = commands[pm_name][operation]
    # Join command for Windows - quote arguments with spaces for cmd.exe
    import platform
    if platform.system() == 'Windows' or sys.platform in ('win32', 'cygwin'):
        # Windows: quote arguments that have spaces (cmd.exe style)
        def quote_arg(arg):
            if ' ' in arg:
                return '"' + arg + '"'
            return arg
        cmd_str = ' '.join(quote_arg(arg) for arg in cmd_list)
    else:
        # Unix: use shlex.join (single quotes work fine)
        import shlex
        cmd_str = shlex.join(cmd_list)

    # Check if the PM has a custom execute_command method (like BrewPM for lock recovery)
    pm_instance = get_pm(pm_name)
    if pm_instance and hasattr(pm_instance, 'execute_command') and not interactive:
        # Use the PM's custom execution logic for non-interactive runs
        try:
            pm_result = pm_instance.execute_command(cmd_list, operation)
            return {
                'success': pm_result.get('success', False),
                'output': pm_result.get('output', ''),
                'error': pm_result.get('error', ''),
                'exit_code': pm_result.get('exit_code', -1),
                'recovery_used': pm_result.get('recovery_used', False)
            }
        except Exception as e:
            return {
                'success': False,
                'error': f"PM execute_command failed: {str(e)}",
                'output': ''
            }

    if interactive:
        # Run in terminal with tracking
        # Use simple operation name for terminal title (not the full command)
        operation_label = f"{pm_name}-{operation}"
        terminal_result = spawn_tracked(
            cmd_str,
            operation=operation_label,  # Simple name for terminal title
            auto_close=False
        )

        if terminal_result.status in ['spawned', 'completed']:
            return {
                'success': True,
                'log_file': terminal_result.log_file,
                'status_file': terminal_result.status_file,
                'command': cmd_str
            }
        else:
            return {
                'success': False,
                'error': terminal_result.error or 'Failed to spawn terminal',
                'output': ''
            }

    else:
        # Run directly and capture output
        try:
            result = subprocess.run(
                cmd_list,
                capture_output=True,
                text=True,
                timeout=60,
                shell=True if '&&' in cmd_list else False
            )

            return {
                'success': result.returncode == 0,
                'output': result.stdout.strip(),
                'error': result.stderr.strip() if result.returncode != 0 else '',
                'exit_code': result.returncode
            }

        except subprocess.TimeoutExpired:
            return {
                'success': False,
                'error': 'Command timed out after 60 seconds',
                'output': ''
            }
        except Exception as e:
            return {
                'success': False,
                'error': f"Execution failed: {str(e)}",
                'output': ''
            }
