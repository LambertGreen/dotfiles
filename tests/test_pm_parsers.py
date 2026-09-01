"""
Tests for PM-specific output parsers

These tests validate the parser refactoring and ensure correct counting
of outdated packages for each package manager.
"""
import pytest
from pathlib import Path
import sys

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))

from pm_parsers import (
    parse_pm_output,
    parse_zinit_status,
    parse_default_output,
    parse_brew_output,
    parse_brew_cask_output,
    parse_npm_output,
)


class TestZinitParser:
    """Tests for zinit status parser"""

    def test_no_updates_needed(self):
        """Test output when all plugins are up to date"""
        output = """Already up-to-date.
Status for plugin romkatv/powerlevel10k
On branch master
Your branch is up to date with 'origin/master'.

nothing to commit, working tree clean

Status for plugin Aloxaf/fzf-tab
On branch master
Your branch is up to date with 'origin/master'.

nothing to commit, working tree clean
"""
        assert parse_zinit_status(output) == 0

    def test_one_plugin_behind(self):
        """Test output when one plugin needs update"""
        output = """Already up-to-date.
Status for plugin romkatv/powerlevel10k
On branch master
Your branch is behind 'origin/master' by 3 commits.

Status for plugin Aloxaf/fzf-tab
On branch master
Your branch is up to date with 'origin/master'.
"""
        assert parse_zinit_status(output) == 1

    def test_multiple_plugins_behind(self):
        """Test output when multiple plugins need updates"""
        output = """Already up-to-date.
Status for plugin romkatv/powerlevel10k
On branch master
Your branch is behind 'origin/master' by 3 commits.

Status for plugin Aloxaf/fzf-tab
On branch master
Your branch is behind 'origin/master' by 1 commit.

Status for plugin zsh-users/zsh-autosuggestions
On branch master
Your branch is up to date with 'origin/master'.
"""
        assert parse_zinit_status(output) == 2

    def test_empty_output(self):
        """Test with empty output"""
        assert parse_zinit_status("") == 0
        assert parse_zinit_status(None) == 0

    def test_mixed_status_with_snippets(self):
        """Test output with snippets (non-git items) and plugins"""
        output = """Already up-to-date.
Status for /home/user/.zinit/snippets/OMZ::lib/completion.zsh
-rw-rw-r-- 1 user user 3.1K Oct  5 19:09 completion.zsh

Status for plugin romkatv/powerlevel10k
On branch master
Your branch is behind 'origin/master' by 2 commits.

Status for plugin Aloxaf/fzf-tab
On branch master
Your branch is up to date with 'origin/master'.
"""
        assert parse_zinit_status(output) == 1


class TestDefaultParser:
    """Tests for default line-counting parser"""

    def test_multiple_lines(self):
        """Test counting non-empty lines"""
        output = """package1 (1.0 -> 1.1)
package2 (2.0 -> 2.1)
package3 (3.0 -> 3.1)"""
        assert parse_default_output(output) == 3

    def test_empty_lines_ignored(self):
        """Test that empty lines are not counted"""
        output = """package1 (1.0 -> 1.1)

package2 (2.0 -> 2.1)

"""
        assert parse_default_output(output) == 2

    def test_empty_output(self):
        """Test with empty output"""
        assert parse_default_output("") == 0
        assert parse_default_output(None) == 0

    def test_whitespace_only_lines_ignored(self):
        """Test that whitespace-only lines are not counted"""
        output = """package1

\t
package2
    """
        assert parse_default_output(output) == 2


class TestPMOutputRouter:
    """Tests for the main parse_pm_output dispatcher"""

    def test_zinit_uses_specific_parser(self):
        """Test that zinit uses its specific parser"""
        output = """Status for plugin test/plugin
Your branch is behind 'origin/master' by 1 commit.
Your branch is behind 'origin/main' by 2 commits.
"""
        # Should count "behind" occurrences, not lines
        assert parse_pm_output('zinit', output) == 2

    def test_unknown_pm_uses_default_parser(self):
        """Test that unknown PMs use default line counting"""
        output = """package1
package2
package3
"""
        assert parse_pm_output('some-unknown-pm', output) == 3

    def test_apt_uses_default_parser(self):
        """Test that apt uses default parser"""
        output = """Inst package1 [1.0] (1.1 Ubuntu:22.04)
Inst package2 [2.0] (2.1 Ubuntu:22.04)
"""
        assert parse_pm_output('apt', output) == 2

    def test_brew_uses_specific_parser(self):
        """Test that brew counts outdated rows, not lines"""
        output = """package1 (1.0) < 1.1
package2 (2.0) < 2.1
"""
        assert parse_pm_output('brew', output) == 2

    def test_npm_uses_specific_parser(self):
        """Test that npm routes to the table parser, not line counting"""
        output = """Package  Current  Wanted  Latest  Location  Depended by
yarn       1.22.0  1.22.1  1.22.1  node_modules/yarn  global
"""
        assert parse_pm_output('npm', output) == 1

    def test_brew_cask_uses_specific_parser(self):
        """Test that brew-cask skips API-download progress lines"""
        output = """==> Downloading Homebrew API data
✔︎ JSON API packages.arm64_tahoe.jws.json
font-montserrat
"""
        assert parse_pm_output('brew-cask', output) == 1


