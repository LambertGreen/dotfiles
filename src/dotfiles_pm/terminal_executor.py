#!/usr/bin/env python3
"""
Terminal Executor Module

Handles spawning commands in terminal windows for interactive operations.
Designed to be extensible for future tmux integration.
"""

import os
import sys
import subprocess
import shutil
import time
import json
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, Tuple, List
from pathlib import Path

# Global registry to track spawned terminals
_spawned_terminals: List[Dict[str, Any]] = []

def _get_registry_file() -> Path:
    """Get the path to the terminal registry file"""
    return Path.home() / '.dotfiles' / 'logs' / 'terminal_registry.json'

def _load_terminal_registry() -> List[Dict[str, Any]]:
    """Load terminal registry from file"""
    registry_file = _get_registry_file()
    if registry_file.exists():
        try:
            return json.loads(registry_file.read_text())
        except Exception:
            return []
    return []

def _save_terminal_registry(terminals: List[Dict[str, Any]]) -> None:
    """Save terminal registry to file"""
    registry_file = _get_registry_file()
    registry_file.parent.mkdir(parents=True, exist_ok=True)
    registry_file.write_text(json.dumps(terminals, indent=2))


class TerminalExecutor(ABC):
    """Abstract base class for terminal executors"""

    @abstractmethod
    def spawn(self, command: str, title: Optional[str] = None) -> Dict[str, Any]:
        """Spawn command in terminal"""
        pass

    def spawn_tracked(self, command: str, operation: str, auto_close: bool = False) -> Dict[str, Any]:
        """
        Spawn command with logging and status tracking.

        Args:
            command: Command to execute
            operation: Name of operation (e.g., 'brew-upgrade')
            auto_close: Auto-close terminal on success

        Returns:
            Dict with status, log_file, and status_file paths
        """
        tracked_cmd, log_file, status_file = self.create_tracked_command(command, operation, auto_close)
        result = self.spawn(tracked_cmd, title=operation)

        # Register terminal for tracking
        terminal_info = {
            **result,
            'log_file': log_file,
            'status_file': status_file,
            'operation': operation,
            'executor': self
        }

        # Add to both in-memory and persistent registry
        global _spawned_terminals
        _spawned_terminals.append(terminal_info)

        # Append to persistent registry
        current_registry = _load_terminal_registry()
        # Create serializable version without executor
        serializable_info = {k: v for k, v in terminal_info.items() if k != 'executor'}
        current_registry.append(serializable_info)
        _save_terminal_registry(current_registry)


        return terminal_info

    def create_tracked_command(self, base_cmd: str, operation: str, auto_close: bool = False) -> Tuple[str, str, str]:
        """
        Create command with logging and status tracking using wrapper script.

        Args:
            base_cmd: Base command to execute
            operation: Operation name for file naming
            auto_close: Auto-close terminal on success

        Returns:
            Tuple of (tracked_command, log_file_path, status_file_path)
        """
        timestamp = int(time.time())
        log_dir = Path.home() / '.dotfiles' / 'logs'
        log_dir.mkdir(parents=True, exist_ok=True)

        # Sanitize operation name for filename: replace spaces and special chars with hyphens
        import re
        safe_operation = re.sub(r'[^a-zA-Z0-9_-]+', '-', operation)
        safe_operation = re.sub(r'-+', '-', safe_operation).strip('-')  # Clean up multiple hyphens

        log_file = str(log_dir / f"{safe_operation}-{timestamp}.log")
        status_file = str(log_dir / f"{safe_operation}-{timestamp}.status")

        # Get the wrapper script path - try multiple locations
        wrapper_script = None

        # First try: DOTFILES_DIR environment variable
        if 'DOTFILES_DIR' in os.environ:
            wrapper_script = Path(os.environ['DOTFILES_DIR']) / 'scripts' / 'run_tracked.sh'

        # Second try: relative to this Python module
        if not wrapper_script or not wrapper_script.exists():
            wrapper_script = Path(__file__).parent.parent.parent / 'scripts' / 'run_tracked.sh'

        # Third try: ~/.dotfiles
        if not wrapper_script.exists():
            wrapper_script = Path.home() / '.dotfiles' / 'scripts' / 'run_tracked.sh'

        wrapper_script = str(wrapper_script)

        # Use wrapper script for clean output
        auto_close_arg = 'true' if auto_close else 'false'
        tracked_cmd = f'{wrapper_script} "{operation}" "{base_cmd}" "{log_file}" "{status_file}" {auto_close_arg}'

        return tracked_cmd, log_file, status_file

    def check_status(self, status_file: str) -> Dict[str, Any]:
        """
        Check the status of a tracked operation.

        Args:
            status_file: Path to status file

        Returns:
            Dict with status information or None if not found
        """
        try:
            status_path = Path(status_file)
            if status_path.exists():
                return json.loads(status_path.read_text())
            return {'status': 'running'}
        except Exception as e:
            return {'status': 'error', 'error': str(e)}

    def close_terminal(self, terminal_info: Dict[str, Any]) -> bool:
        """
        Close a spawned terminal.

        Args:
            terminal_info: Result from spawn() containing terminal details

        Returns:
            True if successfully closed, False otherwise
        """
        return False  # Default implementation does nothing

    def _in_tmux(self) -> bool:
        """Check if running inside tmux"""
        return os.environ.get('TMUX') is not None


