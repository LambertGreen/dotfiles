#!/usr/bin/env python3
"""
Python-based fake package manager implementation.

Provides realistic package manager behavior for testing without shell scripts.
Supports state tracking to validate upgrade behavior.
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Tuple


class FakePM:
    """Base class for fake package managers."""

    def __init__(self, name: str, version: str):
        self.name = name
        self.version = version
        self.state_file = Path(f"/tmp/fake-{name}-state.json")
        self.initial_packages = {}
        self.latest_versions = {}

    def load_state(self) -> Dict[str, str]:
        """Load current package state from file."""
        if not self.state_file.exists():
            self.reset_state()

        try:
            with open(self.state_file, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            self.reset_state()
            return self.initial_packages.copy()

    def save_state(self, packages: Dict[str, str]):
        """Save package state to file."""
        with open(self.state_file, 'w') as f:
            json.dump(packages, f, indent=2)

    def reset_state(self):
        """Reset to initial state."""
        self.save_state(self.initial_packages.copy())
        print(f"🔄 {self.name}: Reset to initial state")

    def cmd_version(self):
        """Show PM version."""
        print(f"{self.name} v{self.version}")

    def cmd_list(self):
        """List installed packages."""
        packages = self.load_state()
        print(f"📦 Installed packages ({self.name}):")
        for pkg, version in packages.items():
            print(f"  {pkg} v{version}")

    def cmd_outdated(self):
        """Show outdated packages."""
        packages = self.load_state()
        outdated = []

        for pkg, current_version in packages.items():
            latest_version = self.latest_versions.get(pkg, current_version)
            if current_version != latest_version:
                outdated.append((pkg, current_version, latest_version))
                print(f"{pkg} {current_version} < {latest_version}")

        if not outdated:
            print("All packages are up to date!")

        return len(outdated)

    def cmd_upgrade(self):
        """Upgrade packages."""
        packages = self.load_state()
        upgraded = []

        print(f"🔄 {self.name} upgrading packages...")

        for pkg, current_version in packages.items():
            latest_version = self.latest_versions.get(pkg, current_version)
            if current_version != latest_version:
                print(f"  📦 Upgrading {pkg} from {current_version} to {latest_version}...")
                packages[pkg] = latest_version
                upgraded.append(pkg)

        if upgraded:
            self.save_state(packages)
            print(f"✅ {self.name}: Upgraded {len(upgraded)} packages!")
        else:
            print(f"✅ {self.name}: All packages already up to date!")

        return len(upgraded)

    def run(self, command: str):
        """Execute a command."""
        if command == "version":
            self.cmd_version()
        elif command == "list":
            self.cmd_list()
        elif command == "outdated":
            return self.cmd_outdated()
        elif command == "upgrade":
            return self.cmd_upgrade()
        elif command == "reset":
            self.reset_state()
        else:
            self.show_help()

    def show_help(self):
        """Show help message."""
        print(f"{self.name} - A fake package manager for testing")
        print(f"Usage: {self.name.lower()} [version|list|outdated|upgrade|reset]")
        print()
        print("Commands:")
        print("  version   - Show PM version")
        print("  list      - List installed packages")
        print("  outdated  - Show outdated packages")
        print("  upgrade   - Upgrade all packages")
        print("  reset     - Reset to initial state")


class FakePM1(FakePM):
    """Fake Package Manager 1 implementation."""

    def __init__(self):
        super().__init__("FakePM1", "1.0.0")
        self.initial_packages = {
            "package-a": "1.0.0",
            "package-b": "2.3.4",
            "package-c": "0.1.0"
        }
        self.latest_versions = {
            "package-a": "1.1.0",
            "package-b": "3.0.0",
            "package-c": "0.1.0"  # Already latest
        }


class FakePM2(FakePM):
    """Fake Package Manager 2 implementation."""

    def __init__(self):
        super().__init__("FakePM2", "2.1.0")
        self.initial_packages = {
            "tool-x": "0.5.0",
            "tool-y": "1.2.3",
            "tool-z": "2.1.0"
        }
        self.latest_versions = {
            "tool-x": "0.5.0",    # Already latest
            "tool-y": "2.0.0",
            "tool-z": "2.1.0"     # Already latest
        }


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: fake_pm.py <pm1|pm2> <command>")
        sys.exit(1)

    pm_name = sys.argv[1]
    command = sys.argv[2] if len(sys.argv) > 2 else "help"

    if pm_name == "pm1":
        pm = FakePM1()
    elif pm_name == "pm2":
        pm = FakePM2()
    else:
        print(f"Unknown PM: {pm_name}")
        sys.exit(1)

    result = pm.run(command)

    # Return count for outdated/upgrade commands
    if isinstance(result, int):
        sys.exit(0 if result >= 0 else 1)


if __name__ == "__main__":
    main()