class TestBrewOutdatedParser:
    """
    Tests for `brew update && brew outdated --verbose`.

    Fixtures are real output captured on 2026-09-01 (personal Mac). The check
    command runs `brew update` first, so update chatter dominates the output
    and must not be counted.
    """

    def test_no_op_check_counts_zero(self):
        """Regression: a fully-current check was reported as 3 outdated packages"""
        output = """==> Updating Homebrew...
==> Updated Homebrew from 74d6ac5e79 to c8e442d221.
No changes to formulae or casks.
"""
        assert parse_brew_output(output) == 0

    def test_already_up_to_date_counts_zero(self):
        output = """==> Updating Homebrew...
Already up-to-date.
"""
        assert parse_brew_output(output) == 0

    def test_counts_formulae_and_casks(self):
        """Formulae use `<`, casks use `!=`; both are outdated rows"""
        output = """==> Updating Homebrew...
Already up-to-date.
ast-grep (0.45.2) < 0.45.3
openssl@3 (3.6.3) < 3.6.4
claude (1.40609.0,f65e386db0db) != 1.40609.1,69aac03faa72
discord (0.0.409) != 0.0.410
"""
        assert parse_brew_output(output) == 4

    def test_new_formulae_listing_not_counted(self):
        """`brew update` lists new formulae/casks; those are not outdated packages"""
        output = """==> Updating Homebrew...
==> Updated Homebrew from 6.0.20 to 6.0.21.
Updated 2 taps (homebrew/core and homebrew/cask).
==> New Formulae
glci: Run GitLab CI/CD pipelines locally
shpool: Persistent shell session manager
==> New Casks
font-asap-sharp
markviewer: Minimal markdown editor

The 6.0.21 changelog can be found at:
  https://github.com/Homebrew/brew/releases/tag/6.0.21
uv (0.12.7) < 0.12.8
"""
        assert parse_brew_output(output) == 1

    def test_lock_error_counts_zero(self):
        """A failed check must not report its error text as packages"""
        output = """lockf: 200: already locked
Error: Another `brew update` process is already running.
Please wait for it to finish or terminate it to continue.
"""
        assert parse_brew_output(output) == 0

    def test_empty_output(self):
        assert parse_brew_output("") == 0
        assert parse_brew_output(None) == 0


class TestBrewCaskParser:
    """Tests for `brew outdated --cask --greedy` (one cask name per line)"""

    def test_skips_api_download_progress(self):
        """Regression: 2 progress lines + 1 cask was reported as 3 outdated"""
        output = """==> Downloading Homebrew API data
✔︎ JSON API packages.arm64_tahoe.jws.json
font-montserrat
"""
        assert parse_brew_cask_output(output) == 1

    def test_counts_bare_cask_names(self):
        output = """claude
discord
docker-desktop
firefox
"""
        assert parse_brew_cask_output(output) == 4

    def test_empty_output(self):
        assert parse_brew_cask_output("") == 0
        assert parse_brew_cask_output(None) == 0


class TestNpmParser:
    """Tests for `npm outdated -g` table output"""

    def test_warning_only_counts_zero(self):
        """
        Regression: npm prints nothing when current, but a stderr warning was
        counted as 1 outdated package on every single run.
        """
        output = ("Warning: Ignoring extra certs from "
                  "`/Users/lgreen/.devbar/certs/corporate-ca-bundle.pem`, "
                  "load failed: error:80000002:system library::"
                  "No such file or directory\n")
        assert parse_npm_output(output) == 0

    def test_counts_table_rows(self):
        output = """Package                    Current  Wanted  Latest  Location                             Depended by
@anthropic-ai/claude-code   1.0.0   1.1.0   1.1.0  node_modules/@anthropic-ai/claude…  global
yarn                        1.22.0  1.22.1  1.22.1 node_modules/yarn                   global
"""
        assert parse_npm_output(output) == 2

    def test_table_rows_counted_despite_warnings(self):
        """A warning alongside a real table must not inflate the count"""
        output = """Warning: Ignoring extra certs from `/missing/ca.pem`, load failed
Package  Current  Wanted  Latest  Location           Depended by
yarn      1.22.0  1.22.1  1.22.1  node_modules/yarn  global
"""
        assert parse_npm_output(output) == 1

    def test_npm_warn_lines_not_counted(self):
        output = """Package  Current  Wanted  Latest  Location           Depended by
yarn      1.22.0  1.22.1  1.22.1  node_modules/yarn  global
npm warn install-scripts 1 package had install scripts blocked
"""
        assert parse_npm_output(output) == 1

    def test_empty_output(self):
        assert parse_npm_output("") == 0
        assert parse_npm_output(None) == 0


class TestIntegrationWithPMCheck:
    """Integration tests to validate refactoring didn't break existing behavior"""

    def test_fake_pm_output_counting(self):
        """Test that fake PMs still work with default parser"""
        output = "fake-pm1: 5 packages outdated"
        assert parse_pm_output('fake-pm1', output) == 1

    def test_empty_output_returns_zero(self):
        """Test that empty output returns 0 for any PM"""
        for pm in ['zinit', 'apt', 'brew', 'npm', 'fake-pm1']:
            assert parse_pm_output(pm, "") == 0
            assert parse_pm_output(pm, None) == 0


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
