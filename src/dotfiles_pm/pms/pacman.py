#!/usr/bin/env python3
"""Pacman Package Manager (MSYS2/Arch Linux)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class PacmanPM(PackageManager):
    """Pacman package manager (MSYS2/Arch)"""

    def __init__(self):
        super().__init__('pacman')

    @property
    def check_command(self) -> List[str]:
        return ["pacman", "-Qu"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["pacman", "-Syu"]

    @property
    def install_command(self) -> List[str]:
        return ["pacman", "-S", "--needed"]

    @property
    def requires_sudo(self) -> bool:
        return False  # MSYS2 doesn't use sudo

    @property
    def priority(self) -> int:
        return 0
