#!/usr/bin/env python3
"""
Package Manager Base Classes

Defines the base architecture for package manager operations.
"""

from abc import ABC, abstractmethod
from typing import List
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
