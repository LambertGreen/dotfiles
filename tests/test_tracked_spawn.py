"""
Tests for the tracked-spawn command line and the "never started" guard.

Background (2026-10-31, personal; same root cause as work 2026-10-19): `just
upgrade` hung forever at the mas child. create_tracked_command wrapped the PM
command in double quotes, the mas upgrade script contains double quotes, so in
Terminal.app `(before upgrade):` ended up unquoted. zsh aborted the line with
"no matches found", run_tracked.sh never ran, no status file appeared, and the
poller treated "no status file" as "still running" with no timeout.

The existing mas tests ran the PM command directly, so they never saw the spawn
layer. These run the real spawn line through the real shells.
"""
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path
from unittest.mock import patch

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))

from src.dotfiles_pm import terminal_executor  # noqa: E402
from src.dotfiles_pm.terminal_executor import DarwinTerminalExecutor  # noqa: E402

# Everything that has bitten or could bite a quoted shell argument.
NASTY_COMMANDS = [
    # The 2026-10-31 mas upgrade script, shape for shape.
    'export SUDO_ASKPASS="/x/sudo-askpass.sh"; echo "==> mas outdated (before upgrade):"; '
    'outdated=$(mas outdated 2>&1); echo "${outdated:-(nothing outdated)}"; '
    'echo "==> mas upgrade"; mas upgrade; rc=$?; echo "==> mas upgrade exited $rc"; exit $rc',
    "bash -c 'echo it'\"'\"'s here'",
    'brew update && brew outdated --verbose',
    'echo back\\slash `uname` *.log ~ !bang',
]


@pytest.fixture
def capture_wrapper(tmp_path, temp_home):
    """A stand-in run_tracked.sh that records the argv it was given."""
    root = tmp_path / 'dotfiles'
    (root / 'scripts').mkdir(parents=True)
    out = tmp_path / 'argv.json'
    wrapper = root / 'scripts' / 'run_tracked.sh'
    wrapper.write_text(
        '#!/usr/bin/env python3\n'
        'import json, sys\n'
        f'json.dump(sys.argv[1:], open({str(out)!r}, "w"))\n'
    )
    wrapper.chmod(0o755)
    with patch.dict(terminal_executor.os.environ, {'DOTFILES_DIR': str(root)}):
        yield out


@pytest.mark.parametrize('shell', ['zsh', 'bash'])
@pytest.mark.parametrize('base_cmd', NASTY_COMMANDS)
def test_wrapper_receives_the_command_verbatim(shell, base_cmd, capture_wrapper):
    if not shutil.which(shell):
        pytest.skip(f'{shell} not installed')
    tracked, log_file, status_file = DarwinTerminalExecutor().create_tracked_command(base_cmd, 'mas-upgrade')

    r = subprocess.run([shell, '-f', '-c', tracked], capture_output=True, text=True)

    assert 'no matches found' not in r.stderr
    argv = json.loads(capture_wrapper.read_text())
    assert argv == ['mas-upgrade', base_cmd, log_file, status_file, 'false']


def test_real_mas_upgrade_command_survives_the_spawn_line(capture_wrapper):
    """The actual MasPM command, not a copy of it."""
    if not shutil.which('zsh'):
        pytest.skip('zsh not installed')
    from src.dotfiles_pm.pm_executor import get_pm_commands
    import shlex
    with patch('sudo_helper.get_sudo_askpass_env', return_value={'SUDO_ASKPASS': '/x/a.sh'}):
        base_cmd = shlex.join(get_pm_commands()['mas']['upgrade'])
    tracked, *_ = DarwinTerminalExecutor().create_tracked_command(base_cmd, 'mas-upgrade')

    subprocess.run(['zsh', '-f', '-c', tracked], capture_output=True, text=True)

    assert json.loads(capture_wrapper.read_text())[1] == base_cmd


def test_applescript_escaping_round_trips():
    """AppleScript string literals need backslashes escaped as well as quotes."""
    if not shutil.which('osascript'):
        pytest.skip('osascript not available')
    cmd = NASTY_COMMANDS[0] + ' ' + NASTY_COMMANDS[3]
    escaped = cmd.replace('\\', '\\\\').replace('"', '\\"')  # as DarwinTerminalExecutor.spawn
    r = subprocess.run(['osascript', '-e', f'return "{escaped}"'], capture_output=True, text=True)
    assert r.stdout.rstrip('\n') == cmd


class TestNeverStarted:
    def test_spawn_writes_a_spawned_status(self, temp_home):
        _, _, status_file = DarwinTerminalExecutor().create_tracked_command('true', 'op')
        assert json.loads(Path(status_file).read_text())['status'] == 'spawned'

    def test_fresh_spawn_counts_as_running(self, temp_home):
        ex = DarwinTerminalExecutor()
        _, _, status_file = ex.create_tracked_command('true', 'op')
        assert ex.check_status(status_file) == {'status': 'running'}

    def test_stale_spawn_is_an_error(self, temp_home):
        ex = DarwinTerminalExecutor()
        _, _, status_file = ex.create_tracked_command('true', 'mas-upgrade')
        old = time.time() - terminal_executor.SPAWN_START_TIMEOUT_SECS - 5
        Path(status_file).write_text(json.dumps(
            {'status': 'spawned', 'timestamp': int(old), 'operation': 'mas-upgrade'}))
        info = ex.check_status(status_file)
        assert info['status'] == 'error'
        assert 'mas-upgrade never started' in info['error']

    def test_started_run_is_not_timed_out(self, temp_home):
        """Once run_tracked.sh writes "running", a long run is never cut off."""
        ex = DarwinTerminalExecutor()
        _, _, status_file = ex.create_tracked_command('true', 'op')
        Path(status_file).write_text(json.dumps({'status': 'running', 'timestamp': 0}))
        assert ex.check_status(status_file)['status'] == 'running'

    def test_sequential_upgrade_gives_up_on_a_child_that_never_starts(self, temp_home):
        """The poller that hung: it must return a failure, not wait forever."""
        from src.dotfiles_pm import pm_upgrade
        ex = DarwinTerminalExecutor()
        _, log_file, status_file = ex.create_tracked_command('true', 'mas-upgrade')
        Path(status_file).write_text(json.dumps(
            {'status': 'spawned', 'timestamp': 0, 'operation': 'mas-upgrade'}))
        spawned = {'pm': 'mas', 'success': True, 'status_file': status_file, 'log_file': log_file}
        import threading
        results = []
        with patch.object(pm_upgrade, 'upgrade_pm_packages', return_value=spawned):
            # A regression is an infinite poll; fail the test instead of hanging the suite.
            t = threading.Thread(target=lambda: results.extend(
                pm_upgrade.upgrade_all_pms(['mas'], parallel=False)), daemon=True)
            t.start()
            t.join(timeout=10)
        assert not t.is_alive(), "upgrade_all_pms is still polling a child that never started"
        assert results[0]['success'] is False
        assert 'never started' in results[0]['error']
