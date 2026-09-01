#!/usr/bin/env python3
"""
Package Manager Base Classes

Defines the base architecture for package manager operations.
"""

import re
from abc import ABC, abstractmethod
from typing import List, Optional
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
    def count_outdated(self, output: Optional[str]) -> int:
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

    def count_outdated(self, output: Optional[str]) -> int:
        if not output:
            return 0
        lines = [line for line in output.split('\n') if line.strip()]
        return len(lines)


# Lines a PM emits that are progress/diagnostic noise rather than packages.
# Check output is captured with stderr merged in, so warnings land here too.
_NOISE_PREFIXES = (
    '==>',        # brew phase banners
    '✔',          # brew API download ticks
    '✖',
    'Warning:',   # e.g. NODE_EXTRA_CA_CERTS pointing at a missing file
    'Error:',
    'npm warn',
    'npm notice',
    'npm error',
)


def _is_noise(line: str) -> bool:
    """True if a line is progress/diagnostic output rather than a package."""
    return line.startswith(_NOISE_PREFIXES)


# A `brew outdated --verbose` row, for formulae and casks respectively:
#   ast-grep (0.45.2) < 0.45.3
#   claude (1.40609.0,f65e386…) != 1.40609.1,69aac03…
# The `(version)` followed by `<` or `!=` is what separates a real row from
# `brew update` chatter such as "Updated 2 taps (homebrew/core and …)."
_BREW_OUTDATED_ROW = re.compile(r'^\S+ \(.+?\) (?:<|!=) \S')


class BrewOutdatedParser(PMParser):
    """
    Parser for `brew update && brew outdated --verbose`.

    Counts only genuine outdated rows. The check command runs `brew update`
    first, so its output is dominated by update chatter — phase banners, tap
    counts, and the full "New Formulae"/"New Casks" listings. Counting lines
    reports those as outdated packages; notably a no-op check still emits
    three lines ("Updating Homebrew…", "Updated Homebrew from…", "No changes
    to formulae or casks.") and would be reported as 3 outdated packages.
    """

    def count_outdated(self, output: Optional[str]) -> int:
        if not output:
            return 0
        return sum(
            1 for line in output.split('\n')
            if _BREW_OUTDATED_ROW.match(line.strip())
        )


class BrewCaskParser(PMParser):
    """
    Parser for `brew outdated --cask --greedy` (one cask name per line).

    Skips the API-download progress lines brew prints before the list.
    """

    def count_outdated(self, output: Optional[str]) -> int:
        if not output:
            return 0
        return sum(
            1 for line in (raw.strip() for raw in output.split('\n'))
            if line and not _is_noise(line)
        )


class NpmParser(PMParser):
    """
    Parser for `npm outdated -g`.

    npm prints a table with a `Package  Current  Wanted  Latest …` header, and
    prints *nothing* when everything is current. So the header is the signal:
    with no header there are no outdated packages, regardless of how many
    warning lines npm wrote to stderr.
    """

    def count_outdated(self, output: Optional[str]) -> int:
        if not output:
            return 0

        lines = [raw.rstrip() for raw in output.split('\n')]
        for i, line in enumerate(lines):
            fields = line.split()
            if fields[:2] == ['Package', 'Current']:
                rows = lines[i + 1:]
                break
        else:
            return 0

        return sum(
            1 for line in (row.strip() for row in rows)
            if line and not _is_noise(line)
        )


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

    def parse_check_output(self, output: Optional[str]) -> int:
        """
        Parse check command output to count outdated packages.

        Args:
            output: Command output

        Returns:
            Number of outdated packages
        """
        return self.parser.count_outdated(output)
