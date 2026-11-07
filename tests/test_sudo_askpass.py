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

        helper = sudo_helper._get_askpass_path(
            "Homebrew Bundle is installing App Store apps and system-linked packages")
        assert helper.parent == Path(temp_home) / '.dotfiles' / 'bin'
        assert helper.exists(), "askpass helper script should have been created"
        assert 'osascript' in helper.read_text()
        assert f'export SUDO_ASKPASS="{helper}"' in cmd


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


class TestMasUpgrade:
    """mas upgrade logs even when idle (2026-10-05) and can reach sudo (2026-10-02)."""

    def _cmd(self):
        from pms.mas import MasPM
        with patch('sudo_helper.get_sudo_askpass_env',
                   return_value={'SUDO_ASKPASS': '/tmp/a.sh'}):
            return MasPM().upgrade_command

    def test_wrapped_with_askpass(self):
        cmd = self._cmd()
        assert cmd[:2] == ['bash', '-c']
        assert cmd[2].startswith('export SUDO_ASKPASS="/tmp/a.sh";')

    def test_idle_run_still_writes_a_log(self, tmp_path):
        """With nothing outdated the log says so, plus the exit status."""
        bin_dir = tmp_path / 'bin'
        bin_dir.mkdir()
        stub = bin_dir / 'mas'
        stub.write_text('#!/bin/bash\nexit 0\n')  # outdated and upgrade print nothing
        stub.chmod(0o755)
        import subprocess
        r = subprocess.run(self._cmd(), capture_output=True, text=True,
                           env={'PATH': f'{bin_dir}:/usr/bin:/bin'})
        assert r.returncode == 0
        assert '(nothing outdated)' in r.stdout
        assert '==> mas upgrade exited 0' in r.stdout

    def _stubs(self, tmp_path, sudo_exit=0):
        """mas reports one app outdated; sudo records how it was called."""
        bin_dir = tmp_path / 'bin'
        bin_dir.mkdir()
        calls = tmp_path / 'calls'
        (bin_dir / 'mas').write_text(
            f'#!/bin/bash\necho "mas $*" >> {calls}\n'
            '[ "$1" = outdated ] && echo "402592703  Time Out  (3.1 -> 4.0)"\nexit 0\n')
        (bin_dir / 'sudo').write_text(f'#!/bin/bash\necho "sudo $*" >> {calls}\nexit {sudo_exit}\n')
        for f in bin_dir.iterdir():
            f.chmod(0o755)
        return bin_dir, calls

    def test_authenticates_with_askpass_before_mas_sudo(self, tmp_path):
        """2026-10-31: mas's own sudo ignores SUDO_ASKPASS in a terminal with a TTY."""
        bin_dir, calls = self._stubs(tmp_path)
        import subprocess
        r = subprocess.run(self._cmd(), capture_output=True, text=True,
                           env={'PATH': f'{bin_dir}:/usr/bin:/bin'})
        assert r.returncode == 0
        lines = calls.read_text().splitlines()
        assert lines == ['mas outdated', 'sudo -A -v', 'mas upgrade']

    def test_failed_authentication_skips_the_upgrade(self, tmp_path):
        bin_dir, calls = self._stubs(tmp_path, sudo_exit=1)
        import subprocess
        r = subprocess.run(self._cmd(), capture_output=True, text=True,
                           env={'PATH': f'{bin_dir}:/usr/bin:/bin'})
        assert r.returncode == 1
        assert 'mas upgrade skipped' in r.stdout
        assert 'mas upgrade' not in calls.read_text().splitlines()

    def test_upgrade_failure_propagates(self, tmp_path):
        bin_dir = tmp_path / 'bin'
        bin_dir.mkdir()
        stub = bin_dir / 'mas'
        stub.write_text('#!/bin/bash\n[ "$1" = upgrade ] && exit 3\nexit 0\n')
        stub.chmod(0o755)
        import subprocess
        r = subprocess.run(self._cmd(), capture_output=True, text=True,
                           env={'PATH': f'{bin_dir}:/usr/bin:/bin'})
        assert r.returncode == 3
        assert '==> mas upgrade exited 3' in r.stdout


