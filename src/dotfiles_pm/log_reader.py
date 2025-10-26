#!/usr/bin/env python3
"""
Log Reader Module

Utilities for reading and summarizing package manager operation logs.
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Optional


class LogReader:
    """Read and summarize package manager operation logs"""

    def __init__(self, log_dir: Optional[Path] = None):
        """Initialize with log directory"""
        self.log_dir = log_dir or (Path.home() / '.dotfiles' / 'logs')

    def get_latest_operation(self, operation: str) -> Optional[Dict]:
        """Get the latest log for a specific operation"""
        pattern = f"{operation}-*.log"
        logs = sorted(self.log_dir.glob(pattern))

        if not logs:
            return None

        latest_log = logs[-1]
        latest_status = latest_log.with_suffix('.status')

        return self.read_operation_log(latest_log, latest_status)

    def read_operation_log(self, log_file: Path, status_file: Path) -> Dict:
        """Read and summarize an operation log"""
        result = {
            'log_file': str(log_file),
            'status_file': str(status_file)
        }

        # Read status
        if status_file.exists():
            status = json.loads(status_file.read_text())
            result.update(status)

        # Parse log for key information
        if log_file.exists():
            log_content = log_file.read_text()
            result['summary'] = self._parse_log_summary(log_content, result.get('operation', ''))

        return result

    def _parse_log_summary(self, log_content: str, operation: str) -> Dict:
        """Parse log content for key information"""
        summary = {
            'lines': len(log_content.splitlines()),
            'size': len(log_content)
        }

        if 'brew' in operation:
            # Parse brew-specific info
            upgraded_match = re.findall(r'==> Upgrading (\d+) outdated packages?:', log_content)
            if upgraded_match:
                summary['packages_upgraded'] = int(upgraded_match[0])

            # Extract package names
            package_matches = re.findall(r'^(\S+) [\d\.]+ -> [\d\.]+', log_content, re.MULTILINE)
            if package_matches:
                summary['upgraded_packages'] = package_matches

            # Check for errors
            if 'Error:' in log_content or 'fatal:' in log_content:
                summary['has_errors'] = True

            # Check if already up-to-date
            if 'Already up-to-date' in log_content or 'No outdated' in log_content:
                summary['already_current'] = True

        return summary

    def list_recent_operations(self, limit: int = 10) -> List[Dict]:
        """List recent operations across all package managers"""
        all_logs = sorted(self.log_dir.glob("*-*.log"), key=lambda p: p.stat().st_mtime, reverse=True)

        operations = []
        for log_file in all_logs[:limit]:
            status_file = log_file.with_suffix('.status')
            ops = self.read_operation_log(log_file, status_file)
            operations.append(ops)

        return operations


def summarize_latest(operation: str = 'brew-upgrade') -> None:
    """Print summary of latest operation"""
    reader = LogReader()
    result = reader.get_latest_operation(operation)

    if not result:
        print(f"No logs found for {operation}")
        return

    print(f"📊 {operation} Summary")
    print("=" * 40)
    print(f"Status: {'✅ Success' if result.get('exit_code') == 0 else '❌ Failed'}")

    if 'summary' in result:
        summary = result['summary']
        if 'upgraded_packages' in summary:
            print(f"Upgraded: {', '.join(summary['upgraded_packages'])}")
        elif summary.get('already_current'):
            print("Already up-to-date")

        if summary.get('has_errors'):
            print("⚠️  Errors detected in log")

    print(f"Log: {result['log_file']}")


if __name__ == '__main__':
    import sys
    operation = sys.argv[1] if len(sys.argv) > 1 else 'brew-upgrade'
    summarize_latest(operation)
