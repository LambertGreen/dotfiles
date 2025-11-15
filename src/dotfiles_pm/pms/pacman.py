#!/usr/bin/env python3
"""Pacman Package Manager (MSYS2/Arch Linux)"""

from typing import List, Optional
import sys
import os
import platform
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class PacmanPM(PackageManager):
    """Pacman package manager (MSYS2/Arch)"""

    def __init__(self):
        super().__init__('pacman')
        self._msys2_root: Optional[str] = None

    def _get_msys2_root(self) -> str:
        """
        Detect MSYS2 root directory from environment or common locations.

        Checks in order:
        1. MSYS2_ROOT environment variable (set by bootstrap)
        2. C:/msys64 (default install location)
        3. C:/tools/msys64 (chocolatey install location)
        """
        if self._msys2_root:
            return self._msys2_root

        # Check environment variable first
        if env_root := os.environ.get('MSYS2_ROOT'):
            self._msys2_root = env_root.replace('\\', '/')
            return self._msys2_root

        # Check common locations
        common_locations = ['C:/msys64', 'C:/tools/msys64']
        for location in common_locations:
            pacman_path = Path(location) / 'usr' / 'bin' / 'pacman.exe'
            if pacman_path.exists():
                self._msys2_root = location
                return self._msys2_root

        # Fallback to default
        self._msys2_root = 'C:/msys64'
        return self._msys2_root

    def _get_pacman_exe(self) -> str:
        """Get platform-specific pacman executable path"""
        # If we're already in MSYS2 (cygwin platform with MSYSTEM set), use 'pacman' directly
        # It's in PATH and will work correctly in spawned terminals
        if sys.platform == 'cygwin' and os.environ.get('MSYSTEM'):
            return 'pacman'
        # On native Windows (win32) without MSYS2, use full path
        if sys.platform == 'win32':
            root = self._get_msys2_root()
            return f'{root}/usr/bin/pacman.exe'
        # Native Linux/Arch
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
            root = self._get_msys2_root()
            return [f'{root}/msys2_shell.cmd', '-defterm', '-no-start', '-c', pacman_args]
        # On native Linux/Arch, run pacman directly
        return pacman_args.split()

    @property
    def check_command(self) -> List[str]:
        # On Windows (including when Python runs from MSYS2), always wrap with msys2_shell.cmd
        # because spawned terminals (PowerShell) don't have pacman in PATH
        if sys.platform in ('win32', 'cygwin'):
            return self._wrap_for_windows('pacman -Qu')
        # Native Linux/Arch - run directly
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
