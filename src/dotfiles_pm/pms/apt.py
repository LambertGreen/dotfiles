#!/usr/bin/env python3
"""APT Package Manager (Debian/Ubuntu)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class AptPM(PackageManager):
    """APT package manager (Debian/Ubuntu)"""

    def __init__(self):
        super().__init__('apt')

    @property
    def check_command(self) -> List[str]:
        return ["sudo", "apt-get", "update", "&&", "sudo", "apt-get", "upgrade", "--dry-run"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["sudo", "apt-get", "upgrade"]

    @property
    def install_command(self) -> List[str]:
        return ["sudo", "apt-get", "install"]

    @property
    def requires_sudo(self) -> bool:
        return True

    @property
    def priority(self) -> int:
        return 0
