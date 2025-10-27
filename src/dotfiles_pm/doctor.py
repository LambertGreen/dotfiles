#!/usr/bin/env python3
"""
Cross-platform system health checks (doctor command)

Checks:
- PATH validation (broken entries, version-specific paths, duplicates)
- Tool availability (expected tools are findable)
- Package manager health
"""

import os
import sys
import re
from pathlib import Path
from typing import List, Dict, Tuple, Optional
import platform


class PathDoctor:
    """Cross-platform PATH health checker"""

    def __init__(self):
        self.platform = platform.system()
        self.path_separator = os.pathsep  # : on Unix, ; on Windows
        self.issues: List[Dict] = []
        self.warnings: List[Dict] = []

    def check_all(self) -> Tuple[List[Dict], List[Dict]]:
        """Run all PATH checks, return (issues, warnings)"""
        self.check_broken_paths()
        self.check_version_specific_paths()
        self.check_duplicate_paths()
        return (self.issues, self.warnings)

    def get_current_path_entries(self) -> List[str]:
        """Get current session PATH entries"""
        path_str = os.environ.get('PATH', '')
        return [p.strip() for p in path_str.split(self.path_separator) if p.strip()]

    def check_broken_paths(self):
        """Check for PATH entries that don't exist on disk"""
        entries = self.get_current_path_entries()

        for entry in entries:
            path_obj = Path(entry)
            if not path_obj.exists():
                self.issues.append({
                    'type': 'broken_path',
                    'severity': 'error',
                    'path': entry,
                    'message': f'PATH entry does not exist: {entry}',
                    'suggestion': 'Remove this entry from PATH or reinstall the application'
                })

    def check_version_specific_paths(self):
        """Check for paths with version numbers (likely to break on updates)"""
        entries = self.get_current_path_entries()

        # Pattern to match version numbers like 2024.2.2, 1.2.3, v20.0, etc.
        version_patterns = [
            r'\d{4}\.\d+\.\d+',  # 2024.2.2 (JetBrains style)
            r'v?\d+\.\d+\.\d+',  # v1.2.3 or 1.2.3
            r'v?\d+\.\d+',       # v20.0 or 20.0
        ]

        for entry in entries:
            for pattern in version_patterns:
                if re.search(pattern, entry):
                    self.warnings.append({
                        'type': 'version_specific_path',
                        'severity': 'warning',
                        'path': entry,
                        'message': f'PATH contains version-specific directory: {entry}',
                        'suggestion': 'Consider using a package manager (scoop, brew, apt) or version-agnostic symlinks'
                    })
                    break  # Only warn once per path

    def check_duplicate_paths(self):
        """Check for duplicate PATH entries"""
        entries = self.get_current_path_entries()
        seen = {}

        for entry in entries:
            # Normalize for comparison (resolve symlinks, normalize case on Windows)
            try:
                normalized = str(Path(entry).resolve())
                if self.platform == 'Windows':
                    normalized = normalized.lower()

                if normalized in seen:
                    self.warnings.append({
                        'type': 'duplicate_path',
                        'severity': 'warning',
                        'path': entry,
                        'duplicate_of': seen[normalized],
                        'message': f'Duplicate PATH entry: {entry}',
                        'suggestion': 'Remove duplicate entries to simplify PATH'
                    })
                else:
                    seen[normalized] = entry
            except (OSError, RuntimeError):
                # Path might not exist or be resolvable, skip normalization
                pass


class ToolDoctor:
    """Check availability of expected development tools"""

    def __init__(self):
        self.issues: List[Dict] = []
        self.warnings: List[Dict] = []

    def check_all(self, expected_tools: Optional[List[str]] = None) -> Tuple[List[Dict], List[Dict]]:
        """Check if expected tools are available in PATH"""
        if expected_tools is None:
            # Common development tools
            expected_tools = [
                'git', 'python', 'python3', 'node', 'npm',
                'stow', 'gcc', 'make', 'vim', 'emacs'
            ]

        for tool in expected_tools:
            if not self.is_tool_available(tool):
                self.warnings.append({
                    'type': 'tool_not_found',
                    'severity': 'warning',
                    'tool': tool,
                    'message': f'Expected tool not found in PATH: {tool}',
                    'suggestion': f'Install {tool} or verify it is in your PATH'
                })

        return (self.issues, self.warnings)

    def is_tool_available(self, tool: str) -> bool:
        """Check if a tool is available in PATH"""
        # Use 'where' on Windows, 'which' on Unix
        cmd = 'where' if platform.system() == 'Windows' else 'which'
        return os.system(f'{cmd} {tool} > /dev/null 2>&1') == 0