class DarwinTerminalExecutor(TerminalExecutor):
    """macOS Terminal.app executor"""

    def spawn(self, command: str, title: Optional[str] = None) -> Dict[str, Any]:
        """Spawn command in Terminal.app using osascript"""
        try:
            # Escape quotes in command for AppleScript
            escaped_cmd = command.replace('"', '\\"')
            # Use default shell with user's profile for proper PATH
            # Capture window count before and after to identify new window
            script = f'''
            tell application "Terminal"
                set windowsBefore to count of windows
                set newTab to do script "{escaped_cmd}"
                set windowsAfter to count of windows
                if windowsAfter > windowsBefore then
                    return id of window 1
                else
                    return "same_window"
                end if
            end tell
            '''
            result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)

            # Extract window ID from AppleScript output
            window_id = None
            if result.returncode == 0 and result.stdout.strip():
                window_id = result.stdout.strip()

            return {
                'status': 'spawned' if result.returncode == 0 else 'failed',
                'platform': 'darwin',
                'method': 'Terminal.app',
                'command': command[:50] + '...' if len(command) > 50 else command,
                'window_id': window_id
            }
        except Exception as e:
            return {
                'status': 'failed',
                'error': str(e),
                'platform': 'darwin',
                'method': 'Terminal.app'
            }

    def close_terminal(self, terminal_info: Dict[str, Any]) -> bool:
        """Close Terminal.app window using AppleScript"""
        window_id = terminal_info.get('window_id')
        if not window_id or window_id == "same_window":
            return False

        try:
            script = f'''
            tell application "Terminal"
                close window id {window_id}
            end tell
            '''
            result = subprocess.run(['osascript', '-e', script], capture_output=True)
            return result.returncode == 0
        except Exception:
            return False


class LinuxTerminalExecutor(TerminalExecutor):
    """Linux terminal executor with fallback chain"""

    def spawn(self, command: str, title: Optional[str] = None) -> Dict[str, Any]:
        """Try various Linux terminals in order of preference"""
        terminals = [
            ('gnome-terminal', ['gnome-terminal', '--', 'bash', '-c', command]),
            ('konsole', ['konsole', '-e', 'bash', '-c', command]),
            ('xfce4-terminal', ['xfce4-terminal', '-e', f'bash -c "{command}"']),
            ('xterm', ['xterm', '-e', command])
        ]

        for terminal_name, cmd in terminals:
            if shutil.which(terminal_name.split()[0]):
                try:
                    subprocess.Popen(cmd)
                    return {
                        'status': 'spawned',
                        'platform': 'linux',
                        'method': terminal_name,
                        'command': command[:50] + '...' if len(command) > 50 else command
                    }
                except Exception:
                    continue

        # Fallback to blocking execution
        try:
            os.system(command)
            return {
                'status': 'spawned',
                'platform': 'linux',
                'method': 'os.system (blocking)',
                'command': command[:50] + '...' if len(command) > 50 else command
            }
        except Exception as e:
            return {
                'status': 'failed',
                'error': str(e),
                'platform': 'linux',
                'method': 'none'
            }


class WSLTerminalExecutor(TerminalExecutor):
    """Windows Subsystem for Linux terminal executor"""

    def spawn(self, command: str, title: Optional[str] = None) -> Dict[str, Any]:
        """Spawn command in Windows Terminal from WSL"""
        try:
            # Try Windows Terminal first
            if shutil.which('wt.exe'):
                subprocess.Popen(['wt.exe', command])
                method = 'Windows Terminal'
            else:
                # Fallback to cmd
                subprocess.Popen(['cmd.exe', '/c', 'start', command])
                method = 'cmd.exe'

            return {
                'status': 'spawned',
                'platform': 'wsl',
                'method': method,
                'command': command[:50] + '...' if len(command) > 50 else command
            }
        except Exception as e:
            return {
                'status': 'failed',
                'error': str(e),
                'platform': 'wsl',
                'method': 'none'
            }


class WindowsTerminalExecutor(TerminalExecutor):
    """Native Windows terminal executor"""

    def spawn(self, command: str, title: Optional[str] = None) -> Dict[str, Any]:
        """Spawn command in Windows Terminal or cmd"""
        try:
            if shutil.which('wt'):
                subprocess.Popen(['wt', command])
                method = 'Windows Terminal'
            else:
                subprocess.Popen(['cmd', '/c', 'start', 'cmd', '/k', command])
                method = 'cmd.exe'

            return {
                'status': 'spawned',
                'platform': 'windows',
                'method': method,
                'command': command[:50] + '...' if len(command) > 50 else command
            }
        except Exception as e:
            return {
                'status': 'failed',
                'error': str(e),
                'platform': 'windows',
                'method': 'none'
            }


