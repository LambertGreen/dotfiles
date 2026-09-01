#!/usr/bin/env python3
"""
Package Manager Output Parsers

PM-specific logic for parsing check command output and counting outdated packages.

NOTE: This module provides functional wrappers around the OOP parser classes
defined in pm_base.py. New code should use the OOP classes directly.
"""

from typing import Dict, Callable

from pm_base import BrewCaskParser, BrewOutdatedParser, DefaultParser, NpmParser


def parse_zinit_status(output: str) -> int:
    """
    Parse zinit status --all output to count plugins needing updates.

    zinit status shows git status for each plugin. Look for indicators:
    - "Your branch is behind 'origin/master'" - plugin needs update
    - "Your branch is up to date" - no update needed

    Args:
        output: Output from 'zinit status --all'

    Returns:
        Number of plugins that need updates (behind origin)
    """
    if not output:
        return 0

    # Count occurrences of "Your branch is behind"
    return output.count('Your branch is behind')


def parse_brew_output(output: str) -> int:
    """Parse `brew update && brew outdated --verbose` output."""
    return BrewOutdatedParser().count_outdated(output)


def parse_brew_cask_output(output: str) -> int:
    """Parse brew outdated --cask --greedy output (one package per line)."""
    return BrewCaskParser().count_outdated(output)


def parse_npm_output(output: str) -> int:
    """Parse `npm outdated -g` table output."""
    return NpmParser().count_outdated(output)


def parse_default_output(output: str) -> int:
    """
    Default parser - count non-empty lines as outdated packages.

    Args:
        output: Command output

    Returns:
        Number of non-empty lines
    """
    return DefaultParser().count_outdated(output)


# Registry of PM-specific parsers. Must stay in step with the `_parser` each
# PackageManager wires up in pms/ — both routes go through the same classes so
# the functional and OOP paths cannot report different counts.
PM_PARSERS: Dict[str, Callable[[str], int]] = {
    'zinit': parse_zinit_status,
    'brew': parse_brew_output,
    'brew-cask': parse_brew_cask_output,
    'npm': parse_npm_output,
}


def parse_pm_output(pm_name: str, output: str) -> int:
    """
    Parse PM check output to count outdated packages.

    Uses PM-specific parser if available, otherwise falls back to default.

    Args:
        pm_name: Package manager name
        output: Command output from check operation

    Returns:
        Number of outdated packages
    """
    parser = PM_PARSERS.get(pm_name, parse_default_output)
    return parser(output)
