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


def get_pm_commands() -> Dict[str, Dict[str, List[str]]]:
    """
    Get all package manager commands defined in one place.
    No special case logic - just the correct commands.

    Returns:
        Dict mapping pm_name -> operation -> command_list
    """
    return {
        'apt': {
            # Use apt-get for scripting (apt man page recommendation for automation)
            # apt is designed for interactive use and may change behavior between versions
            # Note: apt-get update requires sudo - user will be prompted in terminal
            'check': ['sudo', 'apt-get', 'update', '&&', 'apt', 'list', '--upgradable'],
            'upgrade': ['sudo', 'apt-get', 'upgrade'],
            'install': ['sudo', 'apt-get', 'install']
        },
        'brew': {
            'check': ['brew', 'update', '&&', 'brew', 'outdated', '--verbose'],
            'upgrade': ['brew', 'upgrade'],
            'install': ['brew', 'bundle', 'install']
        },
        'npm': {
            'check': ['npm', 'outdated', '-g'],
            'upgrade': ['npm', 'update', '-g'],
            'install': ['npm', 'install', '-g']
        },
        'pip': {
            'check': ['pip3', 'list', '--outdated'],
            'upgrade': ['pip3', 'install', '--upgrade'],  # Will be modified per package
            'install': ['pip3', 'install']
        },
        'pipx': {
            'check': ['pipx', 'list', '--short'],
            'upgrade': ['pipx', 'upgrade-all'],
            'install': ['pipx', 'install']
        },
        'cargo': {
            'check': ['cargo', 'install-update', '--list'],
            'upgrade': ['cargo', 'install-update', '-a'],
            'install': ['cargo', 'install']
        },
        'gem': {
            'check': ['gem', 'outdated'],
            'upgrade': ['gem', 'update'],
            'install': ['gem', 'install']
        },
        'fake-pm1': {
            'check': ['fake-pm1', 'outdated'],
            'upgrade': ['fake-pm1', 'upgrade'],
            'install': ['fake-pm1', 'install']
        },
        'fake-pm2': {
            'check': ['fake-pm2', 'outdated'],
            'upgrade': ['fake-pm2', 'upgrade'],
            'install': ['fake-pm2', 'install']
        },
        'zinit': {
            'check': ["zsh -i -c 'zinit times'"],
            'upgrade': ["zsh -i -c 'zinit self-update && zinit update --all'"],
            'install': ["zsh -i -c 'true'"]
        },
        'emacs': {
            'check': ['env', 'DOTFILES_EMACS_CHECK=1', 'emacs', '--batch', '-l', '~/.emacs.d/init.el'],
            'upgrade': ['env', 'DOTFILES_EMACS_UPDATE=1', 'emacs', '--batch', '-l', '~/.emacs.d/init.el'],
            'install': ['env', 'DOTFILES_EMACS_INSTALL=1', 'emacs', '--batch', '-l', '~/.emacs.d/init.el']
        },
        'neovim': {
            'check': ['nvim', '--headless', '-c', 'Lazy check', '-c', 'qa'],
            'upgrade': ['nvim', '--headless', '-c', 'Lazy sync', '-c', 'qa'],
            'install': ['nvim', '--headless', '-c', 'Lazy install', '-c', 'qa']
        }
    }


def get_pm_priority(pm_name: str) -> int:
    """
    Get the priority for a package manager.
    Lower numbers run first.

    Priority levels:
    - 0: System package managers (apt, yum, dnf, pacman)
    - 1: User-level package managers with sudo (none currently)
    - 10: User-level package managers (brew, cargo, gem, etc.)

    Args:
        pm_name: Package manager name

    Returns:
        Priority level (lower runs first)
    """
    # System package managers - run these first
    system_pms = ['apt', 'yum', 'dnf', 'pacman', 'zypper']
    if pm_name in system_pms:
        return 0

    # All other PMs are user-level
    return 10


def requires_sudo(pm_name: str, operation: str) -> bool:
    """
    Check if a package manager operation requires sudo.

    Args:
        pm_name: Package manager name
        operation: Operation being performed

    Returns:
        True if the operation requires sudo
    """
    commands = get_pm_commands()

    if pm_name not in commands or operation not in commands[pm_name]:
        return False

    cmd_list = commands[pm_name][operation]
    # Check if command starts with sudo
    return len(cmd_list) > 0 and cmd_list[0] == 'sudo'


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
    cmd_str = ' '.join(cmd_list)

    if interactive:
        # Run in terminal with tracking
        # Use simple operation name for terminal title (not the full command)
        operation_label = f"{pm_name}-{operation}"
        terminal_result = spawn_tracked(
            cmd_str,
            operation=operation_label,  # Simple name for terminal title
            auto_close=False
        )

        if terminal_result['status'] in ['spawned', 'completed']:
            return {
                'success': True,
                'log_file': terminal_result.get('log_file'),
                'status_file': terminal_result.get('status_file'),
                'command': cmd_str
            }
        else:
            return {
                'success': False,
                'error': terminal_result.get('error', 'Failed to spawn terminal'),
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