class TmuxTerminalExecutor(TerminalExecutor):
    """Tmux-based terminal executor (future enhancement)"""

    def spawn(self, command: str, title: Optional[str] = None) -> Dict[str, Any]:
        """
        Spawn command in tmux window or pane

        TODO: Implement in Phase 2
        - New window vs split-pane decision
        - Session management
        - Status tracking
        """
        # For now, delegate to platform executor
        executor = create_terminal_executor(force_system=True)
        return executor.spawn(command, title)


def detect_platform() -> str:
    """Detect the current platform"""
    if sys.platform == 'darwin':
        return 'darwin'
    elif sys.platform == 'win32':
        return 'windows'
    elif sys.platform.startswith('linux'):
        # Check for WSL
        if 'microsoft' in os.uname().release.lower():
            return 'wsl'
        return 'linux'
    else:
        return 'unknown'


def create_terminal_executor(force_system: bool = False) -> TerminalExecutor:
    """
    Factory function to create appropriate terminal executor.

    Args:
        force_system: Force system terminal even if in tmux

    Returns:
        Platform-appropriate TerminalExecutor instance
    """
    # Check for tmux first (unless forced to use system)
    if not force_system and os.environ.get('TMUX'):
        return TmuxTerminalExecutor()

    platform = detect_platform()

    executors = {
        'darwin': DarwinTerminalExecutor,
        'linux': LinuxTerminalExecutor,
        'wsl': WSLTerminalExecutor,
        'windows': WindowsTerminalExecutor
    }

    executor_class = executors.get(platform, LinuxTerminalExecutor)
    return executor_class()


# Convenience functions
def spawn_in_terminal(command: str, title: Optional[str] = None) -> Dict[str, Any]:
    """
    Convenience function to spawn command in terminal.

    Args:
        command: Command to execute
        title: Optional title for the terminal

    Returns:
        Dict with execution status
    """
    executor = create_terminal_executor()
    return executor.spawn(command, title)


def get_spawned_terminals() -> List[Dict[str, Any]]:
    """Get list of all spawned terminals"""
    return _load_terminal_registry()


def close_all_terminals() -> int:
    """
    Close all spawned terminals.

    Returns:
        Number of terminals successfully closed
    """
    spawned_terminals = _load_terminal_registry()
    closed_count = 0

    for terminal_info in spawned_terminals:
        # Recreate executor if not present (from persistent registry)
        executor = terminal_info.get('executor')
        if not executor:
            executor = create_terminal_executor()

        if executor and executor.close_terminal(terminal_info):
            closed_count += 1

    # Clear both registries
    global _spawned_terminals
    _spawned_terminals.clear()
    _save_terminal_registry([])
    return closed_count


def prompt_close_terminals() -> None:
    """Prompt user to close spawned terminals"""
    spawned_terminals = _load_terminal_registry()

    if not spawned_terminals:
        return

    print(f"\n🖥️  {len(spawned_terminals)} terminal(s) were opened during this session:")
    for i, terminal in enumerate(spawned_terminals, 1):
        print(f"  {i}. {terminal.get('operation', 'Unknown operation')}")

    try:
        while True:
            choice = input(f"\nClose all terminals? [Y/n]: ").strip().lower()
            if choice in ['y', 'yes', '']:  # Empty input defaults to yes
                closed = close_all_terminals()
                print(f"✅ Closed {closed} terminal(s)")
                break
            elif choice in ['n', 'no']:
                print(f"📋 Terminals left open for review")
                break
            else:
                print(f"Please enter 'y' or 'n' (default: y)")
    except (EOFError, KeyboardInterrupt):
        # Handle cases where input is not available (Claude Code, CI, etc.)
        print(f"\n📋 Terminals left open for review")


def spawn_tracked(command: str, operation: str, auto_close: bool = False, test_mode: bool = False) -> Dict[str, Any]:
    """
    Spawn command with logging and status tracking.

    Args:
        command: Command to execute
        operation: Name of operation (e.g., 'brew-upgrade')
        auto_close: Auto-close terminal on success
        test_mode: Run locally for testing instead of spawning terminal

    Returns:
        Dict with status, log_file, and status_file paths
    """
    if test_mode or os.environ.get('DOTFILES_TEST_MODE') == 'true':
        # Run locally for testing
        import tempfile
        import subprocess

        with tempfile.TemporaryDirectory() as tmpdir:
            log_file = f"{tmpdir}/{operation}.log"
            status_file = f"{tmpdir}/{operation}.status"

            print(f"TEST MODE: Running {operation} locally")
            proc = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=10
            )

            # Write results
            with open(log_file, 'w') as f:
                f.write(proc.stdout)
                f.write(proc.stderr)

            with open(status_file, 'w') as f:
                import json
                json.dump({
                    'status': 'completed',
                    'exit_code': proc.returncode,
                    'test_mode': True
                }, f)

            return {
                'status': 'completed',
                'platform': 'test',
                'method': 'local',
                'log_file': log_file,
                'status_file': status_file,
                'operation': operation,
                'exit_code': proc.returncode
            }

    executor = create_terminal_executor()
    return executor.spawn_tracked(command, operation, auto_close)
