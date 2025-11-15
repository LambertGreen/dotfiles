#!/usr/bin/env python3
"""
Package Manager Detection Module

Simple, cross-platform detection of available package managers.
No categories, no metadata - just aggregation.
"""

import os
import shutil
from pathlib import Path
from typing import List, Optional, Set


def get_machine_class_pms() -> Optional[Set[str]]:
    """
    Get the set of package managers configured for the current machine class.
    
    Returns:
        Set of PM names configured for the machine class, or None if no machine class is set
    """
    machine_class = os.environ.get('DOTFILES_MACHINE_CLASS')
    if not machine_class:
        # Try to load from .dotfiles.env
        env_file = Path.home() / '.dotfiles.env'
        if env_file.exists():
            with open(env_file) as f:
                for line in f:
                    if line.startswith('export DOTFILES_MACHINE_CLASS='):
                        machine_class = line.split('=')[1].strip().strip('"')
                        break
    
    if not machine_class:
        return None
    
    # Find dotfiles root (go up from src/dotfiles_pm to root)
    dotfiles_root = Path(__file__).parent.parent.parent
    machine_class_dir = dotfiles_root / 'machine-classes' / machine_class
    
    if not machine_class_dir.exists():
        return None
    
    # Get all directories in machine class (each is a PM name)
    configured_pms = set()
    for item in machine_class_dir.iterdir():
        if item.is_dir() and item.name not in ('stow', 'win-reg'):
            # These are special directories, not PM names
            configured_pms.add(item.name)
    
    return configured_pms if configured_pms else None


def get_machine_class_name() -> Optional[str]:
    """
    Get the current machine class name.
    
    Returns:
        Machine class name or None if not set
    """
    machine_class = os.environ.get('DOTFILES_MACHINE_CLASS')
    if not machine_class:
        # Try to load from .dotfiles.env
        env_file = Path.home() / '.dotfiles.env'
        if env_file.exists():
            with open(env_file) as f:
                for line in f:
                    if line.startswith('export DOTFILES_MACHINE_CLASS='):
                        machine_class = line.split('=')[1].strip().strip('"')
                        break
    return machine_class


