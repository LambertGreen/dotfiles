"""
Tests for Windows elevation resolution (gsudo vs. native sudo).

On org-managed Windows machines, the native `sudo` (C:\\Windows\\System32\\sudo.exe)
is frequently disabled by policy ("Sudo is disabled by your organization's policy"),
while gsudo (installed via scoop) works. The elevation resolver in sudo_helper.py
prefers gsudo and falls back to native sudo, and ChocoPM uses it for its elevated
commands.

These tests mock shutil.which / the environment so they run on any platform
(including this Mac — choco/gsudo need not be installed).
"""
import pytest
from pathlib import Path
import sys
from unittest.mock import patch

# Add project root to path (match sibling test modules)
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))

import sudo_helper
from sudo_helper import (
    get_windows_elevation_binary,
    get_windows_elevation_command,
)
from pms.choco import ChocoPM


def _which_only(*available):
    """Build a shutil.which stub that resolves only the named binaries."""
    available = set(available)
    return lambda name: f'/fake/path/{name}' if name in available else None


class TestWindowsElevationBinary:
    """Resolve the elevation binary by preference: gsudo first, then sudo."""

    def test_prefers_gsudo_when_present(self):
        """When both gsudo and sudo exist, gsudo wins."""
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('gsudo', 'sudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            assert get_windows_elevation_binary() == 'gsudo'

    def test_prefers_gsudo_when_only_gsudo(self):
        """gsudo present, sudo absent -> gsudo."""
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('gsudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            assert get_windows_elevation_binary() == 'gsudo'

    def test_falls_back_to_sudo_when_gsudo_absent(self):
        """gsudo absent but sudo present -> sudo fallback."""
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('sudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            assert get_windows_elevation_binary() == 'sudo'

    def test_defaults_to_gsudo_when_neither_present(self):
        """Neither on PATH -> default to preferred (gsudo), let the command error clearly."""
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only()), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            assert get_windows_elevation_binary() == 'gsudo'

    def test_env_override_wins(self):
        """DOTFILES_WINDOWS_ELEVATION overrides PATH-based resolution."""
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('gsudo', 'sudo')), \
             patch.dict(sudo_helper.os.environ,
                        {'DOTFILES_WINDOWS_ELEVATION': 'mysudo'}, clear=False):
            assert get_windows_elevation_binary() == 'mysudo'


class TestWindowsElevationCommand:
    """Prefixing a command with the resolved elevation binary."""

    def test_prefixes_with_gsudo(self):
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('gsudo', 'sudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            assert get_windows_elevation_command(['choco', 'upgrade', 'all', '-y']) == \
                ['gsudo', 'choco', 'upgrade', 'all', '-y']

    def test_prefixes_with_sudo_fallback(self):
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('sudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            assert get_windows_elevation_command(['choco', 'install', '-y']) == \
                ['sudo', 'choco', 'install', '-y']


class TestChocoElevation:
    """ChocoPM's elevated commands use the resolved binary; check stays unelevated."""

    def test_upgrade_uses_gsudo_when_present(self):
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('gsudo', 'sudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            pm = ChocoPM()
            assert pm.upgrade_command == ['gsudo', 'choco', 'upgrade', 'all', '-y']

    def test_install_uses_gsudo_when_present(self):
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('gsudo', 'sudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            pm = ChocoPM()
            assert pm.install_command == ['gsudo', 'choco', 'install', '-y']

    def test_upgrade_falls_back_to_sudo(self):
        """gsudo absent (e.g. not installed) but sudo present -> sudo."""
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('sudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            pm = ChocoPM()
            assert pm.upgrade_command == ['sudo', 'choco', 'upgrade', 'all', '-y']

    def test_install_falls_back_to_sudo(self):
        with patch.object(sudo_helper.shutil, 'which',
                          side_effect=_which_only('sudo')), \
             patch.dict(sudo_helper.os.environ, {}, clear=False):
            sudo_helper.os.environ.pop('DOTFILES_WINDOWS_ELEVATION', None)
            pm = ChocoPM()
            assert pm.install_command == ['sudo', 'choco', 'install', '-y']

    def test_check_command_is_not_elevated(self):
        """`choco outdated` is read-only and must never be prefixed with elevation."""
        pm = ChocoPM()
        assert pm.check_command == ['choco', 'outdated']
        assert pm.check_command[0] not in ('gsudo', 'sudo')

    def test_choco_still_requires_sudo_metadata(self):
        """requires_sudo metadata is unchanged by the elevation-binary refactor."""
        pm = ChocoPM()
        assert pm.requires_sudo is True


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
