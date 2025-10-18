#!/usr/bin/env python3
"""Pipx Package Manager (Python applications)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class PipxPM(PackageManager):
    """Pipx package manager (Python applications)"""

    def __init__(self):
        super().__init__('pipx')

    @property
    def check_command(self) -> List[str]:
        return ["pipx", "list", "--short"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["pipx", "upgrade-all"]

    @property
    def install_command(self) -> List[str]:
        return ["pipx", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
