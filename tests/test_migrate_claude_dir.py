"""
Tests for scripts/claude/migrate-dir.sh: ~/.claude real dir <-> stow folder link (B25).

The fixture mirrors a pre-migration Mac. ~/.claude is a real directory holding runtime
state, plus per-file stow links for settings.json and CLAUDE.md. The package is a git
repo standing in for the dot-claude submodule, using the real allow-list .gitignore,
the real .stow-local-ignore and the real configs/.stowrc. Real GNU Stow runs.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
SCRIPT = PROJECT_ROOT / 'scripts' / 'claude' / 'migrate-dir.sh'
PKG = 'ai_claude_my'
SUBMODULE = PROJECT_ROOT / 'configs' / PKG / 'dot-claude'

pytestmark = [
    pytest.mark.skipif(shutil.which('stow') is None, reason='GNU Stow not installed'),
    pytest.mark.skipif(not (SUBMODULE / '.gitignore').is_file(), reason='dot-claude-my submodule not initialized'),
]

RUNTIME = {
    'history.jsonl': 'h\n',
    'projects/-Users-x-repo/memory/MEMORY.md': 'memory\n',
    'projects/-Users-x-repo/s1.jsonl': 'transcript\n',
    'sessions/1.json': '{}\n',
    'plugins/installed_plugins.json': '{}\n',
    'settings.json.bak': 'old\n',
    '.last-cleanup': 'x\n',
}


def git(*args):
    return subprocess.run(['git', *args], check=True, capture_output=True, text=True).stdout


@pytest.fixture
def env(tmp_path):
    home = tmp_path / 'home'
    dotfiles = tmp_path / 'dotfiles'
    configs = dotfiles / 'configs'
    pkg_dir = configs / PKG
    repo = pkg_dir / 'dot-claude'
    repo.mkdir(parents=True)
    shutil.copy(PROJECT_ROOT / 'configs' / '.stowrc', configs / '.stowrc')
    shutil.copy(PROJECT_ROOT / 'configs' / PKG / '.stow-local-ignore', pkg_dir / '.stow-local-ignore')
    for name in ('.gitignore', 'settings.json', 'CLAUDE.md', 'README.md'):
        shutil.copy(SUBMODULE / name, repo / name)
    git('init', '-q', str(repo))
    git('-C', str(repo), 'add', '.gitignore', 'settings.json', 'CLAUDE.md', 'README.md')
    git('-C', str(repo), '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q', '-m', 'seed')
    stow_txt = dotfiles / 'machine-classes' / 'laptop_personal_mac' / 'stow' / 'stow.txt'
    stow_txt.parent.mkdir(parents=True)
    stow_txt.write_text(f'# AI\n{PKG}\n')

    live = home / '.claude'
    live.mkdir(parents=True)
    (home / '.dotfiles.env').write_text('export DOTFILES_MACHINE_CLASS=laptop_personal_mac\n')
    for rel, text in RUNTIME.items():
        (live / rel).parent.mkdir(parents=True, exist_ok=True)
        (live / rel).write_text(text)
    (live / 'skills').mkdir()
    (live / 'skills' / 'attune').symlink_to('/abs/ai_council/.claude/skills/attune')
    # the pre-migration per-file stow links
    (live / 'settings.json').symlink_to(os.path.relpath(repo / 'settings.json', live))
    shared = configs / 'ai_claude' / 'dot-claude' / 'CLAUDE.md'
    shared.parent.mkdir(parents=True)
    shared.write_text((SUBMODULE / 'CLAUDE.md').read_text())
    (live / 'CLAUDE.md').symlink_to(os.path.relpath(shared, live))

    trash_dir = tmp_path / 'trash'
    trash_dir.mkdir()
    fake_trash = tmp_path / 'fake-trash'
    fake_trash.write_text(f'#!/bin/sh\nmv "$1" "{trash_dir}/"\n')
    fake_trash.chmod(0o755)
    return {'home': home, 'live': live, 'repo': repo, 'dotfiles': dotfiles, 'tmp': tmp_path,
            'trash': str(fake_trash)}


def run(e, *args, allow_running=True, extra_env=None):
    environ = {k: v for k, v in os.environ.items() if k != 'DOTFILES_MACHINE_CLASS'}
    environ.update(TARGET_HOME=str(e['home']), DOTFILES_DIR=str(e['dotfiles']),
                   CLAUDE_MIGRATE_TRASH=e['trash'])
    if allow_running:
        environ['CLAUDE_MIGRATE_ALLOW_RUNNING'] = '1'
    environ.update(extra_env or {})
    return subprocess.run(['bash', str(SCRIPT), *args], env=environ, capture_output=True, text=True)


def tree(root):
    """Every path under root -> file content or link target (follows nothing)."""
    out = {}
    for p in sorted(root.rglob('*')):
        rel = str(p.relative_to(root))
        if '.git' in p.relative_to(root).parts:
            continue
        if p.is_symlink():
            out[rel] = '-> ' + os.readlink(p)
        elif p.is_file():
            out[rel] = p.read_text()
    return out


def runtime_view(root):
    return {k: v for k, v in tree(root).items()
            if k.split('/')[0] not in ('settings.json', 'CLAUDE.md', '.git', '.gitignore', 'README.md')}


def test_dry_run_changes_nothing(env):
    e = env
    before = tree(e['home'])
    r = run(e, '--dry-run')
    assert r.returncode == 0, r.stderr
    assert 'would proceed' in r.stdout
    assert tree(e['home']) == before


def test_migrate_moves_everything_and_links_the_folder(env):
    e = env
    before = runtime_view(e['live'])
    inode = (e['live'] / 'history.jsonl').stat().st_ino
    r = run(e)
    assert r.returncode == 0, r.stdout + r.stderr
    live = e['live']
    assert live.is_symlink() and os.readlink(live) == f'../dotfiles/configs/{PKG}/dot-claude'
    assert runtime_view(live) == before  # every runtime entry, unchanged, through the link
    assert (live / 'history.jsonl').stat().st_ino == inode  # moved, not copied
    assert (live / 'settings.json').is_file() and not (live / 'settings.json').is_symlink()
    assert git('-C', str(e['repo']), 'status', '--porcelain', '--untracked-files=all') == ''
    backups = list(e['home'].glob('.claude.pre-dirstow-*'))
    assert len(backups) == 1 and (backups[0] / 'projects/-Users-x-repo/memory/MEMORY.md').read_text() == 'memory\n'
    assert sorted(p.name for p in (e['tmp'] / 'trash').iterdir()) == ['CLAUDE.md', 'settings.json']


def test_migrate_is_idempotent(env):
    assert run(env).returncode == 0
    r = run(env)
    assert r.returncode == 0 and 'Already migrated' in r.stdout


def test_rollback_restores_the_real_directory(env):
    e = env
    before = runtime_view(e['live'])
    assert run(e).returncode == 0
    r = run(e, '--rollback')
    assert r.returncode == 0, r.stdout + r.stderr
    live = e['live']
    assert live.is_dir() and not live.is_symlink()
    assert runtime_view(live) == before
    for name in ('settings.json', 'CLAUDE.md'):
        assert (live / name).is_symlink() and (live / name).resolve() == (e['repo'] / name).resolve()
    # the package holds only the curated files again
    left = sorted(p.name for p in e['repo'].iterdir())
    assert left == sorted(['.git', '.gitignore', 'README.md', 'CLAUDE.md', 'settings.json'])


def test_drifted_settings_is_adopted_as_a_diff(env):
    e = env
    (e['live'] / 'settings.json').unlink()
    (e['live'] / 'settings.json').write_text('{"model": "drifted"}\n')
    r = run(e)
    assert r.returncode == 0, r.stdout + r.stderr
    assert 'adopt' in r.stdout
    assert git('-C', str(e['repo']), 'status', '--porcelain') == ' M settings.json\n'


def test_refuses_an_entry_that_would_be_committable(env):
    e = env
    gi = e['repo'] / '.gitignore'
    gi.write_text(gi.read_text() + '!/agents/\n')
    git('-C', str(e['repo']), '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qam', 'allow agents')
    (e['live'] / 'agents').mkdir()
    (e['live'] / 'agents' / 'a.md').write_text('a\n')
    before = tree(e['home'])
    r = run(e)
    assert r.returncode == 1 and 'agents: NOT ignored' in r.stderr
    assert tree(e['home']) == before


def test_refuses_a_name_already_in_the_repo(env):
    e = env
    (e['live'] / 'README.md').write_text('stray\n')
    before = tree(e['home'])
    r = run(e)
    assert r.returncode == 1 and 'README.md: already exists' in r.stderr
    assert tree(e['home']) == before


def test_refuses_a_dirty_submodule(env):
    e = env
    (e['repo'] / 'CLAUDE.md').write_text('edited\n')
    r = run(e)
    assert r.returncode == 1 and 'uncommitted changes' in r.stderr
    assert e['live'].is_dir() and not e['live'].is_symlink()


def fake_pgrep(e):
    bin_dir = e['tmp'] / 'bin'
    bin_dir.mkdir(exist_ok=True)
    (bin_dir / 'pgrep').write_text('#!/bin/sh\necho 4242\n')
    (bin_dir / 'pgrep').chmod(0o755)
    return {'PATH': f'{bin_dir}:{os.environ["PATH"]}'}


def test_refuses_while_claude_runs(env):
    e = env
    r = run(e, allow_running=False, extra_env=fake_pgrep(e))
    assert r.returncode == 1 and 'Claude is running (pids: 4242)' in r.stderr
    assert e['live'].is_dir() and not e['live'].is_symlink()


def test_running_override_is_ignored_for_the_real_home(env):
    e = env
    r = run(e, extra_env={**fake_pgrep(e), 'HOME': str(e['home'])})
    assert r.returncode == 1 and 'Claude is running' in r.stderr
