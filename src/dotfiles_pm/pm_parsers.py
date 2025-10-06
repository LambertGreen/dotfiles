#!/usr/bin/env python3
"""
Package Manager Output Parsers

PM-specific logic for parsing check command output and counting outdated packages.

NOTE: This module provides functional wrappers around the OOP parser classes
defined in pm_base.py. New code should use the OOP classes directly.
"""

from typing import Dict, Callable


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


def parse_default_output(output: str) -> int:
    """
    Default parser - count non-empty lines as outdated packages.

    Args:
        output: Command output

    Returns:
        Number of non-empty lines
    """
    if not output:
        return 0

    lines = [line for line in output.split('\n') if line.strip()]
    return len(lines)


# Registry of PM-specific parsers
PM_PARSERS: Dict[str, Callable[[str], int]] = {
    'zinit': parse_zinit_status,
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
