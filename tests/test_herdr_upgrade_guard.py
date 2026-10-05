"""
Tests for the herdr upgrade guard (ai_council backlog #3).

Background (2026-10-03): `just upgrade` ran a bare `brew upgrade`. It took the
herdr client 0.8.2 → 0.9.3 (protocol 20 → 22) under a live protocol-20 server,
and every herdr call failed until `herdr server stop`, which kills every pane.

Now:
  - `just upgrade` (BrewPM.upgrade_command → herdr_guard.py brew-upgrade) holds
    herdr back while any herdr server is live, says so loudly, and names
    `just herdr-upgrade`;
  - `just herdr-upgrade` (herdr-upgrade.sh) is the deliberate path: it refuses
    to run without a TTY or inside herdr, asks for confirmation, then does
    upgrade → server stop → `ai_council`.

Everything runs the real code against stub `herdr`, `brew` and `ai_council`
on PATH. The real herdr server is never touched.
"""
import json
import os
import pty
import subprocess
import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
GUARD = PROJECT_ROOT / 'src' / 'dotfiles_pm' / 'herdr_guard.py'
RECIPE = PROJECT_ROOT / 'scripts' / 'package-management' / 'herdr' / 'herdr-upgrade.sh'

# Every stub appends one line ("<tool> <argv...>") to $STUB_LOG.
HERDR_STUB = """#!/bin/bash
echo "herdr $*" >> "$STUB_LOG"
if [ "$1" = "--session" ]; then session="$2"; shift 2; fi
case "$*" in
  "session list --json")
    [ -n "$STUB_SESSIONS_FAIL" ] && exit 1
    echo "$STUB_SESSIONS" ;;
  "status server --json")
    case " $STUB_SKEWED " in
      *" $session "*) echo '{"running":true,"compatible":false}' ;;
      *)              echo '{"running":true,"compatible":true}' ;;
    esac ;;
  "--version") echo "herdr 0.8.2" ;;
  "server stop") ;;
esac
"""

BREW_STUB = """#!/bin/bash
echo "brew $*" >> "$STUB_LOG"
case "$1" in
  outdated)
    if [ "$2" = "--json=v2" ]; then
      [ -n "$STUB_OUTDATED_FAIL" ] && exit 1
      echo "==> Auto-updating Homebrew..."
      # After an upgrade, report the post-upgrade state when the test sets one.
      if [ -f "$STUB_LOG.upgraded" ] && [ -n "${STUB_OUTDATED_AFTER+x}" ]; then
        echo "$STUB_OUTDATED_AFTER"
      else
        echo "$STUB_OUTDATED"
      fi
    else
      [ -n "$STUB_HERDR_OUTDATED" ] && { echo herdr; exit 1; }
    fi ;;
  upgrade)
    echo "env EULA=$HOMEBREW_ACCEPT_EULA NO_AUTO_UPDATE=$HOMEBREW_NO_AUTO_UPDATE" >> "$STUB_LOG"
    touch "$STUB_LOG.upgraded"
    [ -n "$STUB_UPGRADE_OUTPUT" ] && echo "$STUB_UPGRADE_OUTPUT"
    [ -n "$STUB_UPGRADE_FAIL" ] && exit 1 ;;
esac
exit 0
"""

AI_COUNCIL_STUB = """#!/bin/bash
echo "ai_council $*" >> "$STUB_LOG"
"""


def _sessions(**running):
    return json.dumps({'sessions': [
        {'name': name, 'running': up} for name, up in running.items()]})


def _formula(name, installed, current, pinned=False):
    return {'name': name, 'installed_versions': [installed],
            'current_version': current, 'pinned': pinned}


OUTDATED = json.dumps({
    'formulae': [_formula('herdr', '0.8.2', '0.9.3'),
                 _formula('ripgrep', '14.0', '14.1'),
                 _formula('pinned-thing', '1.0', '2.0', pinned=True)],
    'casks': [_formula('blender', '5.2.1', '5.2.2')],
})


def _write_exe(path, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)
    path.chmod(0o755)


@pytest.fixture
def stubs(tmp_path):
    """Stub bin dir + env; PATH holds only stubs and system dirs (no real brew/herdr)."""
    bin_dir = tmp_path / 'bin'
    _write_exe(bin_dir / 'brew', BREW_STUB)
    _write_exe(bin_dir / 'herdr', HERDR_STUB)
    _write_exe(bin_dir / 'ai_council', AI_COUNCIL_STUB)
    (bin_dir / 'python3').symlink_to(sys.executable)
    log = tmp_path / 'calls.log'
    log.touch()
    env = {
        'HOME': str(tmp_path),
        'PATH': f'{bin_dir}:/usr/bin:/bin',
        'STUB_LOG': str(log),
        'STUB_SESSIONS': _sessions(default=False, council=True),
        'STUB_OUTDATED': OUTDATED,
        'STUB_HERDR_OUTDATED': '1',
    }

    class Stubs:
        def __init__(self):
            self.bin, self.env = bin_dir, env

        def calls(self):
            return log.read_text().splitlines()

        def upgrades(self):
            return [c for c in self.calls() if c.startswith('brew upgrade')]

    return Stubs()


