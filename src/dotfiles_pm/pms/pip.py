#!/usr/bin/env python3
"""Pip Package Manager (Python)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class PipPM(PackageManager):
    """Pip package manager (Python)"""

    def __init__(self):
        super().__init__('pip')

    @property
    def check_command(self) -> List[str]:
        return ["pip3", "list", "--outdated"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["pip3", "install", "--upgrade"]

    @property
    def install_command(self) -> List[str]:
        return ["pip3", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
