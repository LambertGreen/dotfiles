#!/usr/bin/env python3
"""
TOML Package Definition Parser
Parses structured package definitions and outputs installation lists or health checks
"""

import sys
import argparse
from pathlib import Path

# Python 3.11+ required for native TOML support
try:
    import tomllib
except ImportError:
    print("Error: Python 3.11+ required for native tomllib support", file=sys.stderr)
    print("Your Python version:", sys.version, file=sys.stderr)
    print("Please run bootstrap to install Python 3.11+", file=sys.stderr)
    sys.exit(1)

def load_toml_file(file_path):
    """Load and parse a TOML file"""
    with open(file_path, 'rb') as f:
        return tomllib.load(f)

def get_package_list(data, platform, package_manager, priority=None):
    """Extract package list for specific platform and package manager"""
    packages = []
    
    for pkg_name, pkg_info in data.get('packages', {}).items():
        # Check if package is platform-specific
        if 'platforms' in pkg_info and platform not in pkg_info['platforms']:
            continue
            
        # Check priority filter if specified
        if priority and pkg_info.get('priority') != priority:
            continue
            
        # Get install info for this platform/manager
        install_info = pkg_info.get('install', {})
        manager_key = f"{platform}_{package_manager}"
        
        if manager_key in install_info:
            packages.append(install_info[manager_key])
    
    return packages

def get_health_checks(data, platform=None, priority=None):
    """Extract health check commands for packages"""
    checks = []
    
    for pkg_name, pkg_info in data.get('packages', {}).items():
        # Check if package is platform-specific
        if platform and 'platforms' in pkg_info and platform not in pkg_info['platforms']:
            continue
            
        # Check priority filter if specified
        pkg_priority = pkg_info.get('priority')
        if priority and pkg_priority != priority:
            continue
            
        if 'health_check' in pkg_info:
            checks.append({
                'name': pkg_name,
                'description': pkg_info.get('description', ''),
                'executable': pkg_info.get('executable', pkg_name),
                'health_check': pkg_info['health_check']
            })
    
    return checks

def main():
    parser = argparse.ArgumentParser(description='Parse TOML package definitions')
    parser.add_argument('file', help='TOML file to parse')
    parser.add_argument('--action', choices=['packages', 'health-checks'], required=True,
                        help='Action to perform')
    parser.add_argument('--platform', help='Platform (osx, arch, ubuntu)')
    parser.add_argument('--package-manager', help='Package manager (brew, pacman, apt)')
    parser.add_argument('--priority', help='Priority filter (p1, p2)')
    parser.add_argument('--format', choices=['list', 'json', 'bash'], default='list',
                        help='Output format')
    
    args = parser.parse_args()
    
    try:
        data = load_toml_file(args.file)
        
        if args.action == 'packages':
            if not args.platform or not args.package_manager:
                print("Error: --platform and --package-manager required for packages action", file=sys.stderr)
                sys.exit(1)
                
            packages = get_package_list(data, args.platform, args.package_manager, args.priority)
            
            if args.format == 'list':
                for pkg in packages:
                    print(pkg)
            elif args.format == 'bash':
                print(' '.join(packages))
                
        elif args.action == 'health-checks':
            checks = get_health_checks(data, args.platform, args.priority)
            
            if args.format == 'list':
                for check in checks:
                    print(f"{check['name']}: {check['health_check']}")
            elif args.format == 'bash':
                # Output as bash function calls
                for check in checks:
                    print(f"check_package \"{check['name']}\" \"{check['executable']}\" \"{check['health_check']}\"")
                    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()