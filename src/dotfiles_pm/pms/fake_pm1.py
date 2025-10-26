#!/usr/bin/env python3
"""Fake Package Manager 1 (for testing)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class FakePM1(PackageManager):
    """Fake package manager for testing"""

    def __init__(self):
        super().__init__('fake-pm1')

    @property
    def check_command(self) -> List[str]:
        return ["echo", "fake-pm1: 5 packages outdated"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["echo", "fake-pm1: upgrading packages..."]

    @property
    def install_command(self) -> List[str]:
        return ["echo", "fake-pm1: installing packages..."]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
