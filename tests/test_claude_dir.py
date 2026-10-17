"""
Tests for the ~/.claude folder link (B25): the safety boundary around it.

~/.claude is one stow folder link into configs/ai_claude_<ctx>/dot-claude, a private
submodule (dot-claude-my / dot-claude-work). Everything Claude Code and other apps
write to ~/.claude then lands in that tree, so two allow-lists must hold:

1. dot-claude/.gitignore: git sees only the curated files, never runtime state
   (sessions, transcripts, memory, credentials, caches), whatever new names appear.
2. <pkg>/.stow-local-ignore: stow still folds ~/.claude into one link, and when
   ~/.claude is a real directory it links only the curated files.

Both run against the real package files, with a corpus of runtime names seen in a
live ~/.claude (2026-10-16) plus names no one has seen yet.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
CONFIGS = PROJECT_ROOT / 'configs'
PACKAGES = ('ai_claude_my', 'ai_claude_work')
CURATED = {'.gitignore', 'README.md', 'CLAUDE.md', 'settings.json'}
STOWED = {'CLAUDE.md', 'settings.json'}  # what a real-dir ~/.claude gets linked

# Seen in live ~/.claude (personal Mac, 2026-10-16), from the work Mac's settings.json,
# and from the Claude Code docs, plus unknown names: an allow-list must hide those too.
RUNTIME_FILES = [
    'projects/-Users-x-dev-repo/memory/MEMORY.md',
    'projects/-Users-x-dev-repo/0b1c.jsonl',
    'sessions/abc.json', 'session-env/abc/env', 'history.jsonl', '.credentials.json',
    'plugins/cache/x/plugin.json', 'plugins/installed_plugins.json', 'file-history/a/b',
    'paste-cache/p.txt', 'shell-snapshots/s.sh', 'todos/t.json', 'statsig/s', 'ide/1.lock',
    'debug/1.txt', 'cache/c', 'telemetry/t', 'feedback/f', 'backups/.claude.json.backup.1',
    'stats-cache.json', 'settings.json.bak', 'settings.json.bak2', 'settings.local.json',
    'settings.json.tmp.123', '.last-cleanup', '.last-update-result.json',
    'skills/synced/u/pdf/SKILL.md', 'hooks/herdr-agent-state.sh', 'statusline.sh',
    'agents/a.md', 'commands/c.md', 'output-styles/o.md', 'some-future-dir/x', 'NEW_FILE',
    '.DS_Store', 'CLAUDE.md.orig', 'nested/settings.json', 'nested/CLAUDE.md',
]
RUNTIME_LINKS = {'debug/latest': '/abs/debug/1.txt', 'skills/attune': '/abs/ai_council/.claude/skills/attune'}


def dot_claude(pkg):
    d = CONFIGS / pkg / 'dot-claude'
    if not (d / '.gitignore').is_file():
        pytest.skip(f'{pkg}/dot-claude submodule not initialized (just git-sync)')
    return d


def fill_runtime(root):
    for rel in RUNTIME_FILES:
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text('runtime\n')
    for rel, target in RUNTIME_LINKS.items():
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).symlink_to(target)


@pytest.fixture(params=PACKAGES)
def pkg(request):
    return request.param


# --- 1. git: only curated files are visible ---------------------------------------------------

def test_gitignore_hides_every_runtime_name(pkg, tmp_path):
    repo = tmp_path / 'dot-claude'
    repo.mkdir()
    subprocess.run(['git', 'init', '-q', str(repo)], check=True)
    shutil.copy(dot_claude(pkg) / '.gitignore', repo / '.gitignore')
    for name in CURATED - {'.gitignore'}:
        (repo / name).write_text('curated\n')
    fill_runtime(repo)
    r = subprocess.run(['git', '-C', str(repo), 'status', '--porcelain', '--untracked-files=all'],
                       capture_output=True, text=True, check=True)
    visible = {ln[3:] for ln in r.stdout.splitlines()}
    assert visible == CURATED


def test_submodule_tracks_only_curated_files(pkg):
    r = subprocess.run(['git', '-C', str(dot_claude(pkg)), 'ls-files'],
                       capture_output=True, text=True, check=True)
    assert set(r.stdout.split()) <= CURATED


# --- 2. stow: one folder link; a real dir gets only curated links -----------------------------

@pytest.fixture
def stow_env(pkg, tmp_path):
    if shutil.which('stow') is None:
        pytest.skip('GNU Stow not installed')
    src = dot_claude(pkg)
    configs = tmp_path / 'configs'
    configs.mkdir()
    shutil.copy(CONFIGS / '.stowrc', configs / '.stowrc')
    dst = configs / pkg / 'dot-claude'
    dst.mkdir(parents=True)
    shutil.copy(CONFIGS / pkg / '.stow-local-ignore', configs / pkg / '.stow-local-ignore')
    shutil.copy(CONFIGS / pkg / 'README.md', configs / pkg / 'README.md')
    for name in CURATED:
        shutil.copy(src / name, dst / name)
    (dst / '.git').write_text('gitdir: ../../../.git/modules/x\n')  # the submodule's gitfile
    fill_runtime(dst)  # the migrated state: runtime lives in the package
    home = tmp_path / 'home'
    home.mkdir()
    return pkg, configs, home


def stow_n(configs, home, pkg):
    r = subprocess.run(['stow', '-n', '-v', '--dotfiles', f'--target={home}', pkg],
                       cwd=configs, capture_output=True, text=True)
    return r.returncode, [ln for ln in (r.stdout + r.stderr).splitlines() if not ln.startswith('WARNING: in simulation')]


def test_missing_target_folds_into_one_link(stow_env):
    pkg, configs, home = stow_env
    rc, lines = stow_n(configs, home, pkg)
    assert (rc, lines) == (0, [f'LINK: .claude => ../configs/{pkg}/dot-claude'])


def test_real_dir_target_links_only_curated_files(stow_env):
    pkg, configs, home = stow_env
    (home / '.claude').mkdir()
    (home / '.claude' / 'history.jsonl').write_text('live\n')
    (home / '.claude' / 'projects').mkdir()
    rc, lines = stow_n(configs, home, pkg)
    assert rc == 0, lines
    assert sorted(lines) == sorted(f'LINK: .claude/{n} => ../../configs/{pkg}/dot-claude/{n}' for n in STOWED)


def test_stow_and_git_allow_lists_agree(pkg):
    ignore = (CONFIGS / pkg / '.stow-local-ignore').read_text()
    for name in STOWED:
        assert name.replace('.', r'\.') in ignore
    allowed = {ln[2:] for ln in (dot_claude(pkg) / '.gitignore').read_text().splitlines() if ln.startswith('!/')}
    assert STOWED <= allowed


# --- 3. machine classes -------------------------------------------------------------------------

@pytest.mark.parametrize('cls,pkg_name', [('laptop_personal_mac', 'ai_claude_my'),
                                          ('laptop_work_mac', 'ai_claude_work')])
def test_macs_stow_the_folder_package_not_the_per_file_one(cls, pkg_name):
    lines = (PROJECT_ROOT / 'machine-classes' / cls / 'stow' / 'stow.txt').read_text().splitlines()
    entries = [ln.strip() for ln in lines if ln.strip() and not ln.lstrip().startswith('#')]
    assert pkg_name in entries
    # ai_claude's per-file ~/.claude/CLAUDE.md link would make stow unfold ~/.claude
    assert 'ai_claude' not in entries
    assert not (CONFIGS / pkg_name / '.stowrc').exists()  # no --no-folding marker
