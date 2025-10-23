#!/usr/bin/env python3
"""Package Manager Registry

Central registry of all available package managers.
"""

from typing import Dict
from pm_base import PackageManager
from pms import (
    AptPM, BrewPM, BrewCaskPM, MasPM, NpmPM, PipPM, PipxPM, CargoPM, GemPM,
    ZinitPM, EmacsPM, NeovimPM,
    PacmanPM, ChocoPM, WingetPM, ScoopPM,
    FakePM1, FakePM2, FakeSudoPM
)


# Registry of PM instances
PM_REGISTRY: Dict[str, PackageManager] = {
    'apt': AptPM(),
    'brew': BrewPM(),
    'brew-cask': BrewCaskPM(),
    'mas': MasPM(),
    'npm': NpmPM(),
    'pip': PipPM(),
    'pipx': PipxPM(),
    'cargo': CargoPM(),
    'gem': GemPM(),
    'zinit': ZinitPM(),
    'emacs': EmacsPM(),
    'neovim': NeovimPM(),
    'pacman': PacmanPM(),
    'choco': ChocoPM(),
    'winget': WingetPM(),
    'scoop': ScoopPM(),
    'fake-pm1': FakePM1(),
    'fake-pm2': FakePM2(),
    'fake-sudo-pm': FakeSudoPM(),
}


def get_pm(name: str) -> PackageManager:
    """
    Get package manager instance by name.

    Args:
        name: Package manager name

    Returns:
        PackageManager instance

    Raises:
        KeyError: If PM not found in registry
    """
    if name not in PM_REGISTRY:
        raise KeyError(f"Package manager '{name}' not registered")
    return PM_REGISTRY[name]
