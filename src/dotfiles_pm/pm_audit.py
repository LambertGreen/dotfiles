#!/usr/bin/env python3
"""
Package Manager Audit Module

Checks for consistency between detected package managers and their manifests.
Identifies orphaned package managers and suggests remediation.
"""

import os
import subprocess
from pathlib import Path
from typing import Dict, List, Tuple, Optional

from .pm_detect import detect_all_pms


def get_dotfiles_dir() -> Path:
    """Get the dotfiles directory."""
    dotfiles_dir = os.environ.get('DOTFILES_DIR')
    if dotfiles_dir:
        return Path(dotfiles_dir)
    return Path.cwd()


def find_manifests() -> Dict[str, List[Path]]:
    """Find all package manager manifest files."""
    dotfiles_dir = get_dotfiles_dir()
    manifests = {}

    # Define manifest patterns for each package manager
    manifest_patterns = {
        'brew': ['**/Brewfile'],
        'npm': ['**/package.json', '**/packages.txt'],
        'pip': ['**/requirements.txt', '**/pyproject.toml'],
        'pipx': ['**/pipx-packages.txt'],
        'cargo': ['**/Cargo.toml'],
        'gem': ['**/Gemfile', '**/gems.txt'],
        'apt': ['**/packages.txt'],
        'pacman': ['**/packages.txt'],
        'scoop': ['**/packages.txt'],
        'choco': ['**/packages.txt'],
        'winget': ['**/packages.txt'],
        'emacs': ['**/.emacs.d/init.el', '**/emacs-packages.txt'],
        'zinit': ['**/.zshrc', '**/zinit-packages.txt'],
        'neovim': ['**/init.vim', '**/init.lua', '**/nvim-packages.txt']
    }

    for pm, patterns in manifest_patterns.items():
        manifests[pm] = []
        for pattern in patterns:
            manifests[pm].extend(dotfiles_dir.glob(pattern))

    return manifests


def get_installed_packages(pm: str) -> Tuple[bool, List[str]]:
    """Get list of installed packages for a package manager."""
    commands = {
        'brew': ['brew', 'list', '--formula'],
        'npm': ['npm', 'list', '-g', '--depth=0', '--parseable'],
        'pip': ['pip3', 'list', '--format=freeze'],
        'pipx': ['pipx', 'list'],
        'cargo': ['cargo', 'install', '--list'],
        'gem': ['gem', 'list'],
        'apt': ['apt', 'list', '--installed'],
        'pacman': ['pacman', '-Q'],
        'scoop': ['scoop', 'list'],
        'choco': ['choco', 'list'],
        'winget': ['winget', 'list'],
        'emacs': None,  # Package list varies by config
        'zinit': None,  # Package list varies by config
        'neovim': None  # Package list varies by config
    }

    cmd = commands.get(pm)
    if not cmd:
        return False, []

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            # Filter out empty lines and headers
            packages = [line for line in lines if line.strip() and not line.startswith('Warning')]
            return True, packages
        else:
            return False, []
    except (subprocess.TimeoutExpired, FileNotFoundError, subprocess.SubprocessError):
        return False, []


def audit_package_managers() -> Dict[str, Dict]:
    """Audit all package managers for consistency."""
    detected_pms = detect_all_pms()
    manifests = find_manifests()

    audit_results = {}

    for pm in detected_pms:
        pm_manifests = manifests.get(pm, [])
        has_manifest = len(pm_manifests) > 0

        success, packages = get_installed_packages(pm)
        has_packages = success and len(packages) > 0

        audit_results[pm] = {
            'has_manifest': has_manifest,
            'manifest_files': pm_manifests,
            'has_packages': has_packages,
            'package_count': len(packages) if success else 0,
            'packages': packages if success else [],
            'check_success': success
        }

    return audit_results


