#!/usr/bin/env python3
"""Mac App Store Package Manager"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class MasPM(PackageManager):
    """Mac App Store package manager"""

    def __init__(self):
        super().__init__('mas')

    @property
    def check_command(self) -> List[str]:
        return ["mas", "outdated"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["mas", "upgrade"]

    @property
    def install_command(self) -> List[str]:
        return ["mas", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 15  # Higher priority than npm/pip (system apps are important for security)
