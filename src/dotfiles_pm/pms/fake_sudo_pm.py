#!/usr/bin/env python3
"""Fake Sudo-Requiring Package Manager (for testing)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class FakeSudoPM(PackageManager):
    """Fake sudo-requiring package manager for testing"""

    def __init__(self):
        super().__init__('fake-sudo-pm')

    @property
    def check_command(self) -> List[str]:
        return ["sh", "-c", "sleep 2 && echo \"fake-sudo-pm: 7 packages outdated\""]

    @property
    def upgrade_command(self) -> List[str]:
        return ["sh", "-c", "sleep 2 && echo \"fake-sudo-pm: upgraded\""]

    @property
    def install_command(self) -> List[str]:
        return ["sh", "-c", "sleep 2 && echo \"fake-sudo-pm: installed\""]

    @property
    def requires_sudo(self) -> bool:
        return True

    @property
    def priority(self) -> int:
        return 0
