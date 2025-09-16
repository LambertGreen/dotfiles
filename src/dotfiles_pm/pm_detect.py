#!/usr/bin/env python3
"""
Package Manager Detection Module

Simple, cross-platform detection of available package managers.
No categories, no metadata - just aggregation.
"""

import os
import shutil
from pathlib import Path
from typing import List


def detect_all_pms() -> List[str]:
    """
    Detect all available package managers on the system.

    Respects environment variables:
    - DOTFILES_PM_ONLY_FAKES: Only return fake PMs (for testing)
    - DOTFILES_PM_DISABLE_REAL: Disable all real PMs (for CI)
    - DOTFILES_PM_DISABLED: Comma-separated list of PMs to disable
    - DOTFILES_PM_ENABLED: Comma-separated list of PMs to enable (overrides disabled)

    Returns:
        List of package manager names that are available
    """
    pms = []

    # Check environment settings
    only_fakes = os.environ.get('DOTFILES_PM_ONLY_FAKES', '').lower() == 'true'
    disable_real = os.environ.get('DOTFILES_PM_DISABLE_REAL', '').lower() == 'true'

    # Get disabled/enabled lists from environment
    # Support both new (DOTFILES_PM_*) and legacy (DOTFILES_PACKAGE_MANAGERS*) variables
    disabled_pms = set()
    if disabled_str := os.environ.get('DOTFILES_PM_DISABLED', ''):
        disabled_pms = set(pm.strip() for pm in disabled_str.split(',') if pm.strip())

    enabled_pms = set()
    if enabled_str := os.environ.get('DOTFILES_PM_ENABLED', ''):
        enabled_pms = set(pm.strip() for pm in enabled_str.split(',') if pm.strip())

    # Helper to check if PM should be included
    def should_include(pm_name: str, is_fake: bool = False) -> bool:
        # If only_fakes mode, only include fake PMs
        if only_fakes:
            return is_fake
        # If disable_real mode, exclude real PMs
        if disable_real and not is_fake:
            return False
        # Check explicit enable/disable lists
        if pm_name in enabled_pms:
            return True
        if pm_name in disabled_pms:
            return False
        return True

    # System package managers
    if shutil.which('brew') and should_include('brew'):
        pms.append('brew')
    if shutil.which('apt') and should_include('apt'):
        pms.append('apt')
    if shutil.which('pacman') and should_include('pacman'):
        pms.append('pacman')
    if shutil.which('dnf') and should_include('dnf'):
        pms.append('dnf')
    if shutil.which('zypper') and should_include('zypper'):
        pms.append('zypper')
    if shutil.which('choco') and should_include('choco'):
        pms.append('choco')
    if shutil.which('winget') and should_include('winget'):
        pms.append('winget')
    if shutil.which('scoop') and should_include('scoop'):
        pms.append('scoop')

    # Dev package managers
    if shutil.which('npm') and should_include('npm'):
        pms.append('npm')
    if shutil.which('pip3') and should_include('pip'):
        pms.append('pip')
    if shutil.which('pipx') and should_include('pipx'):
        pms.append('pipx')
    if shutil.which('cargo') and should_include('cargo'):
        pms.append('cargo')
    if shutil.which('gem') and should_include('gem'):
        pms.append('gem')

    # Directory-based package managers
    home = Path.home()
    if (home / '.emacs.d').exists() and should_include('emacs'):
        pms.append('emacs')
    if (home / '.zinit').exists() and should_include('zinit'):
        pms.append('zinit')

    # Editor package managers
    if shutil.which('nvim') and should_include('neovim'):
        pms.append('neovim')

    # Fake PMs for testing
    if shutil.which('fake-pm1') and should_include('fake-pm1', is_fake=True):
        pms.append('fake-pm1')
    if shutil.which('fake-pm2') and should_include('fake-pm2', is_fake=True):
        pms.append('fake-pm2')
    if shutil.which('fake-unattended') and should_include('fake-unattended', is_fake=True):
        pms.append('fake-unattended')
    if shutil.which('fake-attended') and should_include('fake-attended', is_fake=True):
        pms.append('fake-attended')

    return pms


def main():
    """CLI entry point for PM detection."""
    pms = detect_all_pms()

    if not pms:
        print("No package managers detected")
        return

    print("📋 Available Package Managers")
    print("============================")
    print()

    for pm in pms:
        print(f"✅ {pm}")

    print()
    print(f"📊 Summary: {len(pms)} package managers detected")


if __name__ == '__main__':
    main()