def detect_all_pms(operation: str = 'check') -> List[str]:
    """
    Detect available package managers on the system for a specific operation.

    Args:
        operation: Operation context ('install', 'check', 'upgrade')
                  - 'install': Only PMs that handle installation (brew handles all install)
                  - 'check'/'upgrade': All PMs for granular update operations

    Respects environment variables:
    - DOTFILES_PM_ONLY_FAKES: Only return fake PMs (for testing)
    - DOTFILES_PM_DISABLE_REAL: Disable all real PMs (for CI)
    - DOTFILES_PM_DISABLED: Comma-separated list of PMs to disable
    - DOTFILES_PM_ENABLED: Comma-separated list of PMs to enable (overrides disabled)

    Returns:
        List of package manager names that are available for the operation
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

    # Define system directories to exclude (platform-specific)
    # These are directories with OS-provided binaries that we shouldn't manage
    import platform
    system_dirs = set()
    if platform.system() == 'Darwin':  # macOS
        system_dirs = {'/usr/bin', '/bin', '/System'}
    elif platform.system() == 'Linux':
        system_dirs = {'/usr/bin', '/bin'}  # Not /usr/local/bin - that's for user installs
    elif platform.system() == 'Windows':
        system_dirs = {'C:\\Windows\\System32', 'C:\\Windows'}

    def is_system_binary(binary_path: str) -> bool:
        """Check if a binary is a system binary that shouldn't be managed."""
        if not binary_path:
            return False
        return any(binary_path.startswith(sys_dir) for sys_dir in system_dirs)

    # Helper to check if PM should be included
    def should_include(pm_name: str, is_fake: bool = False) -> bool:
        # If only_fakes mode, only include fake PMs
        if only_fakes:
            return is_fake
        # If disable_real mode, exclude real PMs
        if disable_real and not is_fake:
            return False
        # Fake PMs must be explicitly enabled
        if is_fake:
            return pm_name in enabled_pms
        # Disabled list takes precedence - always exclude disabled PMs
        if pm_name in disabled_pms:
            return False
        # If enabled_pms is set, only include PMs that are explicitly enabled
        if enabled_pms:
            return pm_name in enabled_pms
        # Default: include all PMs
        return True

    # System package managers
    if shutil.which('brew') and should_include('brew'):
        pms.append('brew')

    # For install operations, brew handles all package types via brew bundle
    # For check/upgrade operations, use separate PMs for granular control
    if operation in ['check', 'upgrade']:
        # brew-cask is macOS-only (casks don't exist on Linuxbrew)
        if shutil.which('brew') and platform.system() == 'Darwin' and should_include('brew-cask'):
            pms.append('brew-cask')
        if shutil.which('mas') and should_include('mas'):
            pms.append('mas')
    if shutil.which('apt') and should_include('apt'):
        pms.append('apt')
    if shutil.which('pacman') and should_include('pacman'):
        pms.append('pacman')
    if shutil.which('dnf') and should_include('dnf'):
        pms.append('dnf')
    if shutil.which('zypper') and should_include('zypper'):
        pms.append('zypper')
    # Windows PMs: scoop must come before choco (scoop installs 'sudo' package for choco)
    if shutil.which('scoop') and should_include('scoop'):
        pms.append('scoop')
    if shutil.which('choco') and should_include('choco'):
        pms.append('choco')
    if shutil.which('winget') and should_include('winget'):
        pms.append('winget')

    # Dev package managers (exclude system versions)
    npm_path = shutil.which('npm')
    if npm_path and not is_system_binary(npm_path) and should_include('npm'):
        pms.append('npm')

    # pip3 is now externally-managed (PEP 668) and should not be used for system packages
    # Use pipx for applications instead
    # pip3_path = shutil.which('pip3')
    # if pip3_path and not is_system_binary(pip3_path) and should_include('pip'):
    #     pms.append('pip')

    pipx_path = shutil.which('pipx')
    if pipx_path and not is_system_binary(pipx_path) and should_include('pipx'):
        pms.append('pipx')

    cargo_path = shutil.which('cargo')
    if cargo_path and not is_system_binary(cargo_path) and should_include('cargo'):
        pms.append('cargo')

    gem_path = shutil.which('gem')
    if gem_path and not is_system_binary(gem_path) and should_include('gem'):
        pms.append('gem')

    # Editor package managers - their configs are in stowed dotfiles
    # Directory-based package managers
    home = Path.home()
    if (home / '.emacs.d').exists() and should_include('emacs'):
        pms.append('emacs')
    if (home / '.zinit').exists() and should_include('zinit'):
        pms.append('zinit')
    if shutil.which('nvim') and should_include('neovim'):
        pms.append('neovim')

    # Fake PMs for testing - enabled via DOTFILES_PM_ENABLED
    # These don't require binaries to exist; they use simple shell commands
    if should_include('fake-pm1', is_fake=True):
        pms.append('fake-pm1')
    if should_include('fake-pm2', is_fake=True):
        pms.append('fake-pm2')
    if should_include('fake-sudo-pm', is_fake=True):
        pms.append('fake-sudo-pm')

    # Filter by machine class if configured
    # Only include PMs that are configured for the current machine class
    machine_class_pms = get_machine_class_pms()
    machine_class_name = get_machine_class_name()
    
    if machine_class_pms is not None:
        # Check for missing PMs (configured but not detected)
        missing_pms = machine_class_pms - set(pms)
        if missing_pms:
            import sys
            print(f"\n⚠️  WARNING: Package managers configured for machine class '{machine_class_name}' but not detected:", file=sys.stderr)
            for pm in sorted(missing_pms):
                print(f"   • {pm} - not available on this system", file=sys.stderr)
            print("", file=sys.stderr)
            print("   This may indicate:", file=sys.stderr)
            print("   - Package manager not installed", file=sys.stderr)
            print("   - Package manager not in PATH", file=sys.stderr)
            print("   - Machine class configuration mismatch", file=sys.stderr)
            print("", file=sys.stderr)
            print("   To fix:", file=sys.stderr)
            print("   - Install missing package managers", file=sys.stderr)
            print("   - Ensure they are in your PATH", file=sys.stderr)
            print("   - Or update machine class configuration if incorrect", file=sys.stderr)
            print("", file=sys.stderr)
        
        # Filter to only include PMs configured for this machine class
        # This ensures we only use PMs that are actually defined in the machine class
        filtered_pms = [pm for pm in pms if pm in machine_class_pms]
        if filtered_pms:
            pms = filtered_pms
        # If machine class is set but no PMs match, that's a configuration issue
        # but we'll still return empty list rather than all detected PMs

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