def recommend_actions(audit_results: Dict[str, Dict]) -> List[Tuple[str, str, str]]:
    """Generate recommendations based on audit results."""
    recommendations = []

    # Editor package managers use custom configs, not standard package lists
    editor_pms = {'emacs', 'zinit', 'neovim'}

    # Package managers that should be removed if unused (violate editor-isolation)
    isolation_violators = {'pipx', 'gem', 'cargo'}

    for pm, result in audit_results.items():
        has_manifest = result['has_manifest']
        has_packages = result['has_packages']
        check_success = result['check_success']

        if pm in editor_pms:
            if has_manifest:
                recommendations.append((
                    pm,
                    'editor_clean',
                    f"Editor package manager with config files - packages managed by editor"
                ))
            else:
                recommendations.append((
                    pm,
                    'editor_no_config',
                    f"Editor package manager detected but no config files found"
                ))
        elif not check_success:
            recommendations.append((
                pm,
                'error',
                f"Failed to check installed packages - may need manual inspection"
            ))
        elif not has_manifest and not has_packages:
            if pm in isolation_violators:
                recommendations.append((
                    pm,
                    'remove_isolation',
                    f"Unused package manager that violates editor-isolation - consider removing from system"
                ))
            else:
                recommendations.append((
                    pm,
                    'remove',
                    f"No manifest and no packages - consider removing {pm} from system"
                ))
        elif not has_manifest and has_packages:
            if pm in isolation_violators:
                recommendations.append((
                    pm,
                    'violation',
                    f"Has {result['package_count']} packages but violates editor-isolation - consider using project-local environments instead"
                ))
            else:
                recommendations.append((
                    pm,
                    'add_manifest',
                    f"Has {result['package_count']} packages but no manifest - consider adding manifest file"
                ))
        elif has_manifest and not has_packages:
            recommendations.append((
                pm,
                'clean',
                f"Has manifest but no packages - configuration is clean"
            ))
        else:
            recommendations.append((
                pm,
                'consistent',
                f"Has both manifest and {result['package_count']} packages - configuration is consistent"
            ))

    return recommendations


def print_audit_report(audit_results: Dict[str, Dict], recommendations: List[Tuple[str, str, str]]):
    """Print a comprehensive audit report."""
    print("🔍 Package Manager Audit Report")
    print("=" * 32)
    print()

    # Group recommendations by action type
    actions = {
        'consistent': [],
        'clean': [],
        'editor_clean': [],
        'editor_no_config': [],
        'add_manifest': [],
        'violation': [],
        'remove': [],
        'remove_isolation': [],
        'error': []
    }

    for pm, action, description in recommendations:
        actions[action].append((pm, description))

    # Print consistent configurations first
    if actions['consistent']:
        print("✅ Consistent Configurations")
        print("-" * 28)
        for pm, desc in actions['consistent']:
            print(f"  {pm}: {desc}")
        print()

    if actions['clean']:
        print("🧹 Clean Configurations")
        print("-" * 23)
        for pm, desc in actions['clean']:
            print(f"  {pm}: {desc}")
        print()

    # Editor package managers
    if actions['editor_clean']:
        print("📝 Editor Package Managers (Properly Configured)")
        print("-" * 49)
        for pm, desc in actions['editor_clean']:
            print(f"  {pm}: {desc}")
        print()

    if actions['editor_no_config']:
        print("⚠️  Editor Package Managers (No Config Found)")
        print("-" * 46)
        for pm, desc in actions['editor_no_config']:
            print(f"  {pm}: {desc}")
        print()

    # Print issues that need attention
    if actions['add_manifest']:
        print("📝 Missing Manifests (Action Needed)")
        print("-" * 36)
        for pm, desc in actions['add_manifest']:
            print(f"  {pm}: {desc}")
            result = audit_results[pm]
            if result['packages']:
                print(f"     Installed packages ({len(result['packages'])}):")
                for pkg in result['packages'][:5]:  # Show first 5
                    print(f"       - {pkg}")
                if len(result['packages']) > 5:
                    print(f"       ... and {len(result['packages']) - 5} more")
        print()

    # Editor-isolation violations
    if actions['violation']:
        print("⚠️  Editor-Isolation Violations")
        print("-" * 33)
        for pm, desc in actions['violation']:
            print(f"  {pm}: {desc}")
            result = audit_results[pm]
            if result['packages']:
                print(f"     Consider moving to project-local environments:")
                for pkg in result['packages'][:3]:  # Show first 3
                    print(f"       - {pkg}")
                if len(result['packages']) > 3:
                    print(f"       ... and {len(result['packages']) - 3} more")
        print()

    if actions['remove'] or actions['remove_isolation']:
        print("🗑️  Unused Package Managers (Consider Removal)")
        print("-" * 46)
        for pm, desc in actions['remove'] + actions['remove_isolation']:
            print(f"  {pm}: {desc}")
        print()

    if actions['error']:
        print("❌ Package Managers with Errors")
        print("-" * 32)
        for pm, desc in actions['error']:
            print(f"  {pm}: {desc}")
        print()

    # Summary
    total = len(audit_results)
    consistent = len(actions['consistent']) + len(actions['clean']) + len(actions['editor_clean'])
    needs_attention = len(actions['add_manifest']) + len(actions['violation']) + len(actions['remove']) + len(actions['remove_isolation']) + len(actions['editor_no_config'])
    errors = len(actions['error'])

    print("📊 Summary")
    print("-" * 10)
    print(f"Total package managers detected: {total}")
    print(f"Properly configured: {consistent}")
    print(f"Need attention: {needs_attention}")
    print(f"Errors: {errors}")
