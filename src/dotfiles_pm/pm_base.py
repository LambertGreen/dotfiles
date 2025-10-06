#!/usr/bin/env python3
"""
Package Manager Base Classes

Defines the base architecture for package manager operations.
This is the foundation for migrating from procedural to OOP design.
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, List
from dataclasses import dataclass


@dataclass
class PMResult:
    """Result from a package manager operation"""
    success: bool
    output: str = ""
    error: str = ""
    outdated_count: int = 0
    exit_code: int = 0


class PMParser(ABC):
    """Base class for package manager output parsers"""

    @abstractmethod
    def count_outdated(self, output: str) -> int:
        """
        Count outdated packages from check command output.

        Args:
            output: Command output from check operation

        Returns:
            Number of outdated packages
        """
        pass


class DefaultParser(PMParser):
    """Default parser - counts non-empty lines"""

    def count_outdated(self, output: str) -> int:
        if not output:
            return 0
        lines = [line for line in output.split('\n') if line.strip()]
        return len(lines)


class ZinitParser(PMParser):
    """Parser for zinit status output"""

    def count_outdated(self, output: str) -> int:
        if not output:
            return 0
        # Count occurrences of "Your branch is behind"
        return output.count('Your branch is behind')


class PackageManager(ABC):
    """
    Base class for all package managers.

    Each PM implementation provides:
    - Commands for check/upgrade/install operations
    - Parser for interpreting check output
    - Metadata (sudo requirement, priority)
    """

    def __init__(self, name: str):
        self.name = name
        self._parser: PMParser = DefaultParser()

    @property
    @abstractmethod
    def check_command(self) -> List[str]:
        """Command to check for outdated packages"""
        pass

    @property
    @abstractmethod
    def upgrade_command(self) -> List[str]:
        """Command to upgrade packages"""
        pass

    @property
    @abstractmethod
    def install_command(self) -> List[str]:
        """Command to install packages"""
        pass

    @property
    @abstractmethod
    def requires_sudo(self) -> bool:
        """Whether this PM requires sudo privileges"""
        pass

    @property
    @abstractmethod
    def priority(self) -> int:
        """Execution priority (0=system, 10=user)"""
        pass

    @property
    def parser(self) -> PMParser:
        """Output parser for this PM"""
        return self._parser

    def parse_check_output(self, output: str) -> int:
        """
        Parse check command output to count outdated packages.

        Args:
            output: Command output

        Returns:
            Number of outdated packages
        """
        return self.parser.count_outdated(output)


class ZinitPM(PackageManager):
    """Zinit package manager (Zsh plugin manager)"""

    def __init__(self):
        super().__init__('zinit')
        self._parser = ZinitParser()

    @property
    def check_command(self) -> List[str]:
        return ["zsh -i -c 'zinit status --all'"]

    @property
    def upgrade_command(self) -> List[str]:
        return ["zsh -i -c 'zinit self-update && zinit update --all'"]

    @property
    def install_command(self) -> List[str]:
        return ["zsh -i -c 'true'"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 10


# Registry of PM instances (will grow as we migrate more PMs)
PM_REGISTRY: Dict[str, PackageManager] = {
    'zinit': ZinitPM(),
}


def get_pm(name: str) -> PackageManager:
    """
    Get package manager instance by name.

    Args:
        name: Package manager name

    Returns:
        PackageManager instance

    Raises:
        KeyError: If PM not found in registry
    """
    if name not in PM_REGISTRY:
        raise KeyError(f"Package manager '{name}' not registered")
    return PM_REGISTRY[name]
