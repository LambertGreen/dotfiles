#!/usr/bin/env python3
"""
Package Manager Check Module

Check for outdated packages across multiple package managers.
"""

import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Any

# Add current directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from pm_detect import detect_all_pms
from pm_select import select_pms


def check_pm_outdated(pm_name: str) -> Dict[str, Any]:
    """
    Check for outdated packages using a specific package manager.

    Args:
        pm_name: Name of the package manager

    Returns:
        Dict with status, output, and error information
    """
    result = {
        'pm': pm_name,
        'success': False,
        'output': '',
        'error': '',
        'outdated_count': 0
    }

    # Define commands for different package managers
    commands = {
        'brew': ['brew', 'outdated', '--verbose'],
        'npm': ['npm', 'outdated', '-g'],
        'pip': ['pip3', 'list', '--outdated'],
        'pipx': ['pipx', 'list', '--short'],
        'cargo': ['cargo', 'install-update', '--list'],
        'gem': ['gem', 'outdated'],
        'fake-pm1': ['fake-pm1', 'outdated'],
        'fake-pm2': ['fake-pm2', 'outdated'],
    }

    if pm_name not in commands:
        result['error'] = f"No check command defined for {pm_name}"
        return result

    try:
        cmd = commands[pm_name]
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )

        result['output'] = proc.stdout.strip()
        result['error'] = proc.stderr.strip()
        result['success'] = proc.returncode == 0

        # Count outdated packages (simple line count for now)
        if result['success'] and result['output']:
            lines = [line for line in result['output'].split('\n') if line.strip()]
            result['outdated_count'] = len(lines)

    except subprocess.TimeoutExpired:
        result['error'] = f"Command timed out after 30 seconds"
    except FileNotFoundError:
        result['error'] = f"Command not found: {' '.join(cmd)}"
    except Exception as e:
        result['error'] = f"Unexpected error: {str(e)}"

    return result


def check_all_pms(selected_pms: List[str]) -> List[Dict[str, Any]]:
    """
    Check all selected package managers for outdated packages.

    Args:
        selected_pms: List of selected package manager names

    Returns:
        List of check results for each PM
    """
    results = []

    for pm in selected_pms:
        print(f"🔍 Checking {pm}...")
        result = check_pm_outdated(pm)
        results.append(result)

        if result['success']:
            if result['outdated_count'] > 0:
                print(f"  ⚠️  {result['outdated_count']} outdated packages")
            else:
                print(f"  ✅ All packages up to date")
        else:
            print(f"  ❌ Check failed: {result['error']}")

    return results


def main():
    """CLI entry point for package checking."""
    print("🔍 Package Manager Check")
    print("=" * 25)

    # Detect available package managers
    available_pms = detect_all_pms()

    if not available_pms:
        print("❌ No package managers detected")
        return 1

    print(f"\n📋 Detected {len(available_pms)} package managers")

    # Select package managers to check
    selected_pms = select_pms(available_pms)

    if not selected_pms:
        print("⏭️ No package managers selected - nothing to check")
        return 0

    print(f"\n🎯 Checking {len(selected_pms)} package managers...")
    print()

    # Check all selected package managers
    results = check_all_pms(selected_pms)

    # Summary
    print("\n📊 Check Summary")
    print("================")

    total_outdated = 0
    successful_checks = 0

    for result in results:
        status = "✅" if result['success'] else "❌"
        pm = result['pm']

        if result['success']:
            successful_checks += 1
            count = result['outdated_count']
            total_outdated += count
            print(f"{status} {pm}: {count} outdated packages")
        else:
            print(f"{status} {pm}: Check failed")

    print()
    print(f"📈 Total outdated packages: {total_outdated}")
    print(f"🎯 Successful checks: {successful_checks}/{len(selected_pms)}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
