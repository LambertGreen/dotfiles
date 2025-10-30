# Windows Machine Rebuild Issues

This document tracks issues encountered when rebuilding Windows machines and their solutions.

## SSH Key Setup for GitHub Access

**Issue**: Cannot clone dotfiles repository via SSH on fresh Windows install because SSH keys don't exist yet.

**Problem**: The initial setup assumes you can clone the repo, but on a fresh Windows machine you need to:
1. Generate SSH key pair
2. Add public key to GitHub account
3. Test SSH connection before cloning

**Current Workaround**:
- Use HTTPS clone initially: `git clone https://github.com/LambertGreen/dotfiles.git`
- Generate SSH keys after dotfiles setup
- Switch remote to SSH later

**Potential Solutions**:
1. Add SSH key generation to bootstrap process
2. Document HTTPS → SSH workflow in Windows setup guide
3. Create a separate "fresh machine" setup script that handles GitHub authentication

**Related Files**:
- `bootstrap.ps1` - Windows bootstrap script
- `README.org` - Setup documentation

---

## Bootstrap Script Permission Conflicts

**Issue**: `bootstrap.ps1` cannot be run successfully in either admin or non-admin mode due to conflicting package manager requirements.

**Problem**:
- **Chocolatey** requires administrator privileges to install
- **Scoop** requires non-administrator privileges (fails if run as admin)
- Current script tries to install both, causing failure regardless of execution context

**Current Behavior**:
- Run as non-admin: Fails on chocolatey installation
- Run as admin: Fails on scoop installation
- Script exits on first failure, preventing any progress

**Proposed Solution**:
1. **Make script interactive** - prompt user to choose which package managers to install
2. **Continue on failure** - don't exit when one package manager fails, allow script to complete other installations
3. **Idempotent design** - allow script to be re-run multiple times to make incremental progress
4. **Clear messaging** - inform user about permission requirements for each package manager

**Implementation Ideas**:
```powershell
# Prompt user for package manager selection
Write-Host "Select package managers to install:"
Write-Host "1. Chocolatey (requires admin)"
Write-Host "2. Scoop (requires non-admin)"
Write-Host "3. Both (run script twice with different privileges)"

# Continue on failure pattern
try {
    Install-Chocolatey
    Write-Host "✓ Chocolatey installed successfully"
} catch {
    Write-Warning "✗ Chocolatey installation failed: $($_.Exception.Message)"
    Write-Host "  To install chocolatey, re-run this script as administrator"
}
```

**Related Files**:
- `bootstrap.ps1` - Windows bootstrap script

---

## MSYS2 Pre-Configuration Requirements

**Issue**: MSYS2 requires specific configuration before it can properly work with the dotfiles system.

**Problem**:
- MSYS2 defaults don't support native Windows symlinks (needed for GNU Stow)
- MSYS2 creates its own separate home directory instead of using Windows user home
- These must be configured before running any `just` commands in MSYS2

**Required Configuration Steps**:

1. **Enable Native Symlinks** (in MSYS2 terminal):
```bash
# Set MSYS environment variable
echo "export MSYS=winsymlinks:nativestrict" >> ~/.bashrc
```

2. **Set Home Directory to Windows User Home**:
```bash
# Via nsswitch.conf (recommended)
echo "db_home: windows" >> /etc/nsswitch.conf
```

3. **Inherit Windows PATH** (so scoop-installed tools work):
```bash
# Add Windows PATH to MSYS2 PATH
echo "export PATH=\$PATH:/c/Users/\$(whoami)/scoop/shims" >> ~/.bashrc
# Or more comprehensive Windows PATH inheritance:
echo "export MSYS2_PATH_TYPE=inherit" >> ~/.bashrc
```

4. **Restart MSYS2** after making these changes

**Why This Matters**:
- GNU Stow requires symlink support to deploy dotfiles
- Dotfiles expect to be in the same home directory across Windows and MSYS2
- Just commands assume consistent file paths between environments

**Integration Point**: These steps should be added to `bootstrap.ps1` or documented in Windows setup guide.

