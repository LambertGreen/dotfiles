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

from pm_parsers import parse_pm_output, parse_zinit_status, parse_default_output


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

    def test_brew_uses_default_parser(self):
        """Test that brew uses default parser"""
        output = """package1 (1.0) < 1.1
package2 (2.0) < 2.1
"""
        assert parse_pm_output('brew', output) == 2


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
