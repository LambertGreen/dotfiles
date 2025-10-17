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
from .terminal_executor import spawn_tracked, create_terminal_executor


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


def install_brew_packages(package_type: str = 'all') -> Dict[str, Any]:
    """
    Install Homebrew packages from unified Brewfile.

    Args:
        package_type: 'formulas', 'casks', or 'all'

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
        result['success'] = True
        result['output'] = '⚠️  No configuration directory found - consider creating one or uninstalling brew'
        return result

    brewfile = config_dir / 'Brewfile'

    # Fallback to old packages.user/admin if Brewfile doesn't exist
    if not brewfile.exists():
        # Try legacy format
        legacy_files = [config_dir / 'packages.user', config_dir / 'packages.admin']
        for legacy_file in legacy_files:
            if legacy_file.exists():
                brewfile = legacy_file
                break

    if not brewfile.exists():
        result['error'] = f'Brewfile not found in {config_dir}'
        return result

    print(f"  📦 Installing from: {brewfile.name}")

    try:
        # Determine install command and environment based on package type
        cmd = ['brew', 'bundle', 'install', f'--file={brewfile}', '--no-upgrade']
        env = dict(os.environ)

        if package_type == 'formulas':
            print(f"  🍺 Installing formulas only...")
            env['HOMEBREW_BUNDLE_CASK_SKIP'] = '1'
            env['HOMEBREW_BUNDLE_MAS_SKIP'] = '1'
        elif package_type == 'casks':
            print(f"  📦 Installing casks only...")
            env['HOMEBREW_BUNDLE_BREW_SKIP'] = '1'
            env['HOMEBREW_BUNDLE_MAS_SKIP'] = '1'
        else:  # 'all'
            print(f"  📦 Installing all packages...")

        proc = subprocess.run(
            cmd,
            env=env,
            capture_output=True,
            text=True,
            timeout=600  # 10 minutes for installations
        )

        if proc.returncode == 0:
            # Count installed packages (rough estimate)
            lines = proc.stdout.strip().split('\n') if proc.stdout else []
            installed = len([l for l in lines if 'Installing' in l or 'Installed' in l])
            result['installed_count'] = installed
            result['output'] = proc.stdout
            result['success'] = True
        else:
            # brew bundle outputs errors to stdout, not stderr
            result['error'] = proc.stdout if proc.stdout else proc.stderr

    except subprocess.TimeoutExpired:
        result['error'] = 'Installation timed out'
    except Exception as e:
        result['error'] = str(e)

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
        result['success'] = True
        result['output'] = '⚠️  No packages.txt file found - consider creating one or removing config directory'
        return result

    # Read packages
    with open(package_file) as f:
        packages = [line.strip() for line in f if line.strip() and not line.startswith('#')]

    if not packages:
        result['output'] = 'No packages to install'
        result['success'] = True
        return result

    print(f"  📦 Installing {len(packages)} packages...")

    # Build install command (user should run 'just update' first)
    packages_str = ' '.join(packages)
    cmd_str = f"sudo apt-get install -y {packages_str}"

    # Spawn terminal for interactive execution
    terminal_result = spawn_tracked(
        cmd_str,
        operation=f"apt-install",
        auto_close=False
    )

    if terminal_result.status in ['spawned', 'completed']:
        result['success'] = True
        result['log_file'] = terminal_result.log_file
        result['status_file'] = terminal_result.status_file
        result['installed_count'] = len(packages)
        print(f"  🖥️  Executing in new terminal window...")
        print(f"  📄 Log: {terminal_result.log_file}")
    else:
        result['success'] = False
        result['error'] = terminal_result.error or 'Failed to spawn terminal'

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
        result['success'] = True
        result['output'] = '⚠️  No configuration directory found - consider creating one or uninstalling npm'
        return result

    package_file = config_dir / 'packages.txt'
    if not package_file.exists():
        result['success'] = True
        result['output'] = '⚠️  No packages.txt file found - consider creating one or removing config directory'
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
        installed_count = 0
        failed_packages = []
        output_lines = []

        for package in packages:
            cmd = ['npm', 'install', '-g', package]
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

            if proc.returncode == 0:
                installed_count += 1
                output_lines.append(f"✅ {package}: installed")
            else:
                failed_packages.append(package)
                output_lines.append(f"❌ {package}: failed - {proc.stderr.strip()}")

        result['output'] = '\n'.join(output_lines)
        result['success'] = installed_count > 0  # Success if at least one package installed
        result['installed_count'] = installed_count

        if failed_packages:
            result['error'] = f"Failed to install: {', '.join(failed_packages)}"

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
        result['success'] = True
        result['output'] = '⚠️  No configuration directory found - consider creating one or uninstalling pip'
        return result

    package_file = config_dir / 'requirements.txt'
    if not package_file.exists():
        result['success'] = True
        result['output'] = '⚠️  No requirements.txt file found - consider creating one or removing config directory'
        return result

    try:
        print(f"  📦 Installing pip packages from requirements.txt...")
        cmd = ['pip3', 'install', '--user', '--break-system-packages', '-r', str(package_file)]

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


def install_pipx_packages() -> Dict[str, Any]:
    """
    Install pipx packages from packages.txt file.

    Returns:
        Dict with installation results
    """
    result = {
        'pm': 'pipx',
        'success': False,
        'output': '',
        'error': '',
        'installed_count': 0
    }

    config_dir = get_machine_config_dir('pipx')
    if not config_dir:
        # Warn user - PM is installed but no config exists
        result['success'] = True
        result['output'] = '⚠️  No configuration directory found - consider creating one or uninstalling pipx'
        return result

    package_file = config_dir / 'packages.txt'
    if not package_file.exists():
        # Warn user - config dir exists but no package file
        result['success'] = True
        result['output'] = '⚠️  No packages.txt file found - consider creating one or removing config directory'
        return result

    # Read packages
    with open(package_file) as f:
        packages = [line.strip() for line in f if line.strip() and not line.startswith('#')]

    if not packages:
        result['output'] = 'No packages to install'
        result['success'] = True
        return result

    try:
        print(f"  📦 Installing {len(packages)} pipx packages...")
        installed_count = 0
        for package in packages:
            cmd = ['pipx', 'install', package]
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            if proc.returncode == 0:
                installed_count += 1

        result['output'] = f'Attempted to install {len(packages)} packages'
        result['success'] = True
        result['installed_count'] = installed_count

    except subprocess.TimeoutExpired:
        result['error'] = 'Installation timed out'
    except Exception as e:
        result['error'] = str(e)

    return result


def install_cargo_packages() -> Dict[str, Any]:
    """
    Install cargo packages from packages.txt file.

    Returns:
        Dict with installation results
    """
    result = {
        'pm': 'cargo',
        'success': False,
        'output': '',
        'error': '',
        'installed_count': 0
    }

    config_dir = get_machine_config_dir('cargo')
    if not config_dir:
        result['success'] = True
        result['output'] = '⚠️  No configuration directory found - consider creating one or uninstalling cargo'
        return result

    package_file = config_dir / 'packages.txt'
    if not package_file.exists():
        result['success'] = True
        result['output'] = '⚠️  No packages.txt file found - consider creating one or removing config directory'
        return result

    # Read packages
    with open(package_file) as f:
        packages = [line.strip() for line in f if line.strip() and not line.startswith('#')]

    if not packages:
        result['output'] = 'No packages to install'
        result['success'] = True
        return result

    try:
        print(f"  📦 Installing {len(packages)} cargo packages...")
        cmd = ['cargo', 'install'] + packages

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


def install_gem_packages() -> Dict[str, Any]:
    """
    Install gem packages from packages.txt file.

    Returns:
        Dict with installation results
    """
    result = {
        'pm': 'gem',
        'success': False,
        'output': '',
        'error': '',
        'installed_count': 0
    }

    config_dir = get_machine_config_dir('gem')
    if not config_dir:
        result['success'] = True
        result['output'] = '⚠️  No configuration directory found - consider creating one or uninstalling gem'
        return result

    package_file = config_dir / 'packages.txt'
    if not package_file.exists():
        result['success'] = True
        result['output'] = '⚠️  No packages.txt file found - consider creating one or removing config directory'
        return result

    # Read packages
    with open(package_file) as f:
        packages = [line.strip() for line in f if line.strip() and not line.startswith('#')]

    if not packages:
        result['output'] = 'No packages to install'
        result['success'] = True
        return result

    try:
        print(f"  📦 Installing {len(packages)} gem packages...")
        cmd = ['gem', 'install'] + packages

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
        'brew': lambda: install_brew_packages('all'),  # Use single Brewfile for all packages
        'apt': install_apt_packages,
        'npm': install_npm_packages,
        'pip': install_pip_packages,
        'pipx': install_pipx_packages,
        'cargo': install_cargo_packages,
        'gem': install_gem_packages,
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

    Spawns terminals for interactive installations (like apt) and waits for completion.

    Args:
        selected_pms: List of selected package manager names
        level: Installation level ('user', 'admin', 'all' for system packages)

    Returns:
        List of installation results for each PM
    """
    import time

    print(f"🚀 Installing packages for {len(selected_pms)} package manager(s) sequentially...")
    print()

    executor = create_terminal_executor()
    completed_results = {}

    for i, pm in enumerate(selected_pms):
        print(f"📦 Installing {pm} packages ({i+1}/{len(selected_pms)})...")
        result = install_packages_for_pm(pm, level)

        if result.get('status_file'):
            # Terminal spawned - wait for completion
            print(f"  ⏳ Waiting for {pm} installation to complete...")

            status_file = result.get('status_file')
            while True:
                status_info = executor.check_status(status_file)
                if status_info.get('status') == 'completed':
                    exit_code = status_info.get('exit_code', 0)
                    final_result = {
                        'pm': pm,
                        'success': exit_code == 0,
                        'output': 'Installation completed' if exit_code == 0 else '',
                        'error': '' if exit_code == 0 else f"Installation failed with exit code {exit_code}",
                        'installed_count': result.get('installed_count', 0)
                    }
                    completed_results[pm] = final_result

                    if final_result['success']:
                        print(f"  ✅ {pm}: Installation completed successfully")
                    else:
                        print(f"  ❌ {pm}: Installation failed")
                    break

                elif status_info.get('status') == 'error':
                    final_result = {
                        'pm': pm,
                        'success': False,
                        'output': '',
                        'error': status_info.get('error', 'Unknown error'),
                        'installed_count': 0
                    }
                    completed_results[pm] = final_result
                    print(f"  ❌ {pm}: Installation failed")
                    break
                else:
                    # Still running, wait a bit
                    time.sleep(1)
        else:
            # Direct execution (no terminal spawned) or failure
            if result['success']:
                if result['installed_count'] > 0:
                    print(f"  ✅ {result['installed_count']} packages installed")
                else:
                    print(f"  ✅ Installation completed")
            else:
                print(f"  ❌ Installation failed: {result['error']}")
            completed_results[pm] = result

        print()  # Add spacing between sequential operations

    # Return results in original order
    return [completed_results.get(pm, {
        'pm': pm,
        'success': False,
        'output': '',
        'error': 'Unknown - result not found',
        'installed_count': 0
    }) for pm in selected_pms]


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

    # Filter out self-bootstrapping app PMs (they don't need install, just update/upgrade)
    self_bootstrapping_pms = {'emacs', 'zinit', 'neovim'}
    available_pms = [pm for pm in available_pms if pm not in self_bootstrapping_pms]

    if not available_pms:
        print("❌ No package managers need installation (app PMs bootstrap themselves)")
        return 0

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

    # Offer to close spawned terminals
    from .terminal_executor import prompt_close_terminals
    prompt_close_terminals()

    return 0 if successful_installs == len(selected_pms) else 1


if __name__ == '__main__':
    sys.exit(main())
