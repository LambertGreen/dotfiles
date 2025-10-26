#!/usr/bin/env python3
"""
Command Executor Module

Transparent subprocess execution with command visibility.
"""

import subprocess
from typing import List, Dict, Any, Optional


def run_command(cmd: List[str], timeout: int = 30, capture_output: bool = True) -> subprocess.CompletedProcess:
    """
    Run command with full transparency.

    Args:
        cmd: Command list to execute
        timeout: Command timeout in seconds
        capture_output: Whether to capture output

    Returns:
        CompletedProcess result
    """
    cmd_str = ' '.join(cmd)
    print(f"  💻 Command: {cmd_str}")

    return subprocess.run(
        cmd,
        capture_output=capture_output,
        text=True,
        timeout=timeout
    )
