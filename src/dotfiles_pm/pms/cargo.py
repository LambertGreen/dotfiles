#!/usr/bin/env python3
"""Cargo Package Manager (Rust)"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class CargoPM(PackageManager):
    """Cargo package manager (Rust)"""

    def __init__(self):
        super().__init__('cargo')

    @property
    def check_command(self) -> List[str]:
        return ["cargo", "install-update", "--list"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["cargo", "install-update", "-a"]

    @property
    def install_command(self) -> List[str]:
        return ["cargo", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
