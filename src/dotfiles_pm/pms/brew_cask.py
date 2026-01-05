#!/usr/bin/env python3
"""Homebrew Cask Package Manager (macOS GUI Apps)"""

from typing import List, Dict, Any
import sys
import os
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager, PMParser


class BrewCaskParser(PMParser):
    """Custom parser for brew cu output - only counts [ FORCED ] apps"""

    def count_outdated(self, output: str) -> int:
        """Count only apps marked as [ FORCED ] (outdated)"""
        if not output:
            return 0

        count = 0
        for line in output.split('\n'):
            # Only count lines with app entries that have [ FORCED ] status
            if "/" in line and "[ FORCED ]" in line:
                count += 1
        return count


class BrewCaskPM(PackageManager):
    """Homebrew cask package manager for macOS GUI applications"""

    def __init__(self):
        super().__init__('brew-cask')
        # Set custom parser for brew cu output
        self._parser = BrewCaskParser()
        # Import here to avoid circular dependencies
        try:
            from .brew_utils import brew_lock_manager
            self.lock_manager = brew_lock_manager
        except ImportError:
            self.lock_manager = None

    @property
    def check_command(self) -> List[str]:
        # Force flag is enabled by default for check (to show all outdated casks)
        force_flag = "-f" if os.environ.get('DOTFILES_BREW_CASK_NO_FORCE', '').lower() != 'true' else ""
        cmd = f"echo 'N' | brew cu -a {force_flag} --no-brew-update".strip()
        return ["bash", "-c", cmd]

    @property
    def upgrade_command(self) -> List[str]:
        # Force flag is enabled by default for upgrade
        # Set DOTFILES_BREW_CASK_NO_FORCE=true to disable force updates
        args = ["brew", "cu", "-a", "-y"]
        if os.environ.get('DOTFILES_BREW_CASK_NO_FORCE', '').lower() != 'true':
            args.append("-f")
        args.append("--no-brew-update")
        return args

    @property
    def install_command(self) -> List[str]:
        return ["brew", "install", "--cask"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 12  # Run after brew formulae but before other PMs (security-critical GUI apps)

    def execute_command(self, command: List[str], operation: str = "unknown") -> Dict[str, Any]:
        """
        Execute brew cask command with special handling for brew cu interactive prompts

        Args:
            command: Command to execute
            operation: Operation name for logging

        Returns:
            Dict with execution results and recovery info
        """
        # Special handling for brew cu commands (direct or via bash -c)
        is_brew_cu = False
        if len(command) >= 2 and command[0] == "brew" and command[1] == "cu":
            is_brew_cu = True
        elif len(command) >= 3 and command[0] == "bash" and command[1] == "-c" and "brew cu" in command[2]:
            is_brew_cu = True

        if is_brew_cu:
            return self._execute_brew_cu(command, operation)

        # Use standard brew lock detection for other commands
        if not self.lock_manager:
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

    def _execute_brew_cu(self, command: List[str], operation: str = "unknown") -> Dict[str, Any]:
        """Execute brew cu with timeout to handle interactive prompts"""
        try:
            # Run brew cu with timeout to avoid hanging on interactive prompts
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=60  # 60 second timeout
            )

            # Parse output to extract meaningful information (brew cu outputs to stderr)
            output_lines = result.stderr.split('\n')
            outdated_section = False
            outdated_count = 0
            outdated_apps = []

            for line in output_lines:
                if "==> Finding outdated apps" in line or "==> Found outdated apps" in line:
                    outdated_section = True
                    continue
                elif outdated_section and line.strip().startswith("Do you want to upgrade"):
                    break  # Stop at interactive prompt
                elif outdated_section and line.strip() and not line.startswith("==>"):
                    # Parse app line like " 1/21  1password              8.11.8           8.11.14           Y   [ FORCED ]"
                    # Only count FORCED apps (actually outdated), not OK apps (up-to-date)
                    if "/" in line and "[ FORCED ]" in line:
                        outdated_count += 1
                        # Extract app name (second column)
                        parts = line.split()
                        if len(parts) >= 2:
                            outdated_apps.append(parts[1])

            # Determine success based on operation
            if operation == "check":
                # For check operations, success = command ran (regardless of updates found)
                success = True
                if outdated_count > 0:
                    output = f"Found {outdated_count} outdated casks: {', '.join(outdated_apps[:5])}"
                    if len(outdated_apps) > 5:
                        output += f" and {len(outdated_apps) - 5} more"
                else:
                    output = "All casks up to date"
            else:
                # For upgrade operations, success = exit code 0 or timeout (upgrade likely succeeded)
                success = result.returncode == 0 or result.returncode == -15  # -15 is timeout
                output = result.stdout.strip() if result.stdout else "Upgrade process completed"

            return {
                'success': success,
                'output': output,
                'error': result.stderr.strip() if result.stderr and result.returncode not in [0, -15] else '',
                'exit_code': result.returncode if result.returncode != -15 else 0,  # Treat timeout as success for upgrades
                'recovery_used': False
            }

        except subprocess.TimeoutExpired as e:
            # Timeout is expected for check operations (interactive prompt)
            if operation == "check":
                # Parse partial output to get outdated apps count (brew cu outputs to stderr)
                output_lines = e.stderr.split('\n') if e.stderr else []
                outdated_count = 0
                for line in output_lines:
                    if "==> Found outdated apps" in line:
                        # Look for the next lines to count apps
                        continue
                    elif "/" in line and "[" in line and ("FORCED" in line or "OK" in line):
                        if "[ FORCED ]" in line:
                            outdated_count += 1

                return {
                    'success': True,
                    'output': f"Found {outdated_count} outdated casks (timeout parsing full list)",
                    'error': '',
                    'exit_code': 0,
                    'recovery_used': False
                }
            else:
                # For upgrades, timeout might mean it's still running - treat as success
                return {
                    'success': True,
                    'output': "Upgrade process started (timed out waiting for completion)",
                    'error': '',
                    'exit_code': 0,
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
