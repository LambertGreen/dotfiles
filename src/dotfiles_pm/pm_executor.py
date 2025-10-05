#!/usr/bin/env python3
"""
Unified Package Manager Command Executor

Single place for all package manager command execution - no special cases!
"""

import sys
import subprocess
import tomllib
from typing import Dict, Any, List
from pathlib import Path

# Add current directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from terminal_executor import spawn_tracked

# Cache for loaded PM config
_pm_config_cache = None


def get_pm_commands() -> Dict[str, Dict[str, Any]]:
    """
    Load package manager configuration from TOML file.

    Returns:
        Dict mapping pm_name -> {
            'check': command_list,
            'upgrade': command_list,
            'install': command_list,
            'sudo_required': bool,
            'priority': int
        }
    """
    global _pm_config_cache

    # Return cached config if available
    if _pm_config_cache is not None:
        return _pm_config_cache

    # Load from TOML file
    config_file = Path(__file__).parent / 'pm_config.toml'

    try:
        with open(config_file, 'rb') as f:
            _pm_config_cache = tomllib.load(f)
        return _pm_config_cache
    except FileNotFoundError:
        raise RuntimeError(f"PM configuration file not found: {config_file}")
    except Exception as e:
        raise RuntimeError(f"Failed to load PM configuration: {e}")


def _get_pm_commands_legacy() -> Dict[str, Dict[str, Any]]:
    """
    Legacy hardcoded PM commands (kept for reference, not used).
    All configuration now lives in pm_config.toml.
    """
    return {
        'apt': {
            'check': ['sudo', 'apt-get', 'update', '&&', 'apt', 'list', '--upgradable'],
            'upgrade': ['sudo', 'apt-get', 'upgrade'],
            'install': ['sudo', 'apt-get', 'install'],
            'sudo_required': True
        },
        'brew': {
            'check': ['brew', 'update', '&&', 'brew', 'outdated', '--verbose'],
            'upgrade': ['brew', 'upgrade'],
            'install': ['brew', 'bundle', 'install'],
            'sudo_required': False
        },
        'npm': {
            'check': ['npm', 'outdated', '-g'],
            'upgrade': ['npm', 'update', '-g'],
            'install': ['npm', 'install', '-g'],
            'sudo_required': False
        },
        'pip': {
            'check': ['pip3', 'list', '--outdated'],
            'upgrade': ['pip3', 'install', '--upgrade'],
            'install': ['pip3', 'install'],
            'sudo_required': False
        },
        'pipx': {
            'check': ['pipx', 'list', '--short'],
            'upgrade': ['pipx', 'upgrade-all'],
            'install': ['pipx', 'install'],
            'sudo_required': False
        },
        'cargo': {
            'check': ['cargo', 'install-update', '--list'],
            'upgrade': ['cargo', 'install-update', '-a'],
            'install': ['cargo', 'install'],
            'sudo_required': False
        },
        'gem': {
            'check': ['gem', 'outdated'],
            'upgrade': ['gem', 'update'],
            'install': ['gem', 'install'],
            'sudo_required': False
        },
        'fake-pm1': {
            'check': ['echo', 'fake-pm1: 5 packages outdated'],
            'upgrade': ['echo', 'fake-pm1: upgrading packages...'],
            'install': ['echo', 'fake-pm1: installing packages...'],
            'sudo_required': False
        },
        'fake-pm2': {
            'check': ['echo', 'fake-pm2: 3 packages outdated'],
            'upgrade': ['echo', 'fake-pm2: upgrading packages...'],
            'install': ['echo', 'fake-pm2: installing packages...'],
            'sudo_required': False
        },
        'fake-sudo-pm': {
            # Simulates a sudo-requiring PM for testing priority/ordering
            # Uses sleep to simulate time taken for sudo password entry
            'check': ['sh', '-c', 'sleep 2 && echo "fake-sudo-pm: 7 packages outdated"'],
            'upgrade': ['sh', '-c', 'sleep 2 && echo "fake-sudo-pm: upgraded"'],
            'install': ['sh', '-c', 'sleep 2 && echo "fake-sudo-pm: installed"'],
            'sudo_required': True
        },
        'zinit': {
            'check': ["zsh -i -c 'zinit times'"],
            'upgrade': ["zsh -i -c 'zinit self-update && zinit update --all'"],
            'install': ["zsh -i -c 'true'"],
            'sudo_required': False
        },
        'emacs': {
            'check': ['env', 'DOTFILES_EMACS_CHECK=1', 'emacs', '--batch', '-l', '~/.emacs.d/init.el'],
            'upgrade': ['env', 'DOTFILES_EMACS_UPDATE=1', 'emacs', '--batch', '-l', '~/.emacs.d/init.el'],
            'install': ['env', 'DOTFILES_EMACS_INSTALL=1', 'emacs', '--batch', '-l', '~/.emacs.d/init.el'],
            'sudo_required': False
        },
        'neovim': {
            'check': ['nvim', '--headless', '-c', 'Lazy check', '-c', 'qa'],
            'upgrade': ['nvim', '--headless', '-c', 'Lazy sync', '-c', 'qa'],
            'install': ['nvim', '--headless', '-c', 'Lazy install', '-c', 'qa'],
            'sudo_required': False
        }
    }


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
