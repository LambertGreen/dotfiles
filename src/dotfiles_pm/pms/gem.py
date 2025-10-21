#!/usr/bin/env python3
"""Gem Package Manager (Ruby)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class GemPM(PackageManager):
    """Gem package manager (Ruby)"""

    def __init__(self):
        super().__init__('gem')

    @property
    def check_command(self) -> List[str]:
        return ["gem", "outdated"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["gem", "update"]

    @property
    def install_command(self) -> List[str]:
        return ["gem", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