**Related Files**:
- `bootstrap.ps1` - Should configure MSYS2 after installation
- `configs/shell_msys2/` - MSYS2-specific configurations

---

## Windows PATH Not Inherited in MSYS2

**Issue**: Tools installed via Scoop (like `just.exe`) are not available in MSYS2 because MSYS2 doesn't inherit the Windows PATH by default.

**Problem**:
- `bootstrap.ps1` installs `just` via Scoop in Windows
- Scoop adds tools to Windows PATH via shims (`~/scoop/shims/`)
- MSYS2 creates its own isolated PATH, ignoring Windows PATH
- Result: `just` command not found in MSYS2 terminal

**Current Workaround**: Manually add Windows PATH to MSYS2

**Root Cause**: Bootstrap ordering problem - we need MSYS2 configured before our dotfiles can set up `.bashrc`, but we're trying to configure MSYS2 from within `.bashrc`.

**Proper Solution**: Set MSYS2 environment variables at the Windows system level before launching MSYS2.

**Windows System Environment Variables** (set via `bootstrap.ps1` or manually):
```powershell
# Set Windows environment variables that MSYS2 will inherit
[Environment]::SetEnvironmentVariable("MSYS2_PATH_TYPE", "inherit", "User")
[Environment]::SetEnvironmentVariable("MSYS", "winsymlinks:nativestrict", "User")

# Alternative: Set via Windows GUI (sysdm.cpl -> Environment Variables)
# Or via command line:
setx MSYS2_PATH_TYPE inherit
setx MSYS winsymlinks:nativestrict
```

**MSYS2 Configuration Files** (alternative approach):
```bash
# Set in /etc/nsswitch.conf (system-wide)
echo "db_home: windows" >> /etc/nsswitch.conf

# Set in /etc/fstab for mount options
echo "none /tmp usertemp binary,posix=0 0 0" >> /etc/fstab
```

**Immediate Workaround** (run in MSYS2 terminal):
```bash
# Temporary fix until we implement proper Windows-side configuration
export PATH=$PATH:/c/Users/$(whoami)/scoop/shims
export MSYS2_PATH_TYPE=inherit
which just
```

**Design Question**: Should we install `just` via MSYS2 pacman instead of Scoop to avoid this PATH issue entirely?

**Related Files**:
- `bootstrap.ps1` - Installs just via Scoop
- `configs/shell_msys2/` - Could handle PATH configuration

---

## Stow Command Hides Errors in MSYS2

**Issue**: `just stow` appears to succeed but silently fails with "Directory not found" errors that are only visible in log files.

**Problem**:
- `just stow` shows no error output to user
- Actual stow errors are hidden/redirected somewhere
- Errors like "Directory not found, skipping: <dir-name>" only appear in logs
- User has no indication that stow failed

**Symptoms**:
- Command appears to complete successfully
- Dotfiles are not actually deployed
- No immediate feedback about what went wrong

**Investigation Needed**:
1. Check `scripts/stow/stow.sh` - is output being redirected/suppressed?
2. Check `justfile` stow target - are errors being hidden?
3. Identify where these log files are located
4. Determine why directories are "not found" - path issues?

**Root Cause** (found in `scripts/stow/stow.sh`):
- Line 80: `stow` stderr redirected to log file (`2>>"${LOG_FILE}"`) - user never sees stow errors
- Line 87: "Directory not found" uses `log_verbose()` - only writes to log, not console
- Design hides all details to keep interface "clean" but makes debugging impossible

**Recommended Solution**: Use terminal spawning (like `update`/`upgrade` commands)
- Spawn interactive terminal for stow operations
- User sees real-time output and can debug issues
- Maintains clean "Control Center" interface in `just`
- Consistent with existing package management UX pattern

**Implementation**:
```bash
# In justfile - change stow to spawn terminal like update/upgrade
stow:
    @echo "🔗 Deploying configurations in new terminal..."
    @# Spawn terminal with stow script (similar to pm upgrade pattern)
```

