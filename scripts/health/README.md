# Dotfiles Health Check Tool

A comprehensive tool for validating and maintaining dotfiles symlink health across different platforms and environments.

## Overview

This tool provides health checking and cleanup functionality for dotfiles configurations, detecting broken symlinks, legacy configurations, and providing recommendations for system maintenance.

## Features

- **Health Check**: Comprehensive validation of dotfiles symlink integrity
- **Cross-Platform**: Supports macOS, Linux, Windows (MSYS2)
- **Legacy Detection**: Identifies old vs new configuration structures
- **Cleanup**: Safe removal of broken symlinks
- **Testing**: Full test suite with simulated environments
- **Logging**: Optional logging for migration tracking

## Usage

### As a Library (Recommended)

```bash
# Source the library
source tools/dotfiles-health/dotfiles-health.sh

# Run health check
dotfiles_health_check

# Run with verbose output
dotfiles_health_check --verbose

# Run with logging
dotfiles_health_check --log "health-check-$(date +%Y%m%d-%H%M%S).log"

# Clean up broken links (dry run)
dotfiles_cleanup_broken_links

# Clean up broken links (remove)
dotfiles_cleanup_broken_links --remove
```

### Via Justfile Integration

```bash
# Health check
just check-health

# Verbose health check
just check-health-verbose

# Cleanup broken links (dry run)
just cleanup-broken-links-dry-run

# Cleanup broken links (remove)
just cleanup-broken-links-remove
```

## Health Check States

| Status | Description | Action |
|--------|-------------|---------|
| **HEALTHY** 💚 | All systems operational | None needed |
| **WARNING** 💛 | Minor issues, system functional | Review warnings |
| **LEGACY** 🟠 | Using old configuration structure | Run migration |
| **MIXED** 🟠 | Partial migration state | Complete migration |
| **EMPTY** 🟠 | No configurations found | Run initial setup |
| **CRITICAL** 🔴 | Broken symlinks or missing tools | Fix critical issues |

## Environment Variables

- `DOTFILES_DIR`: Override dotfiles directory location
- `TEST_HOME`: Override home directory for testing
- `TEST_PLATFORM`: Force platform detection (e.g., "windows")
- `TEST_MODE`: Enable test mode (skips git validation)

## Testing

Run the comprehensive test suite:

```bash
bash tools/dotfiles-health/test-dotfiles-health.sh
```

The test suite covers:
- New system configurations
- Legacy system detection
- Mixed state detection
- Broken link identification
- XDG config directories
- Windows AppData paths
- Empty system scenarios

## Implementation Details

### Architecture

- **Single Library**: All functionality in `dotfiles-health.sh`
- **Shared Logic**: Common symlink detection prevents code duplication
- **Testable Functions**: Each function can be tested independently
- **Path Handling**: Proper relative/absolute path resolution

### Platform Support

- **macOS**: Full support with platform-specific paths
- **Linux**: Standard XDG config directory handling
- **Windows/MSYS2**: AppData directory recursive search
- **Cross-platform**: Automatic platform detection

### Directory Search Strategy

- **Home Directory**: Depth 1 search (avoids performance issues)
- **Config Directories**: Recursive search for nested configurations
- **AppData**: Full recursive search for Windows configurations

## Migration Workflow

1. **Capture State**: `just check-health`
2. **Dry Run**: `just stow osx stow-basic-dry`  
3. **Migrate**: `just stow osx stow-basic-force`
4. **Validate**: `just check-health`
5. **Cleanup**: `just cleanup-broken-links-remove`

## Files

- `dotfiles-health.sh`: Main library with all functions
- `test-dotfiles-health.sh`: Comprehensive test suite  
- `README.md`: This documentation