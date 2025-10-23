#!/usr/bin/env python3
"""Chocolatey Package Manager (Windows)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class ChocoPM(PackageManager):
    """Chocolatey package manager (Windows)"""

    def __init__(self):
        super().__init__('choco')

    @property
    def check_command(self) -> List[str]:
        return ["choco", "outdated"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["choco", "upgrade", "all", "-y"]

    @property
    def install_command(self) -> List[str]:
        return ["choco", "install", "-y"]

    @property
    def requires_sudo(self) -> bool:
        return True  # Choco usually requires admin

    @property
    def priority(self) -> int:
        return 0
