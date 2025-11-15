#!/usr/bin/env python3
"""Winget Package Manager (Windows)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class WingetPM(PackageManager):
    """Winget package manager (Windows)"""

    def __init__(self):
        super().__init__('winget')

    @property
    def check_command(self) -> List[str]:
        return ["winget", "upgrade"]  # No --list flag, just 'upgrade' lists outdated packages

    @property
    def upgrade_command(self) -> List[str]:
        return ["winget", "upgrade", "--all"]

    @property
    def install_command(self) -> List[str]:
        return ["winget", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10  # Run last - only catches packages scoop/choco don't manage
