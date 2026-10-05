"""
Tests for the `ai_council` launcher's resume target.

Background (2026-10-04): after a herdr restart, `ai_council` woke the Council
with `claude --continue`, which resumes the newest session *in the cwd*.
Missions share ~/dev/my/ai_council, so a mission's session took the Council's
seat (ai_council retro 2026-10-04-recover-rekey.md). The launcher now resumes
the sid `recover.sh --council-sid` reads from the start-stop log, and keeps
`--continue` only as a loud fallback.

These tests drive the real script through both call sites (`herdr pane run`
from another workspace, `exec` inside the Council workspace) with stub
`herdr`, `claude` and `recover.sh`, so the unquoted `$(claude_argv)`
word-splitting is exercised as it runs for real.
"""
import os
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
SCRIPT = PROJECT_ROOT / 'configs' / 'ai_council_common' / 'dot-local' / 'bin' / 'ai_council'
SID = 'b4a4033a-ebcf-4580-8b81-2a6fc1941e0b'

HERDR_STUB = """#!/usr/bin/env bash
case "$1 $2" in
  "workspace list") echo '{"result":{"workspaces":[{"label":"Jedi Council","workspace_id":"w1"}]}}' ;;
  "workspace get")  printf '{"result":{"workspace":{"label":"%s"}}}\\n' "$STUB_LABEL" ;;
  "pane process-info") echo '{"result":{"process_info":{"foreground_processes":[]}}}' ;;
  "pane run") shift 3; printf '%s\\n' "$@" > "$STUB_ARGV_LOG" ;;
  *) exit 0 ;;
esac
"""

CLAUDE_STUB = """#!/usr/bin/env bash
printf '%s\\n' claude "$@" > "$STUB_ARGV_LOG"
"""


def _write_exe(path, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)
    path.chmod(0o755)


def _run(tmp_path, args=(), recover=None, in_council=False):
    """Run the launcher inside a fake herdr; return (argv the launcher ran, result).

    recover: None = no recover.sh installed; else the stub's bash body.
    in_council: True = the `exec` path (current workspace is the Council's).
    """
    home = tmp_path / 'home'
    ai_dir = home / 'dev' / 'my' / 'ai_council'
    ai_dir.mkdir(parents=True)
    if recover is not None:
        _write_exe(ai_dir / '.claude' / 'orchestrator' / 'recover.sh',
                   '#!/usr/bin/env bash\n' + recover)
    bin_dir = tmp_path / 'bin'
    _write_exe(bin_dir / 'herdr', HERDR_STUB)
    _write_exe(bin_dir / 'claude', CLAUDE_STUB)
    log = tmp_path / 'argv.log'
    env = {
        'HOME': str(home),
        'PATH': f"{bin_dir}:{os.environ['PATH']}",
        'HERDR_ENV': '1',
        'HERDR_WORKSPACE_ID': 'w1',
        'STUB_LABEL': 'Jedi Council' if in_council else '~',
        'STUB_ARGV_LOG': str(log),
    }
    result = subprocess.run(['bash', str(SCRIPT), *args], env=env,
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    return log.read_text().split('\n')[:-1], result


@pytest.mark.parametrize('in_council', [False, True], ids=['pane-run', 'exec'])
class TestResumeTarget:
    def test_resumes_recorded_council_sid(self, tmp_path, in_council):
        argv, result = _run(tmp_path, recover=f'echo {SID}', in_council=in_council)
        assert argv == ['claude', '--resume', SID]
        assert f'resuming Council session {SID}' in result.stdout
        assert 'falling back' not in result.stderr

    def test_falls_back_loudly_when_recover_missing(self, tmp_path, in_council):
        argv, result = _run(tmp_path, recover=None, in_council=in_council)
        assert argv == ['claude', '--continue']
        assert 'falling back to `claude --continue`' in result.stderr
        assert 'recover.sh not found' in result.stderr

    def test_falls_back_loudly_when_no_sid_recorded(self, tmp_path, in_council):
        recover = 'echo "no role:council start recorded in log" >&2; exit 1'
        argv, result = _run(tmp_path, recover=recover, in_council=in_council)
        assert argv == ['claude', '--continue']
        assert 'no role:council start recorded' in result.stderr

    def test_rejects_non_sid_output(self, tmp_path, in_council):
        argv, result = _run(tmp_path, recover='echo "not a sid"', in_council=in_council)
        assert argv == ['claude', '--continue']
        assert 'printed no session id: not a sid' in result.stderr

    def test_fresh_and_pick_skip_recover(self, tmp_path, in_council):
        # A failing recover.sh would print the fallback warning: fresh/pick must not consult it.
        argv, result = _run(tmp_path, args=['--pick'], recover='exit 99', in_council=in_council)
        assert argv == ['claude', '--resume']
        assert result.stderr == ''
        argv, _ = _run(tmp_path / 'f', args=['--fresh'], recover='exit 99', in_council=in_council)
        assert argv == ['claude']
