"""
Tests for the installed-but-undeclared package check.

Background (2026-08-29): `just upgrade` failed. `isort` was installed as both a
brew formula and a pip package, the pip script squatted on
/opt/homebrew/bin/isort, and `brew link` could not complete. isort was declared
in no Brewfile for this machine -- the work machine had already retired it:

    # brew "isort"  # Let projects manage import sorters via dev dependencies

`brew bundle check` only answers "is everything I declared installed?", so
nothing ever reported the reverse. A package undeclared for over a year broke
the upgrade.

These tests drive the real script with a stubbed `brew` on PATH, so the actual
parsing and set logic is exercised rather than reimplemented.
"""
import os
import subprocess
import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
SCRIPT = PROJECT_ROOT / 'scripts' / 'health' / 'check-undeclared-packages.sh'

BREW_STUB = """#!/usr/bin/env bash
case "$*" in
  "leaves --installed-on-request") printf '%s' "$STUB_LEAVES" ;;
  "list --formula")                printf '%s' "$STUB_FORMULAE" ;;
  "list --cask")                   printf '%s' "$STUB_CASKS" ;;
  info*)                           exit 1 ;;
  *)                               exit 0 ;;
esac
"""


def _run_check(tmp_path, brewfile_body, leaves, formulae, casks):
    """Run the real script against a fixture repo with a stubbed brew."""
    bindir = tmp_path / 'bin'
    home = tmp_path / 'home'
    brewdir = tmp_path / 'repo' / 'machine-classes' / 'testclass' / 'brew'
    for d in (bindir, home, brewdir):
        d.mkdir(parents=True, exist_ok=True)

    (brewdir / 'Brewfile').write_text(brewfile_body)

    stub = bindir / 'brew'
    stub.write_text(BREW_STUB)
    stub.chmod(0o755)

    env = dict(os.environ)
    env.update({
        'PATH': f"{bindir}:{env['PATH']}",
        'HOME': str(home),          # isolate from the real ~/.dotfiles.env
        'DOTFILES_DIR': str(tmp_path / 'repo'),
        'DOTFILES_MACHINE_CLASS': 'testclass',
        'STUB_LEAVES': leaves,
        'STUB_FORMULAE': formulae,
        'STUB_CASKS': casks,
    })

    proc = subprocess.run(
        ['bash', str(SCRIPT)],
        cwd=str(tmp_path / 'repo'), env=env,
        capture_output=True, text=True, timeout=60,
    )
    return proc.stdout


@pytest.mark.skipif(sys.platform == 'win32', reason='bash script')
class TestUndeclaredPackages:

    def test_flags_the_isort_scenario(self, tmp_path):
        """
        The regression. isort is installed but only COMMENTED OUT in the
        Brewfile -- a commented line is a retirement, not a declaration.
        """
        out = _run_check(
            tmp_path,
            'brew "ripgrep"\n# brew "isort"  # retired: use project dev deps\n',
            leaves='ripgrep\nisort\n',
            formulae='ripgrep\nisort\n',
            casks='',
        )
        assert 'isort' in out
        assert 'not in the Brewfile' in out

    def test_declared_packages_are_not_flagged(self, tmp_path):
        out = _run_check(
            tmp_path,
            'brew "ripgrep"\ncask "firefox"\n',
            leaves='ripgrep\n',
            formulae='ripgrep\n',
            casks='firefox\n',
        )
        assert 'ripgrep' not in out
        assert 'firefox' not in out
        assert 'Everything installed is declared' in out

    def test_flags_undeclared_casks(self, tmp_path):
        out = _run_check(
            tmp_path,
            'cask "firefox"\n',
            leaves='', formulae='', casks='firefox\nsketchy-app\n',
        )
        assert 'sketchy-app' in out
        assert 'firefox' not in out

    def test_declaration_with_options_still_counts(self, tmp_path):
        """`brew "docker", link: false` is a declaration, options and all."""
        out = _run_check(
            tmp_path,
            'brew "docker", link: false\n',
            leaves='docker\n', formulae='docker\n', casks='',
        )
        assert 'Everything installed is declared' in out

    def test_tap_qualified_declaration_matches_short_name(self, tmp_path):
        """Brewfile says user/tap/foo; brew leaves reports foo."""
        out = _run_check(
            tmp_path,
            'brew "equalsraf/neovim-qt/neovim-qt"\n',
            leaves='neovim-qt\n', formulae='neovim-qt\n', casks='',
        )
        assert 'Everything installed is declared' in out

    def test_declared_cask_does_not_vouch_for_installed_formula(self, tmp_path):
        """
        Formula and cask namespaces must stay separate.

        A flat name set let `cask "neovide"` silently satisfy an installed
        neovide FORMULA -- concealing that the same app was installed from two
        sources at once, which is the isort failure mode exactly.
        """
        out = _run_check(
            tmp_path,
            'cask "neovide"\n',
            leaves='neovide\n',      # the FORMULA is installed
            formulae='neovide\n',
            casks='neovide\n',       # and so is the cask
        )
        assert 'neovide' in out
        assert 'not in the Brewfile' in out

    def test_dependencies_are_not_flagged(self, tmp_path):
        """
        Only leaves installed on request are candidates. A formula that is
        merely a dependency never appears in `brew leaves`, so it must not be
        reported -- flagging hundreds of deps would make this check noise.
        """
        out = _run_check(
            tmp_path,
            'brew "ripgrep"\n',
            leaves='ripgrep\n',
            formulae='ripgrep\npcre2\nlibgit2\n',   # deps, not leaves
            casks='',
        )
        assert 'pcre2' not in out
        assert 'libgit2' not in out
        assert 'Everything installed is declared' in out

    def test_exits_zero_even_with_findings(self, tmp_path):
        """Report-only: it must not fail a doctor sweep."""
        bindir = tmp_path / 'bin'
        (tmp_path / 'repo' / 'machine-classes' / 'testclass' / 'brew').mkdir(parents=True)
        (tmp_path / 'home').mkdir()
        bindir.mkdir()
        (tmp_path / 'repo' / 'machine-classes' / 'testclass' / 'brew' / 'Brewfile').write_text('')
        stub = bindir / 'brew'
        stub.write_text(BREW_STUB)
        stub.chmod(0o755)
        env = dict(os.environ)
        env.update({
            'PATH': f"{bindir}:{env['PATH']}", 'HOME': str(tmp_path / 'home'),
            'DOTFILES_DIR': str(tmp_path / 'repo'),
            'DOTFILES_MACHINE_CLASS': 'testclass',
            'STUB_LEAVES': 'stray\n', 'STUB_FORMULAE': 'stray\n', 'STUB_CASKS': '',
        })
        proc = subprocess.run(['bash', str(SCRIPT)], cwd=str(tmp_path / 'repo'),
                              env=env, capture_output=True, text=True, timeout=60)
        assert proc.returncode == 0
        assert 'stray' in proc.stdout
