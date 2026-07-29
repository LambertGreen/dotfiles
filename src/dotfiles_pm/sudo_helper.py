#!/usr/bin/env python3
"""
Sudo authentication helper for package manager upgrades.

Configures SUDO_ASKPASS so that when a command hits sudo, the system shows
a GUI dialog (just like pkexec on Linux). The password is handled by the OS
dialog and piped directly to sudo — same security model as pkexec/polkit.

- macOS: osascript dialog (password field with hidden input)
- Linux: ssh-askpass or similar installed helper

Override with DOTFILES_SUDO_MODE=gui|tty|skip

On Windows the model is different: elevation is done by a separate binary
(gsudo/sudo) rather than an askpass dialog, so see get_windows_elevation_command()
for how the elevation binary is resolved for commands like `choco upgrade`.
"""

import os
import platform
import shutil
import stat
from pathlib import Path
from typing import List


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


def _ensure_macos_askpass(reason: str = "") -> str:
    """Create/verify the macOS askpass script using osascript."""
    askpass_path = _get_askpass_path()
    askpass_path.parent.mkdir(parents=True, exist_ok=True)

    if reason:
        message = f"Administrator password required\\n\\n{reason}"
    else:
        message = "Administrator password required"

    askpass_path.write_text(
        '#!/bin/bash\n'
        f'/usr/bin/osascript -e \'display dialog "{message}" '
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


# Windows elevation binaries, in order of preference.
#
# gsudo is the reliable, org-friendly elevation tool (installed via scoop).
# The native Windows `sudo` (shipped in newer Windows builds as
# C:\Windows\System32\sudo.exe) is often DISABLED by organization policy, in
# which case it fails with "Sudo is disabled by your organization's policy"
# (exit code -2147023636). We therefore prefer gsudo and only fall back to the
# native sudo if gsudo is not on PATH.
_WINDOWS_ELEVATION_BINARIES = ('gsudo', 'sudo')


def get_windows_elevation_binary() -> str:
    """
    Resolve the elevation binary to use on Windows.

    Prefers gsudo (scoop-installed, org-friendly) and falls back to the native
    Windows `sudo` only if gsudo is not available. Resolution happens at runtime
    via shutil.which so the correct binary is chosen per machine.

    Override with DOTFILES_WINDOWS_ELEVATION=<binary> (e.g. 'gsudo', 'sudo').

    Returns the resolved binary name (found on PATH), the override value, or the
    first preference ('gsudo') as a last-resort default if none are found.
    """
    override = os.environ.get('DOTFILES_WINDOWS_ELEVATION', '').strip()
    if override:
        return override

    for binary in _WINDOWS_ELEVATION_BINARIES:
        if shutil.which(binary):
            return binary

    # Nothing found on PATH — default to the preferred binary. The command will
    # surface a clear "not found" error rather than silently using the wrong one.
    return _WINDOWS_ELEVATION_BINARIES[0]


def get_windows_elevation_command(command: List[str]) -> List[str]:
    """
    Prefix a command with the resolved Windows elevation binary.

    Example: ["choco", "upgrade", "all", "-y"]
          -> ["gsudo", "choco", "upgrade", "all", "-y"]

    Args:
        command: The command (as a list) that needs elevation.
    """
    return [get_windows_elevation_binary(), *command]


def get_sudo_askpass_env(reason: str = "") -> dict:
    """
    Get environment variables to set SUDO_ASKPASS for GUI mode.

    When SUDO_ASKPASS is set, brew automatically passes -A to sudo,
    which triggers the askpass program (GUI dialog) instead of TTY input.

    Args:
        reason: Context shown in the dialog explaining why sudo is needed.

    Returns a dict of env vars to export, or empty dict for tty/skip modes.
    """
    mode = get_sudo_mode()

    if mode != 'gui':
        return {}

    system = platform.system()
    if system == 'Darwin':
        askpass = _ensure_macos_askpass(reason)
        return {'SUDO_ASKPASS': askpass}
    elif system == 'Linux':
        askpass = _find_linux_askpass()
        if askpass:
            return {'SUDO_ASKPASS': askpass}
    return {}


def wrap_command_with_askpass(command: str, reason: str = "") -> str:
    """
    Wrap a shell command with SUDO_ASKPASS export if GUI mode is active.

    When brew hits a cask needing sudo, it will see SUDO_ASKPASS in env
    and show the GUI dialog — same flow as pkexec on Linux.

    Args:
        command: The shell command to wrap.
        reason: Context shown in the dialog explaining why sudo is needed.
    """
    env_vars = get_sudo_askpass_env(reason)
    if not env_vars:
        return command

    exports = ' '.join(f'export {k}="{v}";' for k, v in env_vars.items())
    return f'{exports} {command}'
