"""
Tests for PM base classes and OOP architecture

Validates the new OOP design for package managers.
"""
import pytest
from pathlib import Path
import sys

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))

from pm_base import PackageManager, PMParser, DefaultParser
from pm_registry import get_pm, PM_REGISTRY
from pms.zinit import ZinitPM, ZinitParser


class TestParsers:
    """Test parser classes"""

    def test_default_parser(self):
        """Test default line-counting parser"""
        parser = DefaultParser()
        output = """package1
package2
package3"""
        assert parser.count_outdated(output) == 3

    def test_zinit_parser(self):
        """Test zinit-specific parser"""
        parser = ZinitParser()
        output = """Status for plugin test/plugin
Your branch is behind 'origin/master' by 1 commit.
Your branch is behind 'origin/main' by 2 commits.
"""
        assert parser.count_outdated(output) == 2

    def test_parser_empty_output(self):
        """Test parsers handle empty output"""
        default_parser = DefaultParser()
        zinit_parser = ZinitParser()

        assert default_parser.count_outdated("") == 0
        assert default_parser.count_outdated(None) == 0
        assert zinit_parser.count_outdated("") == 0
        assert zinit_parser.count_outdated(None) == 0


class TestZinitPM:
    """Test ZinitPM class"""

    def test_zinit_initialization(self):
        """Test zinit PM is properly initialized"""
        pm = ZinitPM()
        assert pm.name == 'zinit'
        assert isinstance(pm.parser, ZinitParser)

    def test_zinit_commands(self):
        """Test zinit commands are defined"""
        pm = ZinitPM()
        assert pm.check_command == ["zsh -i -c 'zinit status --all'"]
        assert "zinit self-update" in pm.upgrade_command[0]
        assert "zinit update --all" in pm.upgrade_command[0]

    def test_zinit_metadata(self):
        """Test zinit metadata"""
        pm = ZinitPM()
        assert pm.requires_sudo == False
        assert pm.priority == 10

    def test_zinit_parse_output(self):
        """Test zinit can parse its check output"""
        pm = ZinitPM()
        output = """Status for plugin test/plugin
Your branch is behind 'origin/master' by 1 commit.
"""
        assert pm.parse_check_output(output) == 1


class TestPMRegistry:
    """Test PM registry and lookup"""

    def test_registry_contains_zinit(self):
        """Test zinit is registered"""
        assert 'zinit' in PM_REGISTRY
        assert isinstance(PM_REGISTRY['zinit'], ZinitPM)

    def test_get_pm_success(self):
        """Test getting registered PM"""
        pm = get_pm('zinit')
        assert isinstance(pm, ZinitPM)
        assert pm.name == 'zinit'

    def test_get_pm_not_found(self):
        """Test getting unregistered PM raises error"""
        with pytest.raises(KeyError, match="not registered"):
            get_pm('nonexistent-pm')


class TestBackwardCompatibility:
    """Test new OOP design maintains backward compatibility"""

    def test_zinit_parser_matches_functional(self):
        """Test ZinitParser produces same results as functional version"""
        from pm_parsers import parse_zinit_status

        output = """Status for plugin1
Your branch is behind 'origin/master' by 1 commit.
Status for plugin2
Your branch is behind 'origin/master' by 2 commits.
"""
        parser = ZinitParser()
        assert parser.count_outdated(output) == parse_zinit_status(output)

    def test_default_parser_matches_functional(self):
        """Test DefaultParser produces same results as functional version"""
        from pm_parsers import parse_default_output

        output = """line1
line2
line3"""
        parser = DefaultParser()
        assert parser.count_outdated(output) == parse_default_output(output)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
