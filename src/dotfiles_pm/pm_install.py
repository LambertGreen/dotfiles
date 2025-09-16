#!/usr/bin/env python3
"""
Package Manager Install Module

Install packages across multiple package managers using native package files.
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional

from .pm_detect import detect_all_pms
from .pm_select import select_pms


def get_machine_config_dir(pm_name: str) -> Optional[Path]:
    """
    Get the configuration directory for a package manager based on machine class.

    Args:
        pm_name: Name of the package manager

    Returns:
        Path to the PM's config directory or None if not found
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
    config_dir = dotfiles_root / 'machine-classes' / machine_class / pm_name

    if config_dir.exists():
        return config_dir
    return None


def install_brew_packages(level: str = 'all') -> Dict[str, Any]:
    """
    Install Homebrew packages from Brewfile format.

    Args:
        level: 'user', 'admin', or 'all'

    Returns:
        Dict with installation results
    """
    result = {
        'pm': 'brew',
        'success': False,
        'output': '',
        'error': '',
        'installed_count': 0
    }

    config_dir = get_machine_config_dir('brew')
    if not config_dir:
        result['error'] = 'No configuration found for brew'
        return result

    levels_to_install = []
    if level == 'all':
        levels_to_install = ['admin', 'user']
    else:
        levels_to_install = [level]

    total_installed = 0
    for install_level in levels_to_install:
        package_file = config_dir / f'packages.{install_level}'

        if not package_file.exists():
            continue

        print(f"  📦 Installing {install_level}-level packages from: {package_file.name}")

        try:
            # Use brew bundle to install
            cmd = ['brew', 'bundle', 'install', f'--file={package_file}', '--no-upgrade']

            if install_level == 'admin':
                print(f"  ⚠️  Admin packages may require password")

            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=600  # 10 minutes for installations
            )

            if proc.returncode == 0:
                # Count installed packages (rough estimate)
                lines = proc.stdout.strip().split('\n') if proc.stdout else []
                installed = len([l for l in lines if 'Installing' in l or 'Installed' in l])
                total_installed += installed
                result['output'] += f"\n{install_level}: {proc.stdout}"
            else:
                result['error'] += f"\n{install_level}: {proc.stderr}"

        except subprocess.TimeoutExpired:
            result['error'] += f"\n{install_level}: Installation timed out"
        except Exception as e:
            result['error'] += f"\n{install_level}: {str(e)}"

    result['installed_count'] = total_installed
    result['success'] = total_installed > 0 or not result['error']
    return result


def install_apt_packages() -> Dict[str, Any]:
    """
    Install APT packages from packages.txt file.

    Returns:
        Dict with installation results
    """
    result = {
        'pm': 'apt',
        'success': False,
        'output': '',
        'error': '',
        'installed_count': 0
    }

    config_dir = get_machine_config_dir('apt')
    if not config_dir:
        result['error'] = 'No configuration found for apt'
        return result

    package_file = config_dir / 'packages.txt'
    if not package_file.exists():
        result['error'] = f'Package file not found: {package_file}'
        return result

    # Read packages
    with open(package_file) as f:
        packages = [line.strip() for line in f if line.strip() and not line.startswith('#')]

    if not packages:
        result['output'] = 'No packages to install'
        result['success'] = True
        return result

    try:
        # Update package lists first
        print(f"  📦 Updating package lists...")
        subprocess.run(['sudo', 'apt-get', 'update'], check=False)

        # Install packages
        print(f"  📦 Installing {len(packages)} packages...")
        cmd = ['sudo', 'apt-get', 'install', '-y'] + packages

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600
        )

        result['output'] = proc.stdout
        result['error'] = proc.stderr
        result['success'] = proc.returncode == 0
        result['installed_count'] = len(packages) if proc.returncode == 0 else 0

    except subprocess.TimeoutExpired:
        result['error'] = 'Installation timed out'
    except Exception as e:
        result['error'] = str(e)

    return result


def install_npm_packages() -> Dict[str, Any]:
    """
    Install npm packages from packages.txt file.

    Returns:
        Dict with installation results
    """
    result = {
        'pm': 'npm',
        'success': False,
        'output': '',
        'error': '',
        'installed_count': 0
    }

    config_dir = get_machine_config_dir('npm')
    if not config_dir:
        result['error'] = 'No configuration found for npm'
        return result

    package_file = config_dir / 'packages.txt'
    if not package_file.exists():
        result['error'] = f'Package file not found: {package_file}'
        return result

    # Read packages
    with open(package_file) as f:
        packages = [line.strip() for line in f if line.strip() and not line.startswith('#')]

    if not packages:
        result['output'] = 'No packages to install'
        result['success'] = True
        return result

    try:
        print(f"  📦 Installing {len(packages)} npm packages globally...")
        cmd = ['npm', 'install', '-g'] + packages

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300
        )

        result['output'] = proc.stdout
        result['error'] = proc.stderr
        result['success'] = proc.returncode == 0
        result['installed_count'] = len(packages) if proc.returncode == 0 else 0

    except subprocess.TimeoutExpired:
        result['error'] = 'Installation timed out'
    except Exception as e:
        result['error'] = str(e)

    return result


