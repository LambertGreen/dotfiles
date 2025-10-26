# Package Management System Design

## Overview

This document describes the native package manager export/import system for the dotfiles project. This design replaces the previous TOML-based approach with a simpler system that uses each package manager's native export/import formats.

## Core Philosophy

1. **Native Formats** - Use each package manager's own export/import format (Brewfile, requirements.txt, etc.)
2. **No Translation Layer** - Eliminate parsing and conversion between formats
3. **Battle-Tested Configs** - Export from real, working machines
4. **Functional Design** - Composable, idempotent operations with clear dependencies
5. **Modal Interface** - Quick all-in-one commands with selective control when needed

## Directory Structure

```
package-management/
├── machines/                           # Machine class definitions
│   ├── laptop_personal_mac/           # PII-safe naming: form_purpose_os
│   │   ├── brew/
│   │   │   └── Brewfile               # Homebrew packages, casks, mas
│   │   ├── pip/
│   │   │   └── requirements.txt       # Python packages
│   │   ├── npm/
│   │   │   └── packages.txt           # NPM global packages
│   │   └── gem/
│   │       └── Gemfile                # Ruby gems
│   ├── laptop_work_mac/               # Work machine variant
│   │   ├── brew/
│   │   │   └── Brewfile
│   │   └── pip/
│   │       └── requirements.txt
│   ├── desktop_home_ubuntu/           # Ubuntu desktop setup
│   │   ├── apt/
│   │   │   └── packages.txt
│   │   ├── brew/                      # Homebrew on Linux
│   │   │   └── Brewfile
│   │   └── pip/
│   │       └── requirements.txt
│   ├── wsl_work_ubuntu/               # WSL2 Ubuntu
│   │   ├── apt/
│   │   │   └── packages.txt
│   │   └── pip/
│   │       └── requirements.txt
│   ├── desktop_gaming_win/            # Windows gaming rig
│   │   ├── scoop/
│   │   │   └── scoopfile.json
│   │   ├── choco/
│   │   │   └── packages.config
│   │   └── winget/
│   │       └── packages.json
│   ├── docker_test_arch/              # Docker test containers
│   │   └── pacman/
│   │       └── packages.txt
│   ├── docker_test_ubuntu_min/        # Minimal Ubuntu test
│   │   └── apt/
│   │       └── packages.txt
│   ├── docker_test_ubuntu_mid/        # Mid-tier Ubuntu test
│   │   ├── apt/
│   │   │   └── packages.txt
│   │   └── pip/
│   │       └── requirements.txt
│   └── docker_test_ubuntu_max/        # Full Ubuntu test
│       ├── apt/
│       │   └── packages.txt
│       ├── brew/
│       │   └── Brewfile
│       └── pip/
│           └── requirements.txt
├── scripts/
│   ├── configure.sh                   # Set machine class for current system
│   ├── import.sh                      # Install packages (handles PM ordering)
│   ├── export.sh                      # Export current machine state
│   └── update.sh                      # Update packages
├── justfile                           # Modal package manager commands
├── DESIGN.md                          # This file
└── README.md                          # Usage instructions
```

## Machine Class Naming Convention

**Format:** `<form_factor>_<purpose>_<os>`

### Form Factors
- `laptop` - Portable machines
- `desktop` - Desktop workstations
- `docker` - Docker test containers
- `vm` - Virtual machines
- `wsl` - Windows Subsystem for Linux

### Purposes
- `personal` - Personal use
- `work` - Work environments
- `gaming` - Gaming setups
- `dev` - Development focused
- `home` - Home server/media
- `test` - Testing environments

### Operating Systems
- `mac` - macOS
- `ubuntu` - Ubuntu Linux
- `arch` - Arch Linux
- `win` - Windows

### Examples
- `laptop_personal_mac` - Personal MacBook
- `desktop_home_ubuntu` - Home Ubuntu desktop
- `docker_test_arch` - Arch Linux test container
- `wsl_work_ubuntu` - Work WSL2 Ubuntu environment

## Package Manager Support

### System Package Managers
- **brew** - Homebrew (macOS/Linux) - Uses `Brewfile`
- **apt** - Debian/Ubuntu packages - Uses `packages.txt`
- **pacman** - Arch Linux packages - Uses `packages.txt`
- **scoop** - Windows Scoop - Uses `scoopfile.json`
- **choco** - Windows Chocolatey - Uses `packages.config`
- **winget** - Windows Package Manager - Uses `packages.json`
- **snap** - Ubuntu Snap packages - Uses `packages.txt`

