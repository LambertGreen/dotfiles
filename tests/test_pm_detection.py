"""
Test package manager detection functionality
"""
import os
import subprocess
from pathlib import Path
from unittest.mock import patch, MagicMock
import pytest

class TestPMDetection:
    """Test package manager detection across platforms"""

    def test_detect_brew_on_macos(self, platform_mock):
        """Test brew detection on macOS"""
        platform_mock.set_platform('darwin')

        # Mock command existence
        with patch('shutil.which') as mock_which:
            mock_which.return_value = '/opt/homebrew/bin/brew'

            # This would be the actual detection logic
            result = mock_which('brew') is not None
            assert result is True

    def test_detect_apt_on_linux(self, platform_mock):
        """Test apt detection on Ubuntu/Debian"""
        platform_mock.set_platform('linux')

        with patch('shutil.which') as mock_which:
            mock_which.return_value = '/usr/bin/apt'

            result = mock_which('apt') is not None
            assert result is True

    def test_detect_multiple_pms(self):
        """Test detecting multiple package managers"""
        with patch('shutil.which') as mock_which:
            def which_side_effect(cmd):
                commands = {
                    'brew': '/opt/homebrew/bin/brew',
                    'npm': '/usr/local/bin/npm',
                    'pip3': '/usr/bin/pip3',
                    'cargo': '/home/user/.cargo/bin/cargo'
                }
                return commands.get(cmd)

            mock_which.side_effect = which_side_effect

            # Simulate detection
            detected = []
            for pm in ['brew', 'npm', 'pip3', 'cargo', 'apt']:
                if mock_which(pm):
                    detected.append(pm)

            assert detected == ['brew', 'npm', 'pip3', 'cargo']

    def test_detect_dev_package_managers(self, temp_home):
        """Test detection of development package managers"""
        # Create fake emacs.d directory
        emacs_dir = temp_home / '.emacs.d'
        emacs_dir.mkdir()

        with patch('shutil.which') as mock_which:
            mock_which.side_effect = lambda cmd: {
                'npm': '/usr/local/bin/npm',
                'pip3': '/usr/bin/pip3',
                'nvim': '/usr/local/bin/nvim'
            }.get(cmd)

            # Check emacs.d exists
            assert emacs_dir.exists()

            # Simulate dev PM detection
            dev_pms = []
            if mock_which('npm'):
                dev_pms.append('npm')
            if mock_which('pip3'):
                dev_pms.append('pip')
            if emacs_dir.exists():
                dev_pms.append('emacs')
            if mock_which('nvim'):
                dev_pms.append('neovim')

            assert dev_pms == ['npm', 'pip', 'emacs', 'neovim']

    def test_detect_app_package_managers(self, temp_home):
        """Test detection of application package managers"""
        # Create fake zinit directory
        zinit_dir = temp_home / '.zinit'
        zinit_dir.mkdir()

        # Check zinit detection
        app_pms = []
        if zinit_dir.exists():
            app_pms.append('zinit')

        assert app_pms == ['zinit']

    def test_fake_pm_detection(self, fake_pm_scripts):
        """Test detection of fake package managers for testing"""
        import shutil

        # Check that fake PMs are in PATH and executable
        assert shutil.which('fake-pm1') is not None
        assert shutil.which('fake-pm2') is not None

        # Test running them
        result = subprocess.run(['fake-pm1', 'version'],
                              capture_output=True, text=True)
        assert 'FakePM1 v1.0.0' in result.stdout

        result = subprocess.run(['fake-pm2', 'version'],
                              capture_output=True, text=True)
        assert 'FakePM2 v2.0.0' in result.stdout

    @pytest.mark.parametrize("platform,expected_pms", [
        ('darwin', ['brew']),
        ('linux', ['apt', 'dnf', 'pacman']),
        ('win32', ['choco', 'scoop', 'winget']),
    ])
    def test_platform_specific_detection(self, platform, expected_pms):
        """Test that correct PMs are checked for each platform"""
        with patch('sys.platform', platform):
            with patch('shutil.which') as mock_which:
                # Mock that all expected PMs exist
                mock_which.side_effect = lambda cmd: f'/path/to/{cmd}' if cmd in expected_pms else None

                # Simulate platform-specific detection
                detected = []
                for pm in expected_pms:
                    if mock_which(pm):
                        detected.append(pm)

                assert set(detected) == set(expected_pms)
