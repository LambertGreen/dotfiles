"""
Test the Python PM detection module
"""
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock
import pytest

# Add src directory to path for imports
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.dotfiles_pm.pm_detect import detect_all_pms


class TestPythonPMDetection:
    """Test Python-based PM detection"""

    def test_detect_all_pms_basic(self):
        """Test basic PM detection functionality"""
        with patch('shutil.which') as mock_which:
            mock_which.side_effect = lambda cmd: {
                'brew': '/opt/homebrew/bin/brew',
                'npm': '/usr/local/bin/npm',
                'pipx': '/usr/local/bin/pipx'  # pip3 replaced with pipx
            }.get(cmd)

            with patch('pathlib.Path.home') as mock_home:
                mock_home.return_value = Path('/fake/home')
                with patch('pathlib.Path.exists', return_value=False):
                    with patch('platform.system', return_value='Darwin'):  # macOS to get brew-cask
                        result = detect_all_pms()

            assert 'brew' in result
            assert 'brew-cask' in result  # brew-cask is now detected separately on macOS
            assert 'npm' in result
            assert 'pipx' in result  # pip replaced with pipx
            assert len(result) == 4

    def test_detect_directory_based_pms(self, temp_home):
        """Test detection of directory-based PMs"""
        # Create fake directories
        emacs_dir = temp_home / '.emacs.d'
        emacs_dir.mkdir()
        zinit_dir = temp_home / '.zinit'
        zinit_dir.mkdir()

        with patch('shutil.which', return_value=None):
            with patch('pathlib.Path.home', return_value=temp_home):
                result = detect_all_pms()

        assert 'emacs' in result
        assert 'zinit' in result

    def test_detect_fake_pms(self, fake_pm_scripts):
        """Test detection of fake PMs for testing"""
        import shutil
        import os

        # Fake PMs need to be explicitly enabled via environment variable
        with patch.dict(os.environ, {'DOTFILES_PM_ENABLED': 'fake-pm1,fake-pm2'}):
            result = detect_all_pms()

        assert 'fake-pm1' in result
        assert 'fake-pm2' in result

    def test_no_pms_detected(self):
        """Test behavior when no PMs are detected"""
        with patch('shutil.which', return_value=None):
            with patch('pathlib.Path.exists', return_value=False):
                result = detect_all_pms()

        assert result == []

    def test_cross_platform_detection(self):
        """Test that detection works across platforms"""
        platform_pms = {
            'brew': '/opt/homebrew/bin/brew',  # macOS
            'apt': '/usr/bin/apt',             # Linux
            'choco': 'C:\\ProgramData\\chocolatey\\bin\\choco.exe',  # Windows
            'winget': 'C:\\Windows\\system32\\winget.exe'  # Windows
        }

        with patch('shutil.which') as mock_which:
            mock_which.side_effect = platform_pms.get
            with patch('pathlib.Path.exists', return_value=False):
                result = detect_all_pms()

        # Should detect all available PMs regardless of platform
        assert 'brew' in result
        assert 'apt' in result
        assert 'choco' in result
        assert 'winget' in result

    @pytest.mark.parametrize("pm_name,command", [
        ('brew', 'brew'),
        ('npm', 'npm'),
        ('pipx', 'pipx'),  # pip3 replaced with pipx
        ('cargo', 'cargo'),
        ('gem', 'gem'),
        ('neovim', 'nvim'),  # Note: nvim command -> neovim name
    ])
    def test_individual_pm_detection(self, pm_name, command):
        """Test detection of individual package managers"""
        with patch('shutil.which') as mock_which:
            mock_which.side_effect = lambda cmd: f'/path/to/{cmd}' if cmd == command else None
            with patch('pathlib.Path.exists', return_value=False):
                # For brew, we need to handle brew-cask detection on macOS
                if pm_name == 'brew':
                    with patch('platform.system', return_value='Darwin'):
                        result = detect_all_pms()
                    # brew on macOS also detects brew-cask
                    assert pm_name in result
                    assert 'brew-cask' in result
                    assert len(result) == 2
                else:
                    result = detect_all_pms()
                    assert pm_name in result
                    assert len(result) == 1
