"""
Tests for `just doctor-check-claude-settings` (scripts/health/check-claude-settings.sh).

Background: on 2026-10-08 both Macs had a plain ~/.claude/settings.json instead of the
per-file stow symlink. On 2026-10-09 the work Mac's file was re-stowed and turned plain
again two minutes later, because some writer renamed a temp file over the link. Since
B25, ~/.claude is one folder link into configs/<pkg>/dot-claude, a private submodule.
The check warns unless ~/.claude is that link and the submodule is clean.

Runs the real script against a fake HOME and a fake DOTFILES_DIR.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
SCRIPT = PROJECT_ROOT / 'scripts' / 'health' / 'check-claude-settings.sh'


def git(*args):
    subprocess.run(['git', *args], check=True, capture_output=True)


@pytest.fixture
def env(tmp_path):
    home = tmp_path / 'home'
    home.mkdir()
    dotfiles = tmp_path / 'dotfiles'
    for pkg in ('ai_claude_my', 'ai_claude_work'):
        d = dotfiles / 'configs' / pkg / 'dot-claude'
        d.mkdir(parents=True)
        (d / '.gitignore').write_text('/*\n!/.gitignore\n!/settings.json\n')
        (d / 'settings.json').write_text('{}\n')
        git('init', '-q', str(d))
        git('-C', str(d), 'add', '.gitignore', 'settings.json')
        git('-C', str(d), '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-q', '-m', 'seed')
    for cls, pkg in (('personal', 'ai_claude_my'), ('work', 'ai_claude_work'), ('linux', None)):
        s = dotfiles / 'machine-classes' / cls / 'stow' / 'stow.txt'
        s.parent.mkdir(parents=True)
        s.write_text('ai_claude\n' if pkg is None else f'# comment\n{pkg}\n')
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
    (home / '.claude').symlink_to(dotfiles / 'configs' / pkg / 'dot-claude')
    return dotfiles / 'configs' / pkg / 'dot-claude'


def test_clean_folder_link_passes(env):
    home, dotfiles = env
    d = link(home, dotfiles, 'ai_claude_my')
    (d / 'history.jsonl').write_text('runtime, ignored\n')
    out = run(home, dotfiles, 'personal')
    assert '⚠' not in out and 'folder link' in out and 'match the dot-claude repo' in out


def test_rewritten_curated_file_warns(env):
    home, dotfiles = env
    link(home, dotfiles, 'ai_claude_my')
    # what an atomic writer does: temp file renamed over the original, through the link
    (home / '.claude' / 'settings.json.tmp').write_text('{"model": "x"}\n')
    os.replace(home / '.claude' / 'settings.json.tmp', home / '.claude' / 'settings.json')
    out = run(home, dotfiles, 'personal')
    assert '⚠ ~/.claude has 1 uncommitted change(s): settings.json' in out


def test_real_directory_warns_to_migrate(env):
    home, dotfiles = env
    (home / '.claude').mkdir()
    (home / '.claude' / 'settings.json').symlink_to(
        dotfiles / 'configs' / 'ai_claude_my' / 'dot-claude' / 'settings.json')
    out = run(home, dotfiles, 'personal')
    assert 'real directory' in out and 'migrate-dir.sh' in out and 'configs/ai_claude_my/README.md' in out


def test_link_into_wrong_package_warns(env):
    home, dotfiles = env
    link(home, dotfiles, 'ai_claude_my')
    out = run(home, dotfiles, 'work')
    assert '⚠' in out and 'not ai_claude_work' in out


def test_broken_link_warns(env, tmp_path):
    home, dotfiles = env
    (home / '.claude').symlink_to(tmp_path / 'gone' / 'configs' / 'ai_claude_work' / 'dot-claude')
    assert 'broken folder link' in run(home, dotfiles, 'work')


def test_uninitialized_submodule_warns(env):
    home, dotfiles = env
    d = link(home, dotfiles, 'ai_claude_work')
    shutil.rmtree(d / '.git')  # tmp_path fixture data
    assert 'not an initialized submodule' in run(home, dotfiles, 'work')


def test_missing_warns(env):
    home, dotfiles = env
    assert '⚠ ~/.claude is missing' in run(home, dotfiles, 'personal')


def test_unknown_top_level_name_is_named_not_warned(env):
    home, dotfiles = env
    d = link(home, dotfiles, 'ai_claude_my')
    (d / 'projects').mkdir()
    (d / 'brand-new-cache').mkdir()
    out = run(home, dotfiles, 'personal')
    assert 'ℹ New in ~/.claude' in out and 'brand-new-cache' in out
    assert 'projects' not in out.split('ℹ')[1] and '⚠' not in out


def test_class_without_package_skips(env):
    home, dotfiles = env
    (home / '.claude').mkdir()
    out = run(home, dotfiles, 'linux')
    assert '⏭️' in out and '⚠' not in out


def test_no_class_skips(env):
    home, dotfiles = env
    assert 'No machine class' in run(home, dotfiles, None)
