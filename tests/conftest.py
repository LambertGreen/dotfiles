"""
Pytest configuration and fixtures for dotfiles testing
"""
import os
import sys
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch
import pytest

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
# PM modules also import their siblings top-level (`from sudo_helper import …`).
sys.path.insert(0, str(PROJECT_ROOT / 'src' / 'dotfiles_pm'))

REAL_HOME = Path.home()


@pytest.fixture(autouse=True)
def _keep_askpass_out_of_real_home(tmp_path, monkeypatch):
    """Never let a test rewrite the real ~/.dotfiles/bin/sudo-askpass.sh.

    Reading a PM's `upgrade_command` in GUI mode (re)writes the askpass helper,
    and pm_executor reads it for every PM. Tests that set their own HOME
    (temp_home) keep their path; anything resolving to the real HOME is
    redirected under tmp_path.
    """
    def askpass_path():
        home = Path.home()
        base = tmp_path / 'askpass-home' if home == REAL_HOME else home
        return base / '.dotfiles' / 'bin' / 'sudo-askpass.sh'

    import importlib
    # The module is importable under two names; patch both.
    for name in ('sudo_helper', 'src.dotfiles_pm.sudo_helper'):
        monkeypatch.setattr(importlib.import_module(name), '_get_askpass_path', askpass_path)

@pytest.fixture
def temp_home(tmp_path):
    """Create a temporary home directory for testing"""
    home = tmp_path / "home"
    home.mkdir()
    with patch.dict(os.environ, {"HOME": str(home)}):
        yield home

@pytest.fixture
def dotfiles_root():
    """Return the actual dotfiles root directory"""
    return PROJECT_ROOT

@pytest.fixture
def mock_commands():
    """Mock command availability for testing PM detection"""
    commands = {}

    def command_exists(cmd):
        """Mock implementation of command -v"""
        return commands.get(cmd, False)

    mock = Mock()
    mock.commands = commands
    mock.command_exists = command_exists

    return mock

@pytest.fixture
def fake_pm_scripts(tmp_path):
    """Create fake package manager scripts for testing"""
    fake_pms = {}

    # Create fake-pm1
    pm1 = tmp_path / "fake-pm1"
    pm1.write_text("""#!/usr/bin/env bash
case "$1" in
    version) echo "FakePM1 v1.0.0" ;;
    outdated) echo "pkg-a 1.0.0 < 1.1.0" ;;
    upgrade) echo "Upgraded pkg-a to 1.1.0" ;;
    *) echo "FakePM1" ;;
esac
""")
    pm1.chmod(0o755)
    fake_pms['fake-pm1'] = pm1

    # Create fake-pm2
    pm2 = tmp_path / "fake-pm2"
    pm2.write_text("""#!/usr/bin/env bash
case "$1" in
    version) echo "FakePM2 v2.0.0" ;;
    outdated) echo "tool-x 2.0.0 < 3.0.0" ;;
    upgrade) echo "Upgraded tool-x to 3.0.0" ;;
    *) echo "FakePM2" ;;
esac
""")
    pm2.chmod(0o755)
    fake_pms['fake-pm2'] = pm2

    # Add to PATH
    original_path = os.environ.get('PATH', '')
    os.environ['PATH'] = f"{tmp_path}:{original_path}"

    yield fake_pms

    # Restore PATH
    os.environ['PATH'] = original_path

@pytest.fixture
def platform_mock():
    """Mock platform detection for cross-platform testing"""
    class PlatformMock:
        def __init__(self):
            self._platform = 'darwin'  # Default to macOS

        def set_platform(self, platform):
            """Set the mocked platform (darwin, linux, win32)"""
            self._platform = platform

        @property
        def is_macos(self):
            return self._platform == 'darwin'

        @property
        def is_linux(self):
            return self._platform == 'linux'

        @property
        def is_windows(self):
            return self._platform in ('win32', 'cygwin')

    return PlatformMock()
