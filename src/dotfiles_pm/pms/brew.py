#!/usr/bin/env python3
"""Homebrew Package Manager with Lock Recovery"""

from typing import List, Dict, Any
import sys
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class BrewPM(PackageManager):
    """Homebrew package manager with intelligent lock handling"""

    def __init__(self):
        super().__init__('brew')
        # Import here to avoid circular dependencies
        try:
            from .brew_utils import brew_lock_manager
            self.lock_manager = brew_lock_manager
        except ImportError:
            self.lock_manager = None

    @property
    def check_command(self) -> List[str]:
        return ["brew", "update", "&&", "brew", "outdated", "--verbose"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["brew", "upgrade"]

    @property
    def install_command(self) -> List[str]:
        return ["brew", "bundle", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10

    def execute_command(self, command: List[str], operation: str = "unknown") -> Dict[str, Any]:
        """
        Execute brew command with lock recovery

        Args:
            command: Command to execute
            operation: Operation name for logging

        Returns:
            Dict with execution results and recovery info
        """
        if not self.lock_manager:
            # Fallback to standard execution
            return self._execute_standard(command)

        try:
            # Use lock detection (no retry - just detect and raise)
            result = self.lock_manager.execute_with_lock_detection(command)

            return {
                'success': result.returncode == 0,
                'output': result.stdout.strip(),
                'error': result.stderr.strip() if result.returncode != 0 else '',
                'exit_code': result.returncode,
                'recovery_used': False
            }

        except Exception as e:
            # Import here to avoid circular imports
            from .brew_utils import BrewLockError

            if isinstance(e, BrewLockError):
                # Brew lock detected - let justfile handle with doctor command
                raise SystemExit(41)  # Specific exit code for brew lock

            # Re-raise other exceptions
            raise

        except subprocess.CalledProcessError as e:
            # Other brew errors (not lock-related)
            return {
                'success': False,
                'output': e.stdout.strip() if e.stdout else '',
                'error': e.stderr.strip() if e.stderr else str(e),
                'exit_code': e.returncode,
                'recovery_used': False
            }

    def _execute_standard(self, command: List[str]) -> Dict[str, Any]:
        """Fallback standard execution without lock recovery"""
        try:
            # Check if command contains shell operators
            needs_shell = any(op in ' '.join(command) for op in ['&&', '||', '|', ';', '>', '<'])

            if needs_shell:
                # Convert to shell string and use shell=True
                cmd_str = ' '.join(command)
                result = subprocess.run(
                    cmd_str,
                    capture_output=True,
                    text=True,
                    shell=True,
                    timeout=300
                )
            else:
                # Use list form without shell
                result = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    timeout=300
                )

            return {
                'success': result.returncode == 0,
                'output': result.stdout.strip(),
                'error': result.stderr.strip() if result.returncode != 0 else '',
                'exit_code': result.returncode,
                'recovery_used': False
            }

        except Exception as e:
            return {
                'success': False,
                'output': '',
                'error': str(e),
                'exit_code': -1,
                'recovery_used': False
            }
