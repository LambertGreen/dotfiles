#!/usr/bin/env python3
"""Scoop Package Manager (Windows)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class ScoopPM(PackageManager):
    """Scoop package manager (Windows)"""

    def __init__(self):
        super().__init__('scoop')

    @property
    def check_command(self) -> List[str]:
        return ["scoop", "status"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["scoop", "update", "*"]

    @property
    def install_command(self) -> List[str]:
        return ["scoop", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 0
