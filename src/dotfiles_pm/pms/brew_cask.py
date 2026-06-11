#!/usr/bin/env python3
"""Homebrew Cask Package Manager (macOS GUI Apps)"""

from typing import List, Dict, Any
import sys
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager, PMParser


class BrewCaskParser(PMParser):
    """Parser for brew outdated --cask --greedy output (one package per line)"""

    def count_outdated(self, output: str) -> int:
        if not output:
            return 0
        return len([line for line in output.strip().split('\n') if line.strip()])


class BrewCaskPM(PackageManager):
    """Homebrew cask package manager for macOS GUI applications"""

    def __init__(self):
        super().__init__('brew-cask')
        self._parser = BrewCaskParser()
        try:
            from .brew_utils import brew_lock_manager
            self.lock_manager = brew_lock_manager
        except ImportError:
            self.lock_manager = None

    @property
    def check_command(self) -> List[str]:
        return ["brew", "outdated", "--cask", "--greedy"]

    @property
    def upgrade_command(self) -> List[str]:
        from ..sudo_helper import wrap_command_with_askpass, get_sudo_mode
        mode = get_sudo_mode()
        if mode == 'gui':
            wrapped = wrap_command_with_askpass("brew upgrade --cask --greedy")
            return ["bash", "-c", wrapped]
        return ["brew", "upgrade", "--cask", "--greedy"]

    @property
    def install_command(self) -> List[str]:
        return ["brew", "install", "--cask"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 12

    def execute_command(self, command: List[str], operation: str = "unknown") -> Dict[str, Any]:
        if self.lock_manager:
            try:
                result = self.lock_manager.execute_with_lock_detection(command)
                return {
                    'success': result.returncode == 0,
                    'output': result.stdout.strip(),
                    'error': result.stderr.strip() if result.returncode != 0 else '',
                    'exit_code': result.returncode,
                    'recovery_used': False
                }
            except Exception as e:
                from .brew_utils import BrewLockError
                if isinstance(e, BrewLockError):
                    raise SystemExit(41)
                raise

        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=600
        )
        return {
            'success': result.returncode == 0,
            'output': result.stdout.strip(),
            'error': result.stderr.strip() if result.returncode != 0 else '',
            'exit_code': result.returncode,
            'recovery_used': False
        }