class PacmanDoctor:
    """MSYS2 Pacman-specific health checks"""

    def __init__(self):
        self.issues: List[Dict] = []
        self.warnings: List[Dict] = []

    def check_all(self) -> Tuple[List[Dict], List[Dict]]:
        """Run pacman-specific health checks"""
        self.check_database_lock()
        return (self.issues, self.warnings)

    def check_database_lock(self):
        """Check for stale pacman database lock"""
        # Only relevant on systems with pacman
        if not self._has_pacman():
            return

        lock_file = self._get_pacman_lock_path()
        if lock_file and lock_file.exists():
            self.warnings.append({
                'type': 'pacman_db_locked',
                'severity': 'warning',
                'path': str(lock_file),
                'message': f'Pacman database is locked: {lock_file}',
                'suggestion': 'If no pacman process is running, manually remove the lock file'
            })

    def _has_pacman(self) -> bool:
        """Check if pacman is available"""
        if platform.system() == 'Windows':
            # Check for MSYS2 pacman
            msys2_roots = [Path('C:/msys64'), Path('C:/tools/msys64')]
            for root in msys2_roots:
                if (root / 'usr' / 'bin' / 'pacman.exe').exists():
                    return True
            return False
        else:
            # On Linux, check if pacman exists
            return os.system('which pacman > /dev/null 2>&1') == 0

    def _get_pacman_lock_path(self) -> Optional[Path]:
        """Get the pacman database lock file path"""
        if platform.system() == 'Windows':
            # MSYS2 location
            msys2_roots = [Path('C:/msys64'), Path('C:/tools/msys64')]
            for root in msys2_roots:
                lock_file = root / 'var' / 'lib' / 'pacman' / 'db.lck'
                if root.exists():
                    return lock_file
        else:
            # Standard Linux location
            return Path('/var/lib/pacman/db.lck')
        return None


def print_results(issues: List[Dict], warnings: List[Dict]):
    """Pretty-print doctor results"""

    if not issues and not warnings:
        print("✅ All checks passed! System is healthy.")
        return

    if issues:
        print(f"\n❌ Found {len(issues)} issue(s):\n")
        for issue in issues:
            print(f"  [{issue['severity'].upper()}] {issue['message']}")
            if 'suggestion' in issue:
                print(f"    💡 {issue['suggestion']}")
            print()

    if warnings:
        print(f"\n⚠️  Found {len(warnings)} warning(s):\n")
        for warning in warnings:
            print(f"  [{warning['severity'].upper()}] {warning['message']}")
            if 'suggestion' in warning:
                print(f"    💡 {warning['suggestion']}")
            print()


def main():
    """Run all doctor checks"""
    print(f"🩺 Running system health checks on {platform.system()}...\n")

    all_issues = []
    all_warnings = []

    # PATH checks
    print("Checking PATH...")
    path_doctor = PathDoctor()
    issues, warnings = path_doctor.check_all()
    all_issues.extend(issues)
    all_warnings.extend(warnings)

    # Tool availability checks
    print("Checking tool availability...")
    tool_doctor = ToolDoctor()
    issues, warnings = tool_doctor.check_all()
    all_issues.extend(issues)
    all_warnings.extend(warnings)

    # Pacman checks (if applicable)
    if platform.system() in ('Windows', 'Linux'):
        print("Checking package manager health...")
        pacman_doctor = PacmanDoctor()
        issues, warnings = pacman_doctor.check_all()
        all_issues.extend(issues)
        all_warnings.extend(warnings)

    # Print results
    print_results(all_issues, all_warnings)

    # Exit code: 0 if no issues, 1 if issues found, 2 if warnings only
    if all_issues:
        sys.exit(1)
    elif all_warnings:
        sys.exit(2)
    else:
        sys.exit(0)


if __name__ == '__main__':
    main()
