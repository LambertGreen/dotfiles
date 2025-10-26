#!/usr/bin/env python3
"""Pacman Package Manager (MSYS2/Arch Linux)"""

from typing import List
import sys
import platform
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class PacmanPM(PackageManager):
    """Pacman package manager (MSYS2/Arch)"""

    def __init__(self):
        super().__init__('pacman')

    def _get_pacman_exe(self) -> str:
        """Get platform-specific pacman executable path"""
        # On Windows (including MSYS2/Cygwin), use full path with forward slashes
        # Forward slashes work in subprocess from MSYS2 Python, backslashes get mangled
        if sys.platform in ('win32', 'cygwin'):
            return 'C:/msys64/usr/bin/pacman.exe'
        return 'pacman'

    @property
    def check_command(self) -> List[str]:
        return [self._get_pacman_exe(), "-Qu"]

    @property
    def upgrade_command(self) -> List[str]:
        return [self._get_pacman_exe(), "-Syu"]

    @property
    def install_command(self) -> List[str]:
        return [self._get_pacman_exe(), "-S", "--needed"]

    @property
    def requires_sudo(self) -> bool:
        return False  # MSYS2 doesn't use sudo

    @property
    def priority(self) -> int:
        return 0