**Related Files**:
- `justfile` (line 35-40) - stow command definition
- `scripts/stow/stow.sh` - actual stow implementation
- `src/dotfiles_pm/terminal_executor.py` - terminal spawning logic (reference pattern)

---

## Inconsistent and Poor Log Directory Structure

**Issue**: Logs are scattered in inappropriate locations, making debugging difficult.

**Current Problems**:
- `scripts/.logs/` - Wrong location (subdirectory of scripts)
- Not consolidated - different components may log elsewhere
- Inside repo means logs could be accidentally committed
- Requires `rg -uu` to search ignored directories

**Design Trade-offs**:

**Option 1: `~/.dotfiles/logs/` (System location)**
- ✅ Proper system location, won't be committed
- ✅ Persistent across repo updates/moves
- ✅ Standard location for application logs
- ❌ Not immediately accessible when working in repo
- ❌ Extra step to navigate for debugging

**Option 2: `<repo>/.logs/` (Current, but fixed)**
- ✅ Immediately accessible in working directory
- ✅ Easy to `rg` for debugging (with `-uu`)
- ✅ Logs travel with repo for troubleshooting
- ❌ Risk of accidental commit (needs `.gitignore`)
- ❌ Logs lost when repo is deleted/moved

**Recommendation**: **Option 1** (`~/.dotfiles/logs/`)
- More professional/standard approach
- Safer (no commit risk)
- Persistent across environments
- Can create alias/just command for easy access: `just logs`

**Implementation**:
```bash
# Standardize log location
LOG_DIR="$HOME/.dotfiles/logs"
mkdir -p "$LOG_DIR"

# Add convenience command to justfile
logs:
    @ls -la ~/.dotfiles/logs/
    @echo "Most recent logs:"
    @ls -t ~/.dotfiles/logs/ | head -5
```

**Files to Update**:
- `scripts/stow/stow.sh` (line 8) - Currently uses `${DOTFILES_ROOT}/.logs`
- Any other scripts that log
- `.gitignore` - Remove `.logs` entry if moving to `~/.dotfiles/`

---

## Stow Script Directory Resolution Bug

**Issue**: `just stow` fails because script can't find config directories that actually exist.

**Log Evidence** (from Windows MSYS2):
```
Stowing: git_common
Directory not found, skipping: git_common
Stowing: shell_common
Directory not found, skipping: shell_common
```

**Root Cause Analysis**:

1. **Empty line processing bug**: Line 26 in `stow.txt` is empty but creates a "Stowing:" entry
2. **Directory resolution issue**: Script does `cd configs` then `if [ -d "$stow_package" ]` but directories exist
3. **Possible MSYS2 path issues**: Windows path resolution in MSYS2 environment

**Investigation needed**:
- Check if `cd configs` actually succeeds in MSYS2
- Verify `pwd` after the `cd configs` command
- Test if MSYS2 symlink support affects directory detection
- Check for file encoding issues (Windows CRLF vs Unix LF)

**Debug commands to run in MSYS2**:
```bash
# Test the exact script logic
cd /c/Users/$(whoami)/dev/my/dotfiles/configs
ls -la git_common shell_common  # Should exist
[ -d "git_common" ] && echo "EXISTS" || echo "NOT FOUND"
```

**Related to**: MSYS2 configuration issues - may need native symlinks working first

---

## Git Delta Tool Missing - No Fallback

**Issue**: `git diff` fails because `delta` pager tool is not installed, with no graceful fallback.

**Problem**:
- Git is configured to use `delta` as the diff pager
- `delta` is not installed during bootstrap phase
- No fallback configuration when `delta` is missing
- `git diff` becomes unusable until `delta` is manually installed

**Investigation Needed**:
- Check git configuration files for `delta` settings
- Determine if `delta` should be in bootstrap or package lists
- Design fallback strategy (fall back to `less` or plain output)

**Potential Solutions**:

**Option 1: Add delta to bootstrap**
- Include `delta` in essential tools installation
- Ensures `git diff` works immediately

**Option 2: Conditional git config**
- Configure git to use `delta` only if available
- Fall back to standard pager when missing

**Option 3: Graceful degradation**
```bash
# In git config
[pager]
    diff = bash -c 'delta "$@" 2>/dev/null || less "$@"' -
```

**Root Cause Found**:
- `configs/git_common/dot-common.gitconfig:5` sets `core.pager = delta`
- Hard dependency on `delta` with no fallback
- Expected: tools should enhance when present, degrade gracefully when missing

**Recommended Solution: Conditional Git Pager**
```gitconfig
[core]
    # Use delta if available, fallback to less
    pager = bash -c 'command -v delta >/dev/null && delta "$@" || less "$@"' -
```

**Design Principle**: New tools should uplevel functionality when present, downlevel safely when removed.

**Files to Update**:
- `configs/git_common/dot-common.gitconfig:5` - Make delta conditional

---

## Complete Package Management System Failure

**Issue**: `just install` fails completely - all package managers detected but none have installers defined.

**Error Output**:
```
❌ Installation failed: No installer defined for pacman
❌ Installation failed: No installer defined for choco
❌ Installation failed: No installer defined for winget
❌ Installation failed: No installer defined for scoop
❌ Installation failed: No installer defined for zinit
```

**Problem Analysis**:
- System detects 5 package managers (pacman, choco, winget, scoop, zinit)
- All package managers are missing installer definitions
- Suggests broken PM registration or missing PM implementation files
- Complete system failure - 0/5 successful installations

**Investigation Needed**:
1. Check `src/dotfiles_pm/pms/` directory for PM implementation files
2. Verify PM detection vs PM implementation logic
3. Check if Windows-specific PMs are properly implemented
4. Examine PM registry/configuration system

**Possible Causes**:
- Missing PM implementation files for Windows PMs
- PM detection working but implementation broken
- Configuration mismatch between detected and implemented PMs
- MSYS2 environment issues affecting PM execution

**Debug Commands**:
```bash
# Check what PM implementations exist
ls -la src/dotfiles_pm/pms/

# Check PM detection logic
python3 -m src.dotfiles_pm.pm list --verbose

# Check specific PM files
find src/dotfiles_pm/pms/ -name "*scoop*" -o -name "*choco*"
```

**Impact**: Complete system failure - no packages can be installed via the unified system.

---

## Shell Config Assumes Homebrew on All Platforms

**Issue**: Shell startup fails with `lgreen_setup_fzf:4: command not found: brew` and `lgreen_setup_fzf:8: command not found: brew`.

**Problem**:
- Shell configuration contains Homebrew-specific fzf setup commands
- Homebrew is not available on Windows/MSYS2 platform
- No platform detection before calling brew commands
- Causes shell startup errors on Windows

**Root Cause**: Cross-platform shell configuration not properly handling platform differences.

**Investigation Needed**:
- Find where `lgreen_setup_fzf` function is defined
- Check if it's in `shell_common` (should be platform-agnostic) or platform-specific configs
- Determine proper fzf setup method for Windows/MSYS2

**Potential Solutions**:

**Option 1: Platform detection in shell config**
```bash
lgreen_setup_fzf() {
    if command -v brew >/dev/null 2>&1; then
        # Homebrew fzf setup (macOS/Linux with brew)
        [[ $- == *i* ]] && source "$(brew --prefix)/share/zsh-site-functions/fzf"
    elif command -v pacman >/dev/null 2>&1; then
        # MSYS2/Arch fzf setup
        source /usr/share/fzf/key-bindings.zsh 2>/dev/null || true
    fi
}
```

**Option 2: Move brew-specific code to platform configs**
- Move brew fzf setup to `shell_osx` and `shell_linux`
- Keep only generic fzf setup in `shell_common`

**Files to Check**:
- `configs/shell_common/` - likely contains the problematic function
- Platform-specific shell configs for proper fzf setup methods

---

## Package Lists Include Transitive Dependencies

**Issue**: Generated pacman install command is massive and includes low-level system libraries instead of just the tools actually needed.

**Problem**:
- Package list includes transitive dependencies (libssl, libcrypt, gcc-libs, etc.)
- Creates unnecessarily large installation footprint
- More surface area for work machine antivirus to flag
- Hard to see what tools are actually intended vs dependencies

