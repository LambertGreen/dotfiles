"""
Tests for SUDO_ASKPASS wiring on the install workstream.

Background (2026-08-26): `just install` wedged indefinitely. `brew bundle`
reached a `mas` entry ("Windows App"), `mas` re-exec'd itself under plain
`sudo`, and with no TTY and no SUDO_ASKPASS configured there was nothing to
answer the password prompt. It sat for 10h44m consuming 0.29s of CPU, blocking
every remaining Brewfile entry. Each retry spawned a fresh sudo, so killing the
process did not help.

The upgrade workstream already configured SUDO_ASKPASS (BrewPM.upgrade_command,
BrewCaskPM.upgrade_command); install did not. Per sudo(8), SUDO_ASKPASS is used
"if no terminal is available or if the -A option is specified" -- which is
exactly the non-interactive case that hung.

These tests pin the fix and, importantly, the SYMMETRY: install and upgrade must
both be wrapped, so the asymmetry cannot quietly come back.
"""
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

# Match sibling test modules.
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))

import sudo_helper  # noqa: E402
from sudo_helper import wrap_command_with_askpass  # noqa: E402


class TestWrapCommandWithAskpass:
    """The helper itself."""

    def test_gui_mode_prefixes_export(self):
        with patch.object(sudo_helper, 'get_sudo_askpass_env',
                          return_value={'SUDO_ASKPASS': '/tmp/askpass.sh'}):
            wrapped = wrap_command_with_askpass('brew bundle install', reason='r')
        assert wrapped.startswith('export SUDO_ASKPASS="/tmp/askpass.sh";')
        assert wrapped.endswith('brew bundle install')

    def test_tty_mode_is_a_noop(self):
        """No display -> no wrapping, so terminal prompts behave as before."""
        with patch.object(sudo_helper, 'get_sudo_askpass_env', return_value={}):
            assert wrap_command_with_askpass('brew bundle install') == 'brew bundle install'

    def test_skip_mode_is_a_noop(self):
        with patch.dict(sudo_helper.os.environ, {'DOTFILES_SUDO_MODE': 'skip'}):
            assert wrap_command_with_askpass('brew bundle install') == 'brew bundle install'


class TestInstallUsesAskpass:
    """The regression: the install command must carry SUDO_ASKPASS."""

    def _run_install_capturing_cmd(self, tmp_path):
        """Invoke install_brew_packages and return the command string it built."""
        from src.dotfiles_pm import pm_install

        brewfile = tmp_path / 'Brewfile'
        brewfile.write_text('brew "sd"\nmas "Windows App", id: 1295203466\n')

        captured = {}

        def fake_spawn(cmd_str, operation=None, auto_close=None):
            captured['cmd'] = cmd_str
            result = MagicMock()
            result.status = 'completed'
            result.log_file = '/tmp/log'
            result.status_file = '/tmp/status'
            return result

        with patch.object(pm_install, 'get_machine_config_dir', return_value=tmp_path), \
             patch.object(pm_install, 'spawn_tracked', side_effect=fake_spawn), \
             patch.object(pm_install, 'wrap_command_with_askpass',
                          side_effect=lambda c, reason='': f'export SUDO_ASKPASS="/x"; {c}'):
            pm_install.install_brew_packages('all')

        return captured.get('cmd', '')

    def test_install_command_is_wrapped(self, tmp_path):
        cmd = self._run_install_capturing_cmd(tmp_path)
        assert 'SUDO_ASKPASS' in cmd, (
            "brew bundle install must be wrapped with SUDO_ASKPASS; without it a "
            "non-interactive run blocks forever on the first mas entry"
        )

    def test_install_still_targets_the_brewfile(self, tmp_path):
        """Wrapping must not disturb the actual command."""
        cmd = self._run_install_capturing_cmd(tmp_path)
        assert 'brew bundle install' in cmd
        assert '--file=' in cmd
        assert '--no-upgrade' in cmd

    def test_end_to_end_with_the_real_helper(self, tmp_path, temp_home):
        """
        The stronger assertion: no mocking of the wrapper. Force GUI mode and
        confirm install really emits the export AND that the askpass helper
        script is created (isolated to a temp HOME so we do not touch the real
        ~/.dotfiles/bin).
        """
        from src.dotfiles_pm import pm_install

        brewfile = tmp_path / 'Brewfile'
        brewfile.write_text('mas "Windows App", id: 1295203466\n')

        captured = {}

        def fake_spawn(cmd_str, operation=None, auto_close=None):
            captured['cmd'] = cmd_str
            result = MagicMock()
            result.status = 'completed'
            return result

        with patch.object(pm_install, 'get_machine_config_dir', return_value=tmp_path), \
             patch.object(pm_install, 'spawn_tracked', side_effect=fake_spawn), \
             patch.dict(sudo_helper.os.environ, {'DOTFILES_SUDO_MODE': 'gui'}), \
             patch.object(sudo_helper.platform, 'system', return_value='Darwin'):
            pm_install.install_brew_packages('all')

        cmd = captured.get('cmd', '')
        assert 'export SUDO_ASKPASS=' in cmd
        assert 'brew bundle install' in cmd

        helper = Path(temp_home) / '.dotfiles' / 'bin' / 'sudo-askpass.sh'
        assert helper.exists(), "askpass helper script should have been created"
        assert 'osascript' in helper.read_text()


class TestInstallUpgradeSymmetry:
    """
    The bug was an asymmetry: upgrade configured askpass, install did not.
    Assert both, so re-introducing the gap fails a test.
    """

    def test_brew_upgrade_is_wrapped_in_gui_mode(self):
        from pms.brew import BrewPM
        with patch.object(sudo_helper, 'get_sudo_mode', return_value='gui'), \
             patch('sudo_helper.get_sudo_askpass_env',
                   return_value={'SUDO_ASKPASS': '/tmp/a.sh'}):
            cmd = BrewPM().upgrade_command
        assert cmd[0] == 'bash' and 'SUDO_ASKPASS' in cmd[2]

    def test_install_actually_calls_the_askpass_helper(self):
        """
        install_brew_packages must CALL the same helper the upgrade path uses.

        Checks for the call form specifically, with comments stripped: an
        earlier version of this test matched a bare mention and so passed even
        with the call deleted, because the surrounding comment still named it.
        """
        import inspect
        from src.dotfiles_pm import pm_install
        src = inspect.getsource(pm_install.install_brew_packages)
        code = '\n'.join(
            line for line in src.splitlines()
            if not line.lstrip().startswith('#')
        )
        assert 'wrap_command_with_askpass(' in code


class TestSudoModeOverride:
    def test_explicit_override_wins(self):
        for mode in ('gui', 'tty', 'skip'):
            with patch.dict(sudo_helper.os.environ, {'DOTFILES_SUDO_MODE': mode}):
                assert sudo_helper.get_sudo_mode() == mode

    def test_no_askpass_env_in_tty_mode(self):
        with patch.dict(sudo_helper.os.environ, {'DOTFILES_SUDO_MODE': 'tty'}):
            assert sudo_helper.get_sudo_askpass_env('reason') == {}
