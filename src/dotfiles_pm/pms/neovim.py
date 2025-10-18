#!/usr/bin/env python3
"""Neovim Package Manager"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class NeovimPM(PackageManager):
    """Neovim package manager"""

    def __init__(self):
        super().__init__('neovim')

    @property
    def check_command(self) -> List[str]:
        return ["nvim", "--headless", "-c", "Lazy check", "-c", "qa"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["nvim", "--headless", "-c", "Lazy sync", "-c", "qa"]

    @property
    def install_command(self) -> List[str]:
        return ["nvim", "--headless", "-c", "Lazy install", "-c", "qa"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
