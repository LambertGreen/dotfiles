#!/usr/bin/env python3
"""Mac App Store Package Manager"""

from typing import List
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from pm_base import PackageManager


class MasPM(PackageManager):
    """Mac App Store package manager"""

    def __init__(self):
        super().__init__('mas')

    @property
    def check_command(self) -> List[str]:
        return ["mas", "outdated"]

    @property
    def upgrade_command(self) -> List[str]:
        # Bare `mas upgrade` prints nothing when nothing is outdated, so on
        # 2026-10-05 a 0-byte log could not be told apart from a skipped run.
        # Log what was outdated before, and the exit status after.
        #
        # mas re-execs itself under sudo, which needs a TTY or SUDO_ASKPASS
        # (2026-10-02 work: "sudo: a terminal is required"). Wrap it the way
        # pm_install wraps `brew bundle`; the askpass dialog times out.
        from sudo_helper import wrap_command_with_askpass
        script = (
            'echo "==> mas outdated (before upgrade):"; '
            'outdated=$(mas outdated 2>&1); echo "${outdated:-(nothing outdated)}"; '
            'echo "==> mas upgrade"; mas upgrade; rc=$?; '
            'echo "==> mas upgrade exited $rc"; exit $rc'
        )
        return ["bash", "-c", wrap_command_with_askpass(
            script, reason="Mac App Store needs to update apps")]

    @property
    def install_command(self) -> List[str]:
        return ["mas", "install"]

    @property
    def requires_sudo(self) -> bool:
        return False

    @property
    def priority(self) -> int:
        return 15  # Higher priority than npm/pip (system apps are important for security)
