#!/usr/bin/env python3
"""Chocolatey Package Manager (Windows)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager
from sudo_helper import get_windows_elevation_command


class ChocoPM(PackageManager):
    """Chocolatey package manager (Windows)"""

    def __init__(self):
        super().__init__('choco')

    @property
    def check_command(self) -> List[str]:
        return ["choco", "outdated"]  # Read-only, doesn't need elevation

    @property
    def upgrade_command(self) -> List[str]:
        # Elevate via gsudo (falls back to native sudo). Native Windows `sudo` is
        # often disabled by org policy, so we resolve the binary at runtime.
        return get_windows_elevation_command(["choco", "upgrade", "all", "-y"])

    @property
    def install_command(self) -> List[str]:
        # Elevate via gsudo (falls back to native sudo) — see upgrade_command.
        return get_windows_elevation_command(["choco", "install", "-y"])

    @property
    def requires_sudo(self) -> bool:
        return True  # Choco usually requires admin

    @property
    def priority(self) -> int:
        return 5  # Run after scoop (0) but before winget (10)
