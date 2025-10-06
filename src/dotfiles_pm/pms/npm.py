#!/usr/bin/env python3
"""NPM Package Manager (Node.js)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class NpmPM(PackageManager):
    """NPM package manager (Node.js)"""

    def __init__(self):
        super().__init__('npm')

    @property
    def check_command(self) -> List[str]:
        return ["npm", "outdated", "-g"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["npm", "update", "-g"]

    @property
    def install_command(self) -> List[str]:
        return ["npm", "install", "-g"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
