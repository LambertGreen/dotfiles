"""
Tests for `just stow-check` (scripts/stow/check.sh).

Background (B33, 2026-10-15): the Council's `just sync` goes through this
repo's justfile, never around it, and needs a report-only stow dry run.
Contract: exit 0 = stow would change nothing, 1 = it would (stdout names
package + change, one per line), >=2 = could not tell.

Runs the real script and real GNU Stow against a fake HOME and a fake
DOTFILES_DIR whose configs/.stowrc is a copy of the real one.
"""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
SCRIPT = PROJECT_ROOT / 'scripts' / 'stow' / 'check.sh'

pytestmark = pytest.mark.skipif(shutil.which('stow') is None, reason='GNU Stow not installed')


@pytest.fixture
def env(tmp_path):
    home = tmp_path / 'home'
    home.mkdir()
    dotfiles = tmp_path / 'dotfiles'
    configs = dotfiles / 'configs'
    configs.mkdir(parents=True)
    shutil.copy(PROJECT_ROOT / 'configs' / '.stowrc', configs / '.stowrc')
    # file package
    (configs / 'foo').mkdir()
    (configs / 'foo' / 'dot-foorc').write_text('foo\n')
    # folding package: one directory link
    (configs / 'baz' / 'dot-baz').mkdir(parents=True)
    (configs / 'baz' / 'dot-baz' / 'x').write_text('x\n')
    # --no-folding marker: file-level links
    (configs / 'bar' / 'dot-config' / 'bar').mkdir(parents=True)
    (configs / 'bar' / 'dot-config' / 'bar' / 'conf').write_text('c\n')
    (configs / 'bar' / '.stowrc').write_text('--no-folding\n')
    stow_txt = dotfiles / 'machine-classes' / 'cls' / 'stow' / 'stow.txt'
    stow_txt.parent.mkdir(parents=True)
    stow_txt.write_text('# comment\n\nfoo\nbaz\nbar\nnot_a_package\n')
    (home / '.dotfiles.env').write_text('export DOTFILES_MACHINE_CLASS=cls\n')
    return home, dotfiles


def run(home, dotfiles, path=None):
    e = {k: v for k, v in os.environ.items() if k != 'DOTFILES_MACHINE_CLASS'}
    e.update(HOME=str(home), DOTFILES_DIR=str(dotfiles))
    if path is not None:
        e['PATH'] = path
    return subprocess.run(['bash', str(SCRIPT)], env=e, capture_output=True, text=True)


def stow_all(home, dotfiles):
    configs = dotfiles / 'configs'
    for pkg, opts in (('foo', []), ('baz', []), ('bar', ['--no-folding'])):
        subprocess.run(['stow', '--dotfiles', f'--target={home}', *opts, pkg],
                       cwd=configs, check=True, capture_output=True)


def test_unstowed_packages_exit_1_and_name_each_change(env):
    home, dotfiles = env
    r = run(home, dotfiles)
    assert r.returncode == 1, r.stderr
    lines = r.stdout.splitlines()
    assert any(ln.startswith('foo: LINK: .foorc') for ln in lines)
    # folding package: a single directory link
    assert [ln for ln in lines if ln.startswith('baz:')] == ['baz: LINK: .baz => ../dotfiles/configs/baz/dot-baz']
    # marker package: file-level, never a link of .config/bar itself
    assert any(ln.startswith('bar: LINK: .config/bar/conf') for ln in lines)
    # run from configs/, so configs/.stowrc is read, not stowed
    assert '.stowrc' not in r.stdout


def test_fully_stowed_exits_0_silently(env):
    home, dotfiles = env
    stow_all(home, dotfiles)
    r = run(home, dotfiles)
    # no --restow: a restow would report UNLINK+LINK for every package
    assert (r.returncode, r.stdout) == (0, ''), r.stderr


def test_conflict_exits_1_with_conflict_line(env):
    home, dotfiles = env
    stow_all(home, dotfiles)
    (home / '.foorc').unlink()
    (home / '.foorc').write_text('a plain file\n')
    r = run(home, dotfiles)
    assert r.returncode == 1, r.stderr
    assert any(ln.startswith('foo: CONFLICT') and '.foorc' in ln for ln in r.stdout.splitlines())


def test_writes_nothing(env):
    home, dotfiles = env
    before = sorted(p.relative_to(home) for p in home.rglob('*'))
    run(home, dotfiles)
    assert sorted(p.relative_to(home) for p in home.rglob('*')) == before  # no links, no ~/.dotfiles/logs


def test_missing_env_file_cannot_tell(env):
    home, dotfiles = env
    (home / '.dotfiles.env').unlink()
    r = run(home, dotfiles)
    assert r.returncode == 2 and '.dotfiles.env' in r.stderr


def test_no_class_cannot_tell(env):
    home, dotfiles = env
    (home / '.dotfiles.env').write_text('# configured, but no class\n')
    r = run(home, dotfiles)
    assert r.returncode == 2 and 'DOTFILES_MACHINE_CLASS' in r.stderr


def test_missing_stow_txt_cannot_tell(env):
    home, dotfiles = env
    (home / '.dotfiles.env').write_text('export DOTFILES_MACHINE_CLASS=nope\n')
    r = run(home, dotfiles)
    assert r.returncode == 2 and 'stow.txt' in r.stderr


def test_stow_not_on_path_cannot_tell(env, tmp_path):
    home, dotfiles = env
    bin_dir = tmp_path / 'bin'
    bin_dir.mkdir()
    for tool in ('bash', 'dirname', 'uname', 'grep', 'tail'):
        (bin_dir / tool).symlink_to(shutil.which(tool))
    r = run(home, dotfiles, path=str(bin_dir))
    assert r.returncode == 2 and 'stow not on PATH' in r.stderr