class TestAskpassTimeout:
    """The macOS dialog is bounded, so an unattended run cannot wait forever (2026-09-01)."""

    def test_dialog_gives_up_and_fails(self, temp_home):
        with patch.object(sudo_helper.platform, 'system', return_value='Darwin'):
            path = sudo_helper._ensure_macos_askpass('reason')
        script = Path(path).read_text()
        assert f'giving up after {sudo_helper.ASKPASS_TIMEOUT_SECS}' in script
        # A give-up must fail sudo, not hand it an empty password to retry.
        assert 'if gave up of r then error' in script
        assert sudo_helper.ASKPASS_TIMEOUT_SECS <= 600


class TestAskpassPerReason:
    """One script per reason, so a dialog says who is asking (2026-10-31)."""

    def test_reasons_get_separate_scripts(self, temp_home):
        with patch.object(sudo_helper.platform, 'system', return_value='Darwin'):
            cask = sudo_helper._ensure_macos_askpass('Homebrew Cask needs to install/update apps')
            mas = sudo_helper._ensure_macos_askpass('Mac App Store needs to update apps')
        assert cask != mas
        # Writing mas's script last must not change what the cask dialog says.
        assert 'Homebrew Cask needs' in Path(cask).read_text()
        assert 'Mac App Store' not in Path(cask).read_text()

    def test_every_pm_reason_is_distinct(self):
        reasons = [
            "Homebrew needs to update system-linked packages",
            "Homebrew Cask needs to install/update apps in /Applications",
            "Mac App Store needs to update apps",
            "Homebrew Bundle is installing App Store apps and system-linked packages",
        ]
        assert len({sudo_helper._get_askpass_path(r).name for r in reasons}) == len(reasons)

    def test_no_reason_keeps_the_legacy_name(self):
        assert sudo_helper._get_askpass_path('').name == 'sudo-askpass.sh'


class TestAskpassFailsFastAfterDecline:
    """One timeout/Cancel stops the dialogs for that script (2026-10-31: 4×300s for one cask)."""

    def _script_with_stub(self, temp_home, tmp_path, osascript_body):
        calls = tmp_path / 'osascript-calls'
        stub = tmp_path / 'osascript'
        stub.write_text(f'#!/bin/bash\necho x >> {calls}\n{osascript_body}\n')
        stub.chmod(0o755)
        with patch.object(sudo_helper, '_OSASCRIPT', str(stub)), \
             patch.object(sudo_helper.platform, 'system', return_value='Darwin'):
            script = sudo_helper._ensure_macos_askpass('reason')
        return script, calls

    def _ask(self, script):
        import subprocess
        return subprocess.run([script, 'Password:'], capture_output=True, text=True)

    def test_second_prompt_fails_without_a_dialog(self, temp_home, tmp_path):
        script, calls = self._script_with_stub(temp_home, tmp_path, 'exit 1')
        assert self._ask(script).returncode == 1
        r = self._ask(script)
        assert r.returncode == 1
        assert 'failing fast' in r.stderr
        assert calls.read_text().count('x') == 1, "the dialog must not be shown again"

    def test_answered_prompt_keeps_asking(self, temp_home, tmp_path):
        script, calls = self._script_with_stub(temp_home, tmp_path, 'echo hunter2')
        for _ in range(2):
            r = self._ask(script)
            assert r.returncode == 0 and r.stdout.strip() == 'hunter2'
        assert calls.read_text().count('x') == 2

    def test_regenerating_clears_the_decline(self, temp_home, tmp_path):
        script, calls = self._script_with_stub(temp_home, tmp_path, 'exit 1')
        self._ask(script)
        script, _ = self._script_with_stub(temp_home, tmp_path, 'exit 1')
        self._ask(script)
        assert calls.read_text().count('x') == 2, "a new run must get a fresh dialog"


class TestSudoModeOverride:
    def test_explicit_override_wins(self):
        for mode in ('gui', 'tty', 'skip'):
            with patch.dict(sudo_helper.os.environ, {'DOTFILES_SUDO_MODE': mode}):
                assert sudo_helper.get_sudo_mode() == mode

    def test_no_askpass_env_in_tty_mode(self):
        with patch.dict(sudo_helper.os.environ, {'DOTFILES_SUDO_MODE': 'tty'}):
            assert sudo_helper.get_sudo_askpass_env('reason') == {}
