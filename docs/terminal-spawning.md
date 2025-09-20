# Terminal Spawning Architecture

## Overview

The terminal spawning system provides a way to run interactive package manager commands (like `brew upgrade`) in separate terminal windows, preserving user interaction capabilities, progress bars, and colored output.

## Current Implementation

### Architecture

```
TerminalExecutor (ABC)
├── DarwinTerminalExecutor    (macOS Terminal.app)
├── LinuxTerminalExecutor     (gnome-terminal, konsole, xterm)
├── WSLTerminalExecutor       (Windows Terminal via WSL)
├── WindowsTerminalExecutor   (Windows Terminal, cmd.exe)
└── TmuxTerminalExecutor      (Future: tmux-based execution)
```

### Usage

```python
from terminal_executor import spawn_in_terminal

# Simple usage
result = spawn_in_terminal('brew upgrade', title='Homebrew Upgrade')

# Using the class directly
from terminal_executor import create_terminal_executor

executor = create_terminal_executor()
result = executor.spawn('apt update && apt upgrade', title='System Update')
```

### Result Format

```python
{
    'status': 'spawned',     # or 'failed'
    'platform': 'darwin',    # detected platform
    'method': 'Terminal.app', # terminal used
    'command': 'brew upg...' # truncated command
}
```

## Interactive Package Managers

Currently configured for terminal spawning:
- `brew` - Homebrew (macOS/Linux)
- `apt` - APT (Debian/Ubuntu)

Other package managers use subprocess for non-interactive execution.

## Future Tmux Extension

### Detection

The system already detects tmux environment:
```python
def _in_tmux(self) -> bool:
    return os.environ.get('TMUX') is not None
```

### Planned Tmux Features

1. **Session Management**
   ```python
   class TmuxTerminalExecutor(TerminalExecutor):
       def spawn(self, command, title=None):
           session = f"dotfiles-{title or 'cmd'}"
           # Create new window in current session
           subprocess.run(['tmux', 'new-window', '-n', session, command])
   ```

2. **Status Tracking**
   ```python
   def check_status(self, session_name):
       # Capture pane content to check if complete
       result = subprocess.run(['tmux', 'capture-pane', '-t', session_name, '-p'])
       return self._parse_completion_status(result.stdout)
   ```

3. **AI-Friendly Mode**
   ```python
   def spawn_tracked(self, command, title=None):
       # Create session with logging
       session = self._create_session(command, title)
       # Write lock file for idempotency
       self._write_lock_file(session)
       # Return trackable session ID
       return {'session': session, 'lock': lock_file}
   ```

4. **Split Pane Option**
   ```python
   def spawn_split(self, command, direction='horizontal'):
       # Split current pane instead of new window
       flag = '-h' if direction == 'horizontal' else '-v'
       subprocess.run(['tmux', 'split-window', flag, command])
   ```

## Configuration

Future configuration options:
```bash
# ~/.dotfiles.env
DOTFILES_TERMINAL_MODE=tmux      # auto|native|tmux
DOTFILES_TMUX_SPLIT=true         # Use splits instead of windows
DOTFILES_TMUX_SESSION=dotfiles   # Session name for operations
```

## Platform Support

| Platform | Current Terminal | Future Tmux |
|----------|-----------------|-------------|
| macOS | Terminal.app via osascript | ✅ |
| Linux | gnome-terminal, konsole, xterm | ✅ |
| WSL | Windows Terminal | ✅ |
| Windows | Windows Terminal, cmd.exe | ❌ (native) |

## Extension Points

The factory pattern makes it easy to add new terminal types:

```python
def create_terminal_executor(force_system=False):
    # Future: Check for user preference
    if os.getenv('DOTFILES_TERMINAL_MODE') == 'tmux':
        if shutil.which('tmux'):
            return TmuxTerminalExecutor()

    # Current: Platform detection
    platform = detect_platform()
    # ... return appropriate executor
```

## Testing

Test terminal spawning:
```bash
# Direct Python test
python3 -c "from src.dotfiles_pm.terminal_executor import spawn_in_terminal; print(spawn_in_terminal('echo test', 'Test'))"

# Test with package manager
python3 -m src.dotfiles_pm.pm upgrade brew
```

## Benefits

1. **Immediate Feedback** - Users see real-time progress
2. **Interactivity** - Can respond to prompts
3. **Colors & Formatting** - Preserves terminal colors
4. **Non-blocking** - Python continues while terminal runs
5. **Extensible** - Easy to add tmux or other terminals