### Language Package Managers
- **pip** - Python packages - Uses `requirements.txt`
- **npm** - Node.js packages - Uses `packages.txt`
- **gem** - Ruby gems - Uses `Gemfile`
- **cargo** - Rust packages - Uses `packages.txt`

### App Package Managers
App-specific packages (Emacs, Neovim, etc.) are handled by their respective stowed configurations, not this system.

## Package Manager Dependencies

The system handles package manager dependencies through platform-specific installation ordering:

### macOS Order
1. **brew** - Installs Python, Node, Ruby, etc.
2. **pip** - Needs Python from brew
3. **npm** - Needs Node from brew  
4. **gem** - Needs Ruby from brew
5. **cargo** - Standalone

### Linux Order
1. **apt/pacman** - System packages first
2. **brew** - Modern versions of Python, Node
3. **pip** - Needs Python
4. **npm** - Needs Node
5. **gem** - Needs Ruby
6. **cargo** - Standalone

### Windows Order
1. **pacman** (MSYS2) - System packages
2. **scoop** - User packages
3. **choco** - System-wide packages
4. **pip** - Python packages
5. **npm** - Node packages

## Modal Just Interface

The system provides two tiers of commands:

### Tier 1: Convenience Commands (Top-level justfile)
```bash
just install          # Install all packages for configured machine class
just update-check     # Check for updates across all package managers
just update-all       # Update all packages
```

### Tier 2: Selective Control (package-management/justfile)
```bash
# Enter modal mode
just installs         # Shows available install commands
just updates          # Shows available update commands

# Individual package manager operations
just install-brew     # Install only Homebrew packages
just install-pip      # Install only Python packages
just update-brew      # Update only Homebrew (fast)
just check-pip        # Check Python updates only
```

## Configuration Workflow

1. **Initial Setup**
   ```bash
   ./package-management/scripts/configure.sh
   # Prompts to select machine class
   # Saves DOTFILES_MACHINE_CLASS to ~/.dotfiles.env
   ```

2. **Install Packages**
   ```bash
   just install          # Install all packages
   # OR selective
   just installs         # Enter modal mode
   just install-brew     # Install specific PM
   ```

3. **Update Packages**
   ```bash
   just update-check     # See what's available
   just update-all       # Update everything
   # OR selective  
   just updates          # Enter modal mode
   just update-brew      # Update fast packages only
   ```

## Export/Import Workflow

### Creating New Machine Classes
1. **Export from current machine**
   ```bash
   ./package-management/scripts/export.sh
   # Exports to /tmp/machine-export-YYYY-MM-DD-HHMMSS/
   ```

2. **Create new machine class**
   ```bash
   mkdir -p machines/laptop_new_mac
   cp -r /tmp/machine-export-*/. machines/laptop_new_mac/
   ```

3. **Organize by package manager**
   ```bash
   # Move exported files into appropriate PM directories
   mkdir machines/laptop_new_mac/brew
   mv machines/laptop_new_mac/Brewfile machines/laptop_new_mac/brew/
   ```

### Maintaining Existing Classes
- Export periodically to capture new packages
- Diff against existing machine classes to see changes
- Copy useful packages between machine classes

## Docker Testing Integration

### Test Machine Classes
The system includes Docker-based machine classes for testing:

- `docker_test_arch` - Minimal Arch Linux
- `docker_test_ubuntu_min` - Essential packages only
- `docker_test_ubuntu_mid` - Extended CLI tools
- `docker_test_ubuntu_max` - Full development environment

### Updated Docker Test Commands
```bash
# Test with new package management system
just test docker_test_ubuntu_min    # Fast feedback
just test docker_test_ubuntu_mid    # Mid-tier testing
just test docker_test_ubuntu_max    # Full validation

# Test specific package managers in Docker
just test-installs docker_test_ubuntu_max
just install-apt     # Test APT in container
just install-pip     # Test Python packages
```

### Docker Test Implementation
```dockerfile
# Dockerfile updates to use new system
COPY package-management/machines/docker_test_ubuntu_min/ /dotfiles/package-management/machines/docker_test_ubuntu_min/
ENV DOTFILES_MACHINE_CLASS=docker_test_ubuntu_min
RUN ./package-management/scripts/import.sh
```

## Migration from TOML System

### Deprecation Plan
1. **Phase 1** - Implement new system alongside TOML
2. **Phase 2** - Update all scripts to use new system
3. **Phase 3** - Remove TOML-based package management
4. **Phase 4** - Clean up old files and update documentation

### Migration Benefits
- **Simplicity** - No parsing, no translation layer
- **Reliability** - Uses PM native formats, tested on real machines
- **Performance** - Direct PM commands, no intermediate processing
- **Maintainability** - Easy to query with grep/rg, copy between classes
- **Testability** - Docker classes provide fast feedback

## Querying Package Information

The explicit directory structure enables powerful querying:

```bash
# Which machines use Homebrew?
ls -d machines/*/brew/

# Find all pip requirements across machines
cat machines/*/pip/requirements.txt | sort -u

# Where is emacs installed from?
rg "emacs" machines/*/brew/Brewfile machines/*/apt/packages.txt

# Compare Ubuntu packages between machines
diff machines/desktop_home_ubuntu/apt/packages.txt \
     machines/wsl_work_ubuntu/apt/packages.txt

# Find all Python packages used
find machines -name "requirements.txt" -exec basename {} \; -exec cat {} \;
```

## Implementation Tasks

### Critical Path
1. Create `package-management/` directory structure
2. Migrate existing exports from `package_manager_exports/`
3. Implement `scripts/configure.sh` for machine class selection
4. Implement `scripts/import.sh` with PM ordering
5. Create modal `justfile` with selective commands
6. Update Docker testing to use new machine classes
7. Update main `justfile` to use new package management
8. Deprecate TOML-based system

### Testing Strategy
1. **Unit Tests** - Individual PM import/export functions
2. **Integration Tests** - Full machine class imports in Docker
3. **Manual Tests** - Real machine imports/exports
4. **CI/CD** - Docker test machine classes in pipeline

## Future Extensions

### Planned Features
- **Machine class inheritance** - Base classes + extensions
- **Conditional packages** - Work vs personal filtering
- **Version pinning** - Exact vs flexible version management
- **Package conflicts** - Detection and resolution
- **Rollback support** - Restore previous package states

### New Package Managers
Adding new package managers requires:
1. Create directory in machine class
2. Add case to `scripts/import.sh`
3. Add commands to `package-management/justfile`
4. Update export script to handle new format
5. Document in this file

## AI Assistant Guidelines

When working on this system:
1. **Preserve the native format principle** - Don't add translation layers
2. **Maintain machine class naming** - Use `form_purpose_os` convention
3. **Keep PM ordering** - Respect dependencies in import scripts
4. **Test with Docker** - Use Docker machine classes for validation
5. **Document changes** - Update this design doc with modifications
6. **Query-friendly structure** - Keep directory structure greppable
7. **Modal interface** - Maintain two-tier just command structure

## Critical Platform Issue: MSYS2 Environment Pollution

### The Problem

When running from **MSYS2 Python** (Cygwin Python on Windows), all Python subprocess APIs inherit a **polluted hybrid environment** that corrupts Windows process execution:

**Symptoms:**
- PATH becomes corrupted: `C:\Program Files;C;...` (extra `C;` separators)
- Unix environment variables leak: `MSYSTEM=MINGW64`, `TERM=xterm-256color`
- Commands fail: `scoop --version` shows incomplete output (missing git commit info)
- Flash windows appear when MSYS2 executables (like git.exe) are called from PowerShell

**Root Cause:**
MSYS2 creates an **impedance mismatch** - it's a POSIX environment trying to call Windows APIs:
- MSYS2 Python subprocess methods (Popen, run, system, spawnv) all inherit parent environment
- Even passing `env={}` doesn't work - subprocess **merges** with parent
- Environment variables get mangled during the MSYS2 → Windows boundary crossing
- There's no pure way to get a clean Windows environment from MSYS2 Python

### Why Other Platforms Work

**Clean environment boundaries work perfectly:**

| Platform | Boundary | Result |
|----------|----------|--------|
| **Mac/Linux** | POSIX → POSIX subprocess → POSIX shell | ✅ Clean |
| **WSL** | Linux → `/init` interop → Windows Terminal | ✅ Clean (interop reads registry) |
| **Native Windows** | Windows app → Windows subprocess → Windows shell | ✅ Clean |
| **Keypirinha** | Native Windows → subprocess → Windows Terminal | ✅ Clean (reads registry) |
| **MSYS2** | Hybrid POSIX/Windows → subprocess → Windows | ❌ **POLLUTED** |

**The Pattern:** Native executables don't inherit - they query the OS (registry on Windows).

### The Solution: Batch File Intermediary

**Break the pollution chain with a native Windows intermediary:**

```
❌ BEFORE: MSYS2 Python → subprocess.Popen → wt.exe → PowerShell
           (Environment pollution leaks through)

✅ AFTER:  MSYS2 Python → spawn_wt_clean.bat → wt.exe → PowerShell
           (Batch file reads fresh Windows registry, breaks chain)
```

