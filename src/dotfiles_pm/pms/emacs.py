#!/usr/bin/env python3
"""Emacs Package Manager"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class EmacsPM(PackageManager):
    """Emacs package manager"""

    def __init__(self):
        super().__init__('emacs')

    @property
    def check_command(self) -> List[str]:
        return ["env", "DOTFILES_EMACS_CHECK=1", "emacs", "--batch", "-l", "~/.emacs.d/init.el"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["env", "DOTFILES_EMACS_UPDATE=1", "emacs", "--batch", "-l", "~/.emacs.d/init.el"]

    @property
    def install_command(self) -> List[str]:
        return ["env", "DOTFILES_EMACS_INSTALL=1", "emacs", "--batch", "-l", "~/.emacs.d/init.el"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10
