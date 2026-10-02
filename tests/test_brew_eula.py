"""
Tests for HOMEBREW_ACCEPT_EULA on the brew install and upgrade workstreams.

Background (2026-10-02): `just upgrade` stalled on the work machine. The
microsoft/mssql-release formulae (msodbcsql18, mssql-tools18) read
`STDIN.gets` for a license prompt unless HOMEBREW_ACCEPT_EULA=Y is set. The
prompt sat in a spawned terminal too small to show it, so the run just looked
silent. Lambert accepted the EULA and chose to pre-accept it for all
dotfiles-driven brew runs, so unattended runs do not hang.

Like the SUDO_ASKPASS tests, these pin install and upgrade together so one
path cannot quietly lose it.
"""
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))

import sudo_helper  # noqa: E402

EULA = 'HOMEBREW_ACCEPT_EULA=Y'


class TestBrewUpgradeAcceptsEula:

    def test_gui_mode(self):
        from pms.brew import BrewPM
        with patch.object(sudo_helper, 'get_sudo_mode', return_value='gui'), \
             patch('sudo_helper.get_sudo_askpass_env',
                   return_value={'SUDO_ASKPASS': '/tmp/a.sh'}):
            cmd = BrewPM().upgrade_command
        assert f'{EULA} brew upgrade' in cmd[2]

    def test_tty_mode(self):
        from pms.brew import BrewPM
        with patch.object(sudo_helper, 'get_sudo_mode', return_value='tty'):
            cmd = BrewPM().upgrade_command
        assert cmd == ['env', EULA, 'brew', 'upgrade']


class TestBrewInstallAcceptsEula:

    def _install_cmd(self, tmp_path, package_type):
        from src.dotfiles_pm import pm_install

        (tmp_path / 'Brewfile').write_text('brew "sd"\n')
        captured = {}

        def fake_spawn(cmd_str, operation=None, auto_close=None):
            captured['cmd'] = cmd_str
            result = MagicMock()
            result.status = 'completed'
            return result

        with patch.object(pm_install, 'get_machine_config_dir', return_value=tmp_path), \
             patch.object(pm_install, 'spawn_tracked', side_effect=fake_spawn), \
             patch.object(pm_install, 'wrap_command_with_askpass',
                          side_effect=lambda c, reason='': c):
            pm_install.install_brew_packages(package_type)
        return captured.get('cmd', '')

    def test_all_packages(self, tmp_path):
        assert EULA in self._install_cmd(tmp_path, 'all')

    def test_formulas_only(self, tmp_path):
        cmd = self._install_cmd(tmp_path, 'formulas')
        assert EULA in cmd
        assert 'HOMEBREW_BUNDLE_CASK_SKIP=1' in cmd