def install_pip_packages() -> Dict[str, Any]:
    """
    Install pip packages from requirements.txt file.

    Returns:
        Dict with installation results
    """
    result = {
        'pm': 'pip',
        'success': False,
        'output': '',
        'error': '',
        'installed_count': 0
    }

    config_dir = get_machine_config_dir('pip')
    if not config_dir:
        result['error'] = 'No configuration found for pip'
        return result

    package_file = config_dir / 'requirements.txt'
    if not package_file.exists():
        result['error'] = f'Package file not found: {package_file}'
        return result

    try:
        print(f"  📦 Installing pip packages from requirements.txt...")
        cmd = ['pip3', 'install', '-r', str(package_file)]

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300
        )

        result['output'] = proc.stdout
        result['error'] = proc.stderr
        result['success'] = proc.returncode == 0

        # Count installed packages from output
        if proc.returncode == 0:
            installed = proc.stdout.count('Successfully installed')
            result['installed_count'] = installed

    except subprocess.TimeoutExpired:
        result['error'] = 'Installation timed out'
    except Exception as e:
        result['error'] = str(e)

    return result


def install_packages_for_pm(pm_name: str, level: str = 'all') -> Dict[str, Any]:
    """
    Install packages for a specific package manager.

    Args:
        pm_name: Name of the package manager
        level: Installation level (for brew: 'user', 'admin', 'all')

    Returns:
        Dict with installation results
    """
    installers = {
        'brew': lambda: install_brew_packages(level),
        'apt': install_apt_packages,
        'npm': install_npm_packages,
        'pip': install_pip_packages,
        # Add more installers as needed
    }

    if pm_name not in installers:
        return {
            'pm': pm_name,
            'success': False,
            'output': '',
            'error': f'No installer defined for {pm_name}',
            'installed_count': 0
        }

    return installers[pm_name]()


def install_all_pms(selected_pms: List[str], level: str = 'all') -> List[Dict[str, Any]]:
    """
    Install packages for all selected package managers.

    Args:
        selected_pms: List of selected package manager names
        level: Installation level ('user', 'admin', 'all' for system packages)

    Returns:
        List of installation results for each PM
    """
    results = []

    for pm in selected_pms:
        print(f"📦 Installing packages for {pm}...")
        result = install_packages_for_pm(pm, level)
        results.append(result)

        if result['success']:
            if result['installed_count'] > 0:
                print(f"  ✅ {result['installed_count']} packages installed")
            else:
                print(f"  ✅ Installation completed")
        else:
            print(f"  ❌ Installation failed: {result['error']}")

    return results


def main():
    """CLI entry point for package installation."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Install packages for selected package managers'
    )
    parser.add_argument(
        'pms',
        nargs='*',
        help='Specific PMs to install for (optional)'
    )
    parser.add_argument(
        '--level',
        choices=['user', 'admin', 'all'],
        default='all',
        help='Installation level for system packages'
    )
    parser.add_argument(
        '--category',
        choices=['system', 'dev', 'app'],
        help='Package category to install'
    )

    args = parser.parse_args()

    print("📦 Package Manager Installation")
    print("=" * 32)

    # Detect available package managers
    available_pms = detect_all_pms()

    if not available_pms:
        print("❌ No package managers detected")
        return 1

    print(f"\n📋 Detected {len(available_pms)} package managers")

    # Filter by category if specified
    if args.category:
        category_pms = {
            'system': ['brew', 'apt', 'pacman', 'dnf', 'zypper', 'choco', 'winget', 'scoop'],
            'dev': ['npm', 'pip', 'pipx', 'cargo', 'gem'],
            'app': ['emacs', 'zinit', 'neovim']
        }
        available_pms = [pm for pm in available_pms if pm in category_pms.get(args.category, [])]

    # Filter by specific PMs if requested
    if args.pms:
        selected_pms = [pm for pm in args.pms if pm in available_pms]
        if not selected_pms:
            print(f"❌ None of the specified PMs are available: {args.pms}")
            return 1
    else:
        # Interactive selection
        selected_pms = select_pms(available_pms)

    if not selected_pms:
        print("⏭️ No package managers selected - nothing to install")
        return 0

    print(f"\n🎯 Installing packages for {len(selected_pms)} package managers...")
    print()

    # Install packages for all selected package managers
    results = install_all_pms(selected_pms, args.level)

    # Summary
    print("\n📊 Installation Summary")
    print("=====================")

    total_installed = 0
    successful_installs = 0

    for result in results:
        status = "✅" if result['success'] else "❌"
        pm = result['pm']

        if result['success']:
            successful_installs += 1
            count = result['installed_count']
            total_installed += count
            print(f"{status} {pm}: {count} packages installed")
        else:
            print(f"{status} {pm}: Installation failed")

    print()
    print(f"📈 Total packages installed: {total_installed}")
    print(f"🎯 Successful installations: {successful_installs}/{len(selected_pms)}")

    return 0 if successful_installs == len(selected_pms) else 1


if __name__ == '__main__':
    sys.exit(main())