**Work Machine Considerations**:
- Antivirus software scans more files = higher chance of false positives
- Corporate security wants minimal attack surface
- Need to justify each installed tool
- Platform-specific tools preferred over cross-platform alternatives

**Solution Needed**:
- Curate package lists to only include "leaf" packages (actual tools)
- Let package managers handle dependencies automatically
- Focus on essential tools: `vim`, `git`, `tmux`, `fastfetch`, `ripgrep`, etc.
- Separate work-appropriate packages from full development setup

**Investigation**: Review package lists to identify actual intended tools vs system dependencies.

---

## Windows Environment Variables Not Set

**Issue**: Tools like Emacs fail because required Windows environment variables (like `$HOME`) are not set at the system level.

**Problem**:
- Unix-style tools expect `HOME` environment variable
- MSYS2 sets these in its shell, but Windows applications don't see them
- Tools launched from Windows (not MSYS2) fail to find user directories
- No systematic approach to setting required Windows environment variables

**Setup Flow Integration**:
Environment variables should be set in **bootstrap.ps1** because:
- It's the foundational "prepare the system" step
- Already running with appropriate privileges
- Environment variables are infrastructure, like installing tools
- Tools installed later expect the environment to be ready

**Required Windows Environment Variables**:
```powershell
# In bootstrap.ps1 - add environment variable setup
[Environment]::SetEnvironmentVariable("HOME", $env:USERPROFILE, "User")
# Possibly others: EDITOR, PAGER, etc.
```

**Setup Flow**:
1. `just configure` - Select machine class
2. `just bootstrap` - Install tools **+ set environment variables**
3. `just stow` - Deploy configs (expects environment ready)
4. `just install` - Install packages (expects environment ready)

**Impact**: Any Unix-style tool that expects standard environment variables will fail on Windows.

---

## Keypirinha: Scoop vs Chocolatey Config Conflict

**Issue**: Scoop's portable app approach conflicts with GNU Stow for Keypirinha configuration management.

**Problem**:
- **Scoop**: Uses portable directory structure with version symlinks
- **Config path**: `~/scoop/apps/keypirinha/current/portable/Profile/User/`
- **Conflict**: Symlinked paths change with versions, breaking stow symlinks
- **GNU Stow**: Expects stable config paths for symlinking

**Decision**: Use Chocolatey for Keypirinha despite admin requirement.

**Reasoning**:
- **Chocolatey**: Uses standard Windows paths (`%APPDATA%\Roaming\Keypirinha`)
- **Stable paths**: Compatible with GNU Stow symlinking
- **Trade-off**: Admin privileges required vs stable configuration management

**Action Items**:
- ✅ Keep `configs/keypirinha_choco/` (works with stow)
- ❌ Remove `configs/Keypirinha/` (scoop-based, doesn't work with stow)
- 📝 Update machine class to use `choco install keypirinha` instead of scoop

**Scoop Package List**: Remove `keypirinha` from `machine-classes/desktop_work_win/scoop/packages.txt`

**Files to Clean Up**:
- Remove: `configs/Keypirinha/` (scoop version)
- Keep: `configs/keypirinha_choco/` (chocolatey version)

---

## Chocolatey Keypirinha Missing Start Menu Integration

**Issue**: Keypirinha installed via Chocolatey doesn't appear in Start Menu, unlike Scoop version.

**Package Manager Differences**:
- **Scoop**: Creates Start Menu shortcuts even for portable apps
- **Chocolatey**: Sometimes skips Start Menu integration depending on package

**Root Causes**:
1. **Chocolatey package variant**: May be using portable installer without shortcuts
2. **Installation flags**: Might need `--install-arguments` for full integration
3. **Package maintainer choice**: Chocolatey packager might have disabled shortcuts

**Solutions to Try**:

**Option 1: Check installation parameters**
```powershell
choco install keypirinha --install-arguments="/SILENT /TASKS=desktopicon,quicklaunchicon"
```

**Option 2: Manual Start Menu shortcut**
```powershell
# Find keypirinha.exe location
Get-ChildItem "C:\ProgramData\chocolatey\lib\keypirinha" -Recurse -Name "*.exe"
# Create shortcut manually or via PowerShell script
```

**Option 3: Check for different Chocolatey package variant**
```powershell
choco search keypirinha
# Look for alternatives like keypirinha-portable vs keypirinha-installer
```

**Workaround**: Pin to taskbar or create desktop shortcut manually for now.

**Investigation needed**: Check what chocolatey package variant provides full Windows integration.

---

## PowerToys Silently Steals Keybinds

**Issue**: Keypirinha's `Ctrl+Space` keybind not working despite correct configuration.

**Root Cause**: Windows PowerToys was intercepting `Ctrl+Space` globally but not responding when invoked.

**Problem**:
- PowerToys registers global hotkeys silently
- No indication that keybind is captured
- No response when keybind is pressed (appears broken)
- Impossible to debug without knowing PowerToys is interfering

**Solution**: Uninstalled PowerToys

**Lesson**: Check for global hotkey conflicts when keybinds mysteriously fail on Windows. Common culprits:
- PowerToys
- Windows built-in shortcuts
- Antivirus software
- Corporate management tools
- Other launcher applications

**Prevention**: Document known keybind conflicts for future Windows rebuilds.

---

## Registry-Based Configuration (Divvy)

**Issue**: Divvy window manager stores configuration in Windows Registry, not files, breaking standard dotfiles approach.

**Registry Location**: `HKEY_CURRENT_USER\Software\Mizage LLC\Divvy`

**Problem**:
- Cannot use GNU Stow for registry-based configurations
- Settings don't travel with dotfiles repository
- Manual reconfiguration required on each Windows rebuild
- No version control for Windows registry settings

**Potential Solutions**:

**Option 1: Registry Export/Import**
```powershell
# Export current settings to .reg file
reg export "HKEY_CURRENT_USER\Software\Mizage LLC\Divvy" divvy-config.reg

# Import settings on new machine
reg import divvy-config.reg
```

**Option 2: PowerShell Registry Management**
```powershell
# Set registry values via PowerShell script
New-ItemProperty -Path "HKCU:\Software\Mizage LLC\Divvy" -Name "ConfigKey" -Value "ConfigValue" -Force
```

**Option 3: Include in Bootstrap Process**
- Add registry configuration to `bootstrap.ps1`
- Import Divvy settings as part of system setup
- Store .reg files in `configs/divvy_win/` directory

**Registry-Based Apps Pattern**:
This affects other Windows applications that use registry instead of config files:
- Many Windows-native tools
- Some enterprise applications
- Legacy Windows software

## Windows Configuration Architecture Split

**Architectural Insight**: Windows requires two distinct configuration management approaches, following established dotfiles separation-of-concerns pattern.

**File-Based Configs** (existing `configs/` system):
- Managed via GNU Stow (external executor)
- Examples: keypirinha, wezterm, git, shell configs
- Pattern: `configs/app_name_win/` → stow executor → symlinked to target locations

**Registry-Based Configs** (new `win_reg_configs/` system):
- Managed via registry import/export (external executor)
- Examples: Divvy, many Windows-native apps, enterprise software
- Pattern: `win_reg_configs/app_name/` → registry executor → imported to Windows Registry

**Directory Structure**:
```
├── configs/                    # GNU Stow managed (file-based configs)
│   ├── keypirinha_choco/
│   ├── wezterm_common/
│   └── git_win/
└── win_reg_configs/           # Registry managed (registry-based configs)
    ├── divvy/
    │   └── settings.reg       # Pure config spec, no executors
    ├── other-app/
    │   └── config.reg
    └── another-app/
        └── preferences.reg
```

**Executor Examples** (external to config directories):
- `just import-registry` - Import all registry configs
- `just import-registry divvy` - Import specific app
- Manual: `reg import win_reg_configs/divvy/settings.reg`
- Bootstrap: `bootstrap.ps1` iterates through `win_reg_configs/`

**Benefits of Separation**:
- Config directories contain pure data (no execution logic)
- Multiple execution methods (manual, automated, selective)
- Consistent with existing package management and stow patterns
- Easy to version control .reg files without embedded scripts

---

### Implementation (Current)

- **Config source**: Top-level Git submodule at `win_reg_configs/` (per-app folders, e.g., `win_reg_configs/divvy/settings.reg`).
- **Machine class manifest**: `machine-classes/<class>/win-reg/manifest.txt` lists apps to import.
- **Importer**: `scripts/windows/import-regkeys.ps1` (Windows-only)
  - Dry-run:
    ```powershell
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows/import-regkeys.ps1 -WhatIf
    ```
  - Import all apps for current machine class:
    ```bash
    just import-win-regkeys
    ```
  - Import single app:
    ```powershell
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows/import-regkeys.ps1 -App divvy
    ```
  - Logs: `~/.dotfiles/logs/import-regkeys-*.log`

> Note: Keep `.reg` content in the `win_reg_configs/` submodule to minimize risk of exposing license-related data in the public repo.


## Windows Steals Ctrl+N from Divvy Workflow

**Issue**: Windows system shortcuts interfere with Divvy's local keybinds, specifically `Ctrl+N`.

**Workflow Impact**:
- Divvy popup: `Ctrl+Backspace` ✅ (works)
- Divvy local binds: `Ctrl+u/i/h/j/k/l/m` ✅ (work)
- Divvy local bind: `Ctrl+n` ❌ (stolen by Windows)
- Breaks "keep Control down and bam bam" workflow

**Root Cause**: Windows (likely Explorer or other system component) registers global `Ctrl+N` shortcut that takes precedence over application-level shortcuts.

**Investigation Tools**:
- ❌ ProcMon (wrong tool - doesn't track keyboard hooks)
- ✅ Spy++ (Visual Studio) - Monitor WM_KEYDOWN messages
- ✅ Process Explorer - Check processes with unusual handle counts
- ✅ PowerShell: `Get-Process | Where-Object {$_.Modules.ModuleName -like "*hook*"}`

**Proposed Solution: AutoHotkey Interceptor**

Create AutoHotkey script to intercept `Ctrl+N` and redirect appropriately:

```autohotkey
; Global interceptor - decides what to do with Ctrl+N
^n::
if WinActive("ahk_exe divvy.exe") {
    ; Send to Divvy for window placement
    Send, ^n
} else if WinActive("ahk_class CabinetWClass") {
    ; Send to Explorer (new folder)
    Send, ^n
} else {
    ; Default behavior for other apps
    Send, ^n
}
return
```

**TODO Tasks**:
1. Identify exact process stealing `Ctrl+N` (use Spy++ or Process Explorer)
2. Create AutoHotkey script for `Ctrl+N` interception
3. Test Divvy workflow with AutoHotkey running
4. Add AutoHotkey script to `configs/autohotkey/` for stow management
5. Include AutoHotkey setup in Windows bootstrap process

**Files to Create/Update**:
- `configs/autohotkey/divvy-keybind-fix.ahk`
- `setup/setup_win.ps1` - Windows system configuration (revive from deprecated/setup/setup_win)
- Keep bootstrap.ps1 focused on core dotfiles infrastructure only

---

## Revive and Modernize Cross-Platform Setup System

**Issue**: Comprehensive platform-specific setup functionality exists in `deprecated/setup_*` directories but is not integrated into current system.

**Current State - Deprecated Setup Scripts**:

**Windows** (`deprecated/setup_win/setup.ps1`):
- ✅ PowerShell modules (PSReadLine, PSFzf, posh-git, etc.)
- ✅ Scoop buckets and global apps (clink)
- ✅ Chocolatey apps (git)
- ✅ PowerShell prompt (oh-my-posh via winget)
- 🔄 Clink integrations (fzf, flex-prompt) - manual steps documented
- ✅ Divvy scheduled task automation
- ✅ WSL SSH port forwarding setup
- 🔄 Office key hijacking fix - manual steps documented
- ✅ MSYS2 environment variables (symlinks, PATH mode)

**Linux** (`deprecated/setup_linux/setup.sh`):
- ✅ Nerd Font installation via curl + fc-cache
- ✅ Minimap font installation

**macOS** (`deprecated/setup_osx/setup.sh`):
- ✅ Finder settings (show all files)
- ✅ TCC database reset (accessibility permissions)
- ✅ Scroll direction preferences

**Modernization Goals**:

1. **Revive as `setup/` directory** (not deprecated)
2. **Cross-platform consistency** - similar structure across all platforms
3. **Integration with existing architecture**:
   - Keep bootstrap lean (core dotfiles only)
   - Setup handles system optimizations and quality-of-life improvements
4. **Expand functionality** - add missing platform configurations
5. **Automation** - convert manual steps to automated implementations

**Proposed New Structure**:
```
setup/
├── setup_win.ps1          # Windows system configuration
├── setup_osx.sh           # macOS system configuration
├── setup_linux.sh         # Linux system configuration
├── common/                 # Cross-platform utilities
│   ├── fonts.sh           # Font installation (all platforms)
│   └── utils.sh           # Common functions
└── README.md               # Setup documentation and usage
```

**TODO Tasks**:
1. **Audit existing functionality** - catalog what works vs needs updating
2. **Create modern setup/ directory structure**
3. **Port Windows setup.ps1** with improvements:
   - Add AutoHotkey keybind fixes
   - Automate clink integrations (remove manual steps)
   - Add registry import functionality
4. **Expand Linux setup.sh**:
   - Add desktop environment configurations
   - Add development tool optimizations
5. **Expand macOS setup.sh**:
   - Add more Finder/system preferences
   - Add development environment optimizations
6. **Create common utilities**:
   - Cross-platform font installation
   - Shared setup patterns
7. **Integration commands**:
   - `just setup` - run platform-appropriate setup
   - `just setup-fonts` - install fonts across platforms
8. **Documentation** - comprehensive setup guide

**Benefits**:
- **Systematic system optimization** across all platforms
- **Reduced manual setup** after dotfiles deployment
- **Consistent experience** regardless of platform
- **Quality-of-life improvements** that make daily usage pleasant

**Priority**: Medium-High - significantly improves Windows rebuild experience and provides foundation for better cross-platform system configuration.

---

## Neovim XDG_CONFIG_HOME Integration

**Issue**: Neovim on Windows uses `%APPDATA%\Local\nvim` by default instead of the Unix-standard `~/.config/nvim`, requiring separate Windows-specific configuration.

**Problem**:
- Windows Neovim doesn't follow XDG Base Directory specification
- Separate `nvim_win` config needed for Windows-specific paths
- Duplicate configuration maintenance between `nvim_common` and `nvim_win`
- Inconsistent behavior across platforms

**Solution**: Use Windows registry to set `XDG_CONFIG_HOME` environment variable.

**Implementation**:
- Registry config: `win_reg_configs/xdg-config/xdg-config.reg`
- Sets `XDG_CONFIG_HOME=%USERPROFILE%\.config` in user environment
- Removes `nvim_win` from Windows machine classes
- Neovim now uses `~/.config/nvim` on Windows (same as POSIX)

**Registry Configuration**:
```registry
[HKEY_CURRENT_USER\Environment]
"XDG_CONFIG_HOME"="%USERPROFILE%\\.config"
```

**Benefits**:
- Single `nvim_common` configuration works across all platforms
- Consistent Neovim behavior on Windows and POSIX
- Eliminates duplicate configuration maintenance
- Follows XDG Base Directory specification

**Usage**:
```bash
# Import XDG environment variables (must be first)
just import-win-regkeys

# Deploy Neovim configuration (now uses ~/.config/nvim)
just stow
```

**Related Files**:
- `win_reg_configs/xdg-config/xdg-config.reg` - Registry configuration
- `machine-classes/*/win-reg/manifest.txt` - Includes xdg-config
- `configs/nvim_common/` - Single Neovim configuration for all platforms

---

## Additional Issues

*More issues will be documented here as they are encountered during Windows rebuilds.*
