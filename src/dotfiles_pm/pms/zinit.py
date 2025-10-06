#!/usr/bin/env python3
"""Zinit Package Manager (Zsh plugin manager)"""

from typing import List
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager, PMParser


class ZinitParser(PMParser):
    """Parser for zinit status output"""

    def count_outdated(self, output: str) -> int:
        if not output:
            return 0
        # Count occurrences of "Your branch is behind"
        return output.count('Your branch is behind')


class ZinitPM(PackageManager):
    """Zinit package manager (Zsh plugin manager)"""

    def __init__(self):
        super().__init__('zinit')
        self._parser = ZinitParser()

    @property
    def check_command(self) -> List[str]:
        return ["zsh -i -c 'zinit status --all'"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["zsh -i -c 'zinit self-update && zinit update --all'"]

    @property
    def install_command(self) -> List[str]:
        return ["zsh -i -c 'true'"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
