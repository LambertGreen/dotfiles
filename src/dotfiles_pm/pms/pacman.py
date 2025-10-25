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

    def _wrap_for_windows(self, pacman_args: str) -> List[str]:
        """
        Wrap pacman command for Windows PowerShell execution via msys2_shell.cmd

        Following chocolatey's msys2 package pattern:
        https://github.com/chocolatey-community/chocolatey-packages/tree/master/automatic/msys2

        msys2_shell.cmd invokes MSYS2 bash environment to run pacman properly.
        """
        if sys.platform in ('win32', 'cygwin'):
            # Use msys2_shell.cmd to invoke pacman in proper MSYS2 environment
            return ['C:/msys64/msys2_shell.cmd', '-defterm', '-no-start', '-c', pacman_args]
        # On native Linux/Arch, run pacman directly
        return pacman_args.split()

    @property
    def check_command(self) -> List[str]:
        if sys.platform in ('win32', 'cygwin'):
            return self._wrap_for_windows('pacman -Qu')
        return [self._get_pacman_exe(), "-Qu"]

    @property
    def upgrade_command(self) -> List[str]:
        if sys.platform in ('win32', 'cygwin'):
            return self._wrap_for_windows('pacman --noconfirm -Syu')
        return [self._get_pacman_exe(), "-Syu"]

    @property
    def install_command(self) -> List[str]:
        if sys.platform in ('win32', 'cygwin'):
            return self._wrap_for_windows('pacman --noconfirm -S --needed')
        return [self._get_pacman_exe(), "-S", "--needed"]

    @property
    def requires_sudo(self) -> bool:
        return False  # MSYS2 doesn't use sudo

    @property
    def priority(self) -> int:
        return 0