def _guard(stubs, *args):
    return subprocess.run([sys.executable, str(GUARD), *args], env=stubs.env,
                          capture_output=True, text=True)


class TestRoutineUpgradeGuard:
    """`just upgrade`'s brew step: herdr_guard.py brew-upgrade."""

    def test_herdr_not_installed_runs_plain_brew_upgrade(self, stubs):
        (stubs.bin / 'herdr').unlink()
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        assert stubs.upgrades() == ['brew upgrade']

    def test_no_live_server_runs_plain_brew_upgrade(self, stubs):
        # Nothing to break: herdr upgrades with everything else.
        stubs.env['STUB_SESSIONS'] = _sessions(default=False, council=False)
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        assert stubs.upgrades() == ['brew upgrade']
        assert 'HELD BACK' not in r.stderr

    def test_live_server_holds_herdr_back_loudly(self, stubs):
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        # herdr and pinned formulae are left out; casks still upgrade.
        assert stubs.upgrades() == ['brew upgrade ripgrep blender']
        assert 'env EULA= NO_AUTO_UPDATE=1' in stubs.calls()
        assert 'HERDR HELD BACK: 0.8.2 -> 0.9.3 NOT upgraded.' in r.stderr
        assert 'Live herdr session(s): council.' in r.stderr
        assert 'just herdr-upgrade' in r.stderr

    def test_live_server_herdr_current_still_uses_explicit_targets(self, stubs):
        # A bare `brew upgrade` would auto-update first and could pick up a
        # brand-new herdr release; explicit names cannot.
        stubs.env['STUB_OUTDATED'] = json.dumps(
            {'formulae': [_formula('ripgrep', '14.0', '14.1')], 'casks': []})
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        assert stubs.upgrades() == ['brew upgrade ripgrep']
        assert 'HELD BACK' not in r.stderr

    def test_only_herdr_outdated_upgrades_nothing(self, stubs):
        stubs.env['STUB_OUTDATED'] = json.dumps(
            {'formulae': [_formula('herdr', '0.8.2', '0.9.3')], 'casks': []})
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        assert stubs.upgrades() == []
        assert 'HERDR HELD BACK' in r.stderr
        assert 'nothing else to upgrade' in r.stderr

    def test_unknown_session_state_is_treated_as_live(self, stubs):
        stubs.env['STUB_SESSIONS_FAIL'] = '1'
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        assert stubs.upgrades() == ['brew upgrade ripgrep blender']
        assert 'unknown (`herdr session list` failed)' in r.stderr

    def test_live_server_and_brew_outdated_failure_refuses(self, stubs):
        stubs.env['STUB_OUTDATED_FAIL'] = '1'
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 1
        assert stubs.upgrades() == []
        assert 'Not running `brew upgrade`' in r.stderr

    def test_existing_protocol_skew_is_reported(self, stubs):
        # The 2026-10-03 state: client already newer than the running server.
        stubs.env['STUB_SKEWED'] = 'council'
        r = _guard(stubs, 'brew-upgrade')
        assert 'HERDR PROTOCOL SKEW: session(s) council' in r.stderr

    def test_status_names_the_deliberate_path(self, stubs):
        r = _guard(stubs, 'status')
        assert r.returncode == 0, r.stderr
        assert 'live sessions: council' in r.stdout
        assert '0.8.2 -> 0.9.3 available; held back by `just upgrade`; ' \
               'run `just herdr-upgrade`' in r.stdout
        assert stubs.upgrades() == []