**Implementation:**
1. Create `scripts/spawn_wt_clean.bat` - native Windows batch file
2. Batch file calls `wt.exe` directly (reads environment from Windows registry)
3. Python calls batch file instead of `wt.exe` directly
4. Result: Clean Windows environment, no MSYS2 pollution

**Key Code (terminal_executor.py):**
```python
# Find batch file launcher
batch_file = Path(__file__).parent.parent.parent / 'scripts' / 'spawn_wt_clean.bat'

# Call via batch file (breaks MSYS2 chain)
subprocess.Popen([batch_file, title, 'pwsh.exe', '-NoExit', '-Command', command])
```

### Why This Works

1. **Native executables query the OS** - `.bat` files read environment from Windows registry
2. **Breaks the inheritance chain** - No direct parent-child subprocess relationship
3. **Platform-appropriate** - Uses Windows-native process spawning mechanisms
4. **Similar to WSL/Keypirinha** - Matches how other clean boundaries work

### Broader Lesson

**When bridging between incompatible environments, use native intermediaries.**

Don't try to make hybrid environments "speak native" - they will pollute. Instead:
1. Identify the impedance mismatch (POSIX ↔ Windows in this case)
2. Use a native intermediary that queries the OS directly
3. Break the chain of environment inheritance
4. Trust native tools to do what they're designed for

**This pattern applies beyond MSYS2:**
- Docker → host commands (use native Docker API, not subprocess)
- Cygwin → Windows processes (use native .bat/.exe intermediaries)
- WSL → Windows processes (already works via `/init` interop)
- Any hybrid environment → native OS

### Critical Reminders

- **Never assume subprocess.Popen is clean** on hybrid platforms
- **Test environment inheritance** when crossing platform boundaries
- **Use native intermediaries** when pollution is detected
- **Document the solution** so future developers don't waste cycles rediscovering this

### ⚠️ CRITICAL: Claude Code MSYS2 Sandbox Limitation

**Environment Variables Do NOT Propagate to Child Processes in Claude Code Sessions**

When running commands via Claude Code (claude.ai/code) in an MSYS2 environment on Windows, there is a **critical sandbox restriction**:

**The Problem:**
```bash
# In a NORMAL MSYS2 terminal - WORKS:
export TEST_VAR="hello" && python3 -c "import os; print(os.environ.get('TEST_VAR'))"
# Output: hello ✅

# In Claude Code MSYS2 bash session - FAILS:
export TEST_VAR="hello" && python3 -c "import os; print(os.environ.get('TEST_VAR'))"
# Output: None ❌
```

**Impact:**
- ❌ **Configuration via env vars doesn't work** in Claude sessions
- ❌ **`DOTFILES_PM_ENABLED` / `DOTFILES_PM_DISABLED` are ignored**
- ❌ **UI selection testing via env vars is broken** (e.g., `DOTFILES_PM_UI_SELECT`)
- ❌ **Any pytest hooks using env vars for test configuration fail**

**Why This Happens:**
Claude Code runs commands in a **sandboxed/restricted MSYS2 environment** where custom environment variables are blocked from propagating to child processes. This is a Claude Code-specific security/isolation restriction, NOT an MSYS2 or code bug.

**Verification:**
The same commands work perfectly in a normal MSYS2 terminal:
```bash
# Real terminal - env vars propagate correctly:
$ . ~/.dotfiles.env && python3 -c "import os; print('DISABLED:', os.environ.get('DOTFILES_PM_DISABLED'))"
DISABLED: pacman ✅

# Claude Code - env vars blocked:
$ . ~/.dotfiles.env && python3 -c "import os; print('DISABLED:', os.environ.get('DOTFILES_PM_DISABLED'))"
DISABLED: <not set> ❌
```

**Workarounds for Testing in Claude Sessions:**
1. **Direct Python testing** - Pass config via command-line args instead of env vars
2. **Config files** - Use JSON/TOML files read by Python directly (not env vars)
3. **Test in user's terminal** - Ask user to run tests in their own terminal, not via Claude
4. **Hard-code for debugging** - Temporarily hard-code values in Python for Claude-based testing

**Important Notes:**
- This **ONLY affects Claude Code sessions** - real user workflows work normally
- The code is correct - env vars work fine in production
- Don't waste time debugging "env var propagation" in Claude sessions
- When testing configuration changes, **ask the user to test in their own terminal**

**Bottom Line:** Any testing that relies on environment variables for configuration (UI selection, PM filtering, test hooks) **MUST be done by the user in their own terminal**, not via Claude Code bash commands.

This design provides a solid foundation for native package management that's simple, reliable, and extensible.