"""
Tests for brew_post_upgrade: re-applying Brewfile `link: false` after `brew upgrade`.

Background (2026-10-05 personal run): `brew upgrade` relinked `docker` and `sip`
although the Brewfile declares both `link: false`, and docker's relink
overwrote docker-desktop's completion symlinks.
"""
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.dotfiles_pm import brew_post_upgrade as bpu  # noqa: E402


BREWFILE = '''\
tap "pkryger/emacsmacport-exp"
brew "docker", link: false
brew "ripgrep"
brew "sip", link: false   # PyQt build tool, shadows nothing on PATH
brew "pkryger/emacsmacport-exp/thing", link: false
# brew "commented", link: false
brew "linkish", args: ["with-link"]
cask "docker-desktop"
'''


class FakeRun:
    """Records argv; `brew --prefix` returns `prefix`, everything else succeeds."""

    def __init__(self, prefix, fail=()):
        self.prefix, self.fail, self.calls = prefix, set(fail), []

    def __call__(self, argv, **_kwargs):
        self.calls.append(argv)
        if argv == ['brew', '--prefix']:
            return subprocess.CompletedProcess(argv, 0, f'{self.prefix}\n', '')
        rc = 1 if tuple(argv) in self.fail else 0
        return subprocess.CompletedProcess(argv, rc, '', 'boom' if rc else '')


def _linked(prefix, *names):
    d = prefix / 'var' / 'homebrew' / 'linked'
    d.mkdir(parents=True, exist_ok=True)
    for n in names:
        (d / n).symlink_to(prefix / 'Cellar' / n)


def _brewfile(tmp_path):
    p = tmp_path / 'Brewfile'
    p.write_text(BREWFILE)
    return p


def test_link_false_formulae_parses_only_real_declarations(tmp_path):
    assert bpu.link_false_formulae(_brewfile(tmp_path)) == ['docker', 'sip', 'thing']


def test_overwritten_casks_deduplicates_in_order():
    out = ('Warning: Overwrote symlinks from the docker-desktop cask:\n'
           'x\nWarning: Overwrote symlinks from the other cask:\n'
           'Warning: Overwrote symlinks from the docker-desktop cask:\n')
    assert bpu.overwritten_casks(out) == ['docker-desktop', 'other']


def test_unlinks_only_relinked_link_false_formulae(tmp_path):
    prefix = tmp_path / 'prefix'
    _linked(prefix, 'docker', 'ripgrep')  # sip stayed unlinked; ripgrep is allowed
    run = FakeRun(prefix)
    unlinked = bpu.reassert_unlinked(_brewfile(tmp_path), [], run=run)
    assert unlinked == ['docker']
    assert ['brew', 'unlink', 'docker'] in run.calls
    assert ['brew', 'unlink', 'sip'] not in run.calls
    assert ['brew', 'unlink', 'ripgrep'] not in run.calls


def test_relinks_overwritten_casks_after_unlinking(tmp_path):
    prefix = tmp_path / 'prefix'
    _linked(prefix, 'docker')
    run = FakeRun(prefix)
    bpu.reassert_unlinked(_brewfile(tmp_path), ['docker-desktop'], run=run)
    acting = [c for c in run.calls if c != ['brew', '--prefix']]
    assert acting == [['brew', 'unlink', 'docker'],
                      ['brew', 'link', '--cask', 'docker-desktop']]


def test_failures_are_reported_not_raised(tmp_path, capsys):
    prefix = tmp_path / 'prefix'
    _linked(prefix, 'docker')
    run = FakeRun(prefix, fail=[('brew', 'unlink', 'docker'),
                                ('brew', 'link', '--cask', 'gone')])
    assert bpu.reassert_unlinked(_brewfile(tmp_path), ['gone'], run=run) == []
    err = capsys.readouterr().err
    assert 'brew unlink docker failed' in err
    assert 'brew link --cask gone failed' in err


def test_no_brewfile_and_no_casks_does_nothing(tmp_path):
    run = FakeRun(tmp_path)
    assert bpu.reassert_unlinked(None, [], run=run) == []
    assert run.calls == []


def test_still_outdated_respects_targets_held_and_pinned():
    outdated = {'formulae': [{'name': 'herdr'}, {'name': 'ripgrep'},
                             {'name': 'pinned', 'pinned': True}],
                'casks': [{'name': 'whatsapp'}]}
    assert bpu.still_outdated(None, outdated, exclude=['herdr']) == {'ripgrep', 'whatsapp'}
    assert bpu.still_outdated(['whatsapp'], outdated) == {'whatsapp'}
    assert bpu.still_outdated(['ripgrep'], {'formulae': [], 'casks': []}) == set()
