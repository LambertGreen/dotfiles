"""
Tests for `just doctor-check-claude-settings` (scripts/health/check-claude-settings.sh).

Background (2026-10-08): ~/.claude/settings.json was split into the ai_claude_my
and ai_claude_work stow packages. Both Macs were found with a plain file instead
of the symlink, so the check warns whenever the live file is not a symlink into
the package the machine class stows.

Runs the real script against a fake HOME and a fake DOTFILES_DIR.
"""
import os
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
SCRIPT = PROJECT_ROOT / 'scripts' / 'health' / 'check-claude-settings.sh'


@pytest.fixture
def env(tmp_path):
    home = tmp_path / 'home'
    dotfiles = tmp_path / 'dotfiles'
    (home / '.claude').mkdir(parents=True)
    for pkg in ('ai_claude_my', 'ai_claude_work'):
        f = dotfiles / 'configs' / pkg / 'dot-claude' / 'settings.json'
        f.parent.mkdir(parents=True)
        f.write_text('{}\n')
    for cls, pkg in (('personal', 'ai_claude_my'), ('work', 'ai_claude_work'), ('linux', None)):
        s = dotfiles / 'machine-classes' / cls / 'stow' / 'stow.txt'
        s.parent.mkdir(parents=True)
        s.write_text('ai_claude\n' + (f'{pkg}\n' if pkg else ''))
    return home, dotfiles


def run(home, dotfiles, cls):
    if cls:
        (home / '.dotfiles.env').write_text(f'export DOTFILES_MACHINE_CLASS={cls}\n')
    e = {k: v for k, v in os.environ.items() if k != 'DOTFILES_MACHINE_CLASS'}
    e.update(TEST_HOME=str(home), DOTFILES_DIR=str(dotfiles))
    r = subprocess.run(['bash', str(SCRIPT)], env=e, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    return r.stdout


def link(home, dotfiles, pkg):
    (home / '.claude' / 'settings.json').symlink_to(
        dotfiles / 'configs' / pkg / 'dot-claude' / 'settings.json')


def test_correct_symlink_passes(env):
    home, dotfiles = env
    link(home, dotfiles, 'ai_claude_my')
    assert '✓' in run(home, dotfiles, 'personal')


def test_plain_file_warns(env):
    home, dotfiles = env
    (home / '.claude' / 'settings.json').write_text('{}\n')
    out = run(home, dotfiles, 'personal')
    assert 'plain file' in out and 'configs/ai_claude_my/README.md' in out


def test_symlink_into_wrong_package_warns(env):
    home, dotfiles = env
    link(home, dotfiles, 'ai_claude_my')
    out = run(home, dotfiles, 'work')
    assert '⚠' in out and 'not ai_claude_work' in out


def test_broken_symlink_warns(env):
    home, dotfiles = env
    link(home, dotfiles, 'ai_claude_work')
    (dotfiles / 'configs' / 'ai_claude_work' / 'dot-claude' / 'settings.json').unlink()
    assert 'broken symlink' in run(home, dotfiles, 'work')


def test_missing_file_warns(env):
    home, dotfiles = env
    assert 'missing' in run(home, dotfiles, 'personal')


def test_class_without_package_skips(env):
    home, dotfiles = env
    (home / '.claude' / 'settings.json').write_text('{}\n')
    out = run(home, dotfiles, 'linux')
    assert '⏭️' in out and '⚠' not in out


def test_no_class_skips(env):
    home, dotfiles = env
    assert 'No machine class' in run(home, dotfiles, None)
