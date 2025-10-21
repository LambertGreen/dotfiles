#!/usr/bin/env python3
"""Package Manager Implementations"""

from .apt import AptPM
from .brew import BrewPM
from .brew_cask import BrewCaskPM
from .mas import MasPM
from .npm import NpmPM
from .pip import PipPM
from .pipx import PipxPM
from .cargo import CargoPM
from .gem import GemPM
from .zinit import ZinitPM
from .emacs import EmacsPM
from .neovim import NeovimPM
from .fake_pm1 import FakePM1
from .fake_pm2 import FakePM2
from .fake_sudo_pm import FakeSudoPM

__all__ = [
    'AptPM',
    'BrewPM',
    'BrewCaskPM',
    'MasPM',
    'NpmPM',
    'PipPM',
    'PipxPM',
    'CargoPM',
    'GemPM',
    'ZinitPM',
    'EmacsPM',
    'NeovimPM',
    'FakePM1',
    'FakePM2',
    'FakeSudoPM',
]
