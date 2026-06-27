#!/usr/bin/env python3
"""
Sudo authentication helper for package manager upgrades.

Configures SUDO_ASKPASS so that when a command hits sudo, the system shows
a GUI dialog (just like pkexec on Linux). The password is handled by the OS
dialog and piped directly to sudo — same security model as pkexec/polkit.

- macOS: osascript dialog (password field with hidden input)
- Linux: ssh-askpass or similar installed helper

Override with DOTFILES_SUDO_MODE=gui|tty|skip
"""

import os
import platform
import shutil
import stat
from pathlib import Path


def _has_display() -> bool:
    """Detect if a GUI display is available."""
    system = platform.system()
    if system == 'Darwin':
        if os.environ.get('SSH_CONNECTION') and not os.environ.get('DISPLAY'):
            return False
        return True
    elif system == 'Linux':
        return bool(os.environ.get('DISPLAY') or os.environ.get('WAYLAND_DISPLAY'))
    return False


def _get_askpass_path() -> Path:
    """Get the path for the askpass helper script."""
    return Path.home() / '.dotfiles' / 'bin' / 'sudo-askpass.sh'


def _ensure_macos_askpass() -> str:
    """Create/verify the macOS askpass script using osascript."""
    askpass_path = _get_askpass_path()
    askpass_path.parent.mkdir(parents=True, exist_ok=True)

    askpass_path.write_text(
        '#!/bin/bash\n'
        '/usr/bin/osascript -e \'display dialog "Administrator password required" '
        'default answer "" with hidden answer with title "sudo" with icon caution\' '
        '-e \'text returned of result\' 2>/dev/null\n'
    )
    askpass_path.chmod(stat.S_IRWXU)
    return str(askpass_path)


def _find_linux_askpass() -> str | None:
    """Find a GUI askpass program on Linux."""
    candidates = [
        'ssh-askpass',
        '/usr/lib/ssh/x11-ssh-askpass',
        'ksshaskpass',
        'lxqt-openssh-askpass',
        'gnome-ssh-askpass',
        'x11-ssh-askpass',
    ]
    for candidate in candidates:
        if path := shutil.which(candidate):
            return path
    return None


def get_sudo_mode() -> str:
    """
    Determine the sudo mode to use.

    Returns one of: 'gui', 'tty', 'skip'
    """
    override = os.environ.get('DOTFILES_SUDO_MODE', '').lower()
    if override in ('gui', 'tty', 'skip'):
        return override

    if _has_display():
        return 'gui'
    return 'tty'


def get_sudo_askpass_env() -> dict:
    """
    Get environment variables to set SUDO_ASKPASS for GUI mode.

    When SUDO_ASKPASS is set, brew automatically passes -A to sudo,
    which triggers the askpass program (GUI dialog) instead of TTY input.

    Returns a dict of env vars to export, or empty dict for tty/skip modes.
    """
    mode = get_sudo_mode()

    if mode != 'gui':
        return {}

    system = platform.system()
    if system == 'Darwin':
        askpass = _ensure_macos_askpass()
        return {'SUDO_ASKPASS': askpass}
    elif system == 'Linux':
        askpass = _find_linux_askpass()
        if askpass:
            return {'SUDO_ASKPASS': askpass}
    return {}


def wrap_command_with_askpass(command: str) -> str:
    """
    Wrap a shell command with SUDO_ASKPASS export if GUI mode is active.

    When brew hits a cask needing sudo, it will see SUDO_ASKPASS in env
    and show the GUI dialog — same flow as pkexec on Linux.
    """
    env_vars = get_sudo_askpass_env()
    if not env_vars:
        return command

    exports = ' '.join(f'export {k}="{v}";' for k, v in env_vars.items())
    return f'{exports} {command}'