class TestBrewPMUsesGuard:
    """The command `just upgrade` actually spawns goes through the guard."""

    def test_tty_mode_command_holds_herdr(self, stubs, monkeypatch):
        sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))
        import sudo_helper
        from pms.brew import BrewPM
        monkeypatch.setattr(sudo_helper, 'get_sudo_mode', lambda: 'tty')
        cmd = BrewPM().upgrade_command
        assert cmd[:2] == ['env', 'HOMEBREW_ACCEPT_EULA=Y']
        r = subprocess.run(cmd, env=stubs.env, capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        assert stubs.upgrades() == ['brew upgrade ripgrep blender']
        assert 'env EULA=Y NO_AUTO_UPDATE=1' in stubs.calls()


class TestUpgradeResultCheck:
    """brew's exit status is checked against what is still outdated (2026-10-05).

    That run's whatsapp pre-download failed with a curl HTTP/2 error, the
    install step's retry succeeded, all 160 packages upgraded, and brew still
    exited 1, so `just upgrade` reported "❌ brew: Upgrade failed".
    """

    def test_recovered_failure_is_success(self, stubs):
        stubs.env['STUB_UPGRADE_FAIL'] = '1'
        # Only the held-back herdr is left: everything we asked for upgraded.
        stubs.env['STUB_OUTDATED_AFTER'] = json.dumps(
            {'formulae': [_formula('herdr', '0.8.2', '0.9.3')], 'casks': []})
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        assert 'Treating as success' in r.stderr

    def test_real_failure_names_what_is_left(self, stubs):
        stubs.env['STUB_UPGRADE_FAIL'] = '1'
        stubs.env['STUB_OUTDATED_AFTER'] = json.dumps(
            {'formulae': [_formula('ripgrep', '14.0', '14.1')], 'casks': []})
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 1
        assert 'still outdated: ripgrep' in r.stderr

    def test_bare_upgrade_recovered_failure_is_success(self, stubs):
        stubs.env['STUB_SESSIONS'] = _sessions(default=False, council=False)
        stubs.env['STUB_UPGRADE_FAIL'] = '1'
        stubs.env['STUB_OUTDATED_AFTER'] = json.dumps({'formulae': [], 'casks': []})
        r = _guard(stubs, 'brew-upgrade')
        assert stubs.upgrades() == ['brew upgrade']
        assert r.returncode == 0, r.stderr

    def test_unverifiable_failure_stays_a_failure(self, stubs):
        stubs.env['STUB_SESSIONS'] = _sessions(default=False, council=False)
        stubs.env['STUB_UPGRADE_FAIL'] = '1'
        stubs.env['STUB_OUTDATED_FAIL'] = '1'
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 1
        assert 'cannot be checked' in r.stderr

    def test_success_does_not_recheck(self, stubs):
        stubs.env['STUB_SESSIONS'] = _sessions(default=False, council=False)
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        assert 'brew outdated --json=v2' not in stubs.calls()

    def test_upgrade_output_still_reaches_the_log(self, stubs):
        stubs.env['STUB_UPGRADE_OUTPUT'] = '🍺  ripgrep was successfully upgraded!'
        r = _guard(stubs, 'brew-upgrade')
        assert '🍺  ripgrep was successfully upgraded!' in r.stdout

    def test_overwritten_cask_is_relinked(self, stubs):
        stubs.env['STUB_UPGRADE_OUTPUT'] = (
            'Warning: Overwrote symlinks from the docker-desktop cask:\n'
            '  /opt/homebrew/share/zsh/site-functions/_docker')
        r = _guard(stubs, 'brew-upgrade')
        assert r.returncode == 0, r.stderr
        assert 'brew link --cask docker-desktop' in stubs.calls()


def _recipe_pty(stubs, answer=''):
    """Run herdr-upgrade.sh on a pseudo-terminal, typing `answer`; return (rc, output)."""
    master, slave = pty.openpty()
    proc = subprocess.Popen(['bash', str(RECIPE)], env=stubs.env,
                            stdin=slave, stdout=slave, stderr=slave)
    os.close(slave)
    os.write(master, (answer + '\n').encode())
    chunks = []
    while True:
        try:
            data = os.read(master, 4096)
        except OSError:  # EIO once the child closes the pty
            break
        if not data:
            break
        chunks.append(data)
    os.close(master)
    return proc.wait(timeout=30), b''.join(chunks).decode(errors='replace')


class TestDeliberateUpgradeRecipe:
    """`just herdr-upgrade`: herdr-upgrade.sh."""

    def test_refuses_non_interactive(self, stubs):
        r = subprocess.run(['bash', str(RECIPE)], env=stubs.env,
                           stdin=subprocess.DEVNULL, capture_output=True, text=True)
        assert r.returncode == 2
        assert 'refuses to run non-interactively' in r.stderr
        assert stubs.calls() == []

    def test_refuses_inside_herdr(self, stubs):
        stubs.env['HERDR_ENV'] = '1'
        rc, out = _recipe_pty(stubs, 'restart')
        assert rc == 2
        assert 'inside a herdr pane' in out
        assert stubs.calls() == []

    def test_wrong_confirmation_changes_nothing(self, stubs):
        rc, out = _recipe_pty(stubs, 'yes')
        assert rc == 1
        assert 'CLOSES EVERY PANE' in out
        assert 'Aborted; nothing changed.' in out
        assert stubs.upgrades() == []
        assert not any('server stop' in c for c in stubs.calls())

    def test_confirmed_upgrades_then_stops_then_relaunches(self, stubs):
        stubs.env['STUB_SESSIONS'] = _sessions(default=True, council=True)
        rc, out = _recipe_pty(stubs, 'restart')
        assert rc == 0, out
        calls = stubs.calls()
        order = [c for c in calls if c.startswith(('brew upgrade', 'ai_council'))
                 or c.endswith('server stop')]
        assert order == ['brew upgrade herdr',
                         'herdr --session default server stop',
                         'herdr --session council server stop',
                         'ai_council ']

    def test_upgrade_failure_leaves_servers_running(self, stubs):
        stubs.env['STUB_UPGRADE_FAIL'] = '1'
        rc, out = _recipe_pty(stubs, 'restart')
        assert rc == 1
        assert 'servers left running, panes intact' in out
        assert not any('server stop' in c for c in stubs.calls())
        assert not any(c.startswith('ai_council') for c in stubs.calls())

    def test_nothing_to_do_when_herdr_current(self, stubs):
        del stubs.env['STUB_HERDR_OUTDATED']
        rc, out = _recipe_pty(stubs)
        assert rc == 0, out
        assert 'already the latest version' in out
        assert stubs.upgrades() == []
