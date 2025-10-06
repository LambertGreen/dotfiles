#!/usr/bin/env python3
"""Homebrew Package Manager"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class BrewPM(PackageManager):
    """Homebrew package manager"""

    def __init__(self):
        super().__init__('brew')

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
