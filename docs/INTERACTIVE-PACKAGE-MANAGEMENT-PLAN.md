# Interactive Package Management Plan

## Overview

Enhance the package management commands (`configure`, `install-packages`, `check-packages`, `upgrade-packages`) with interactive previews and opt-out controls using numbered lists and timeouts.

## User Experience Design

### Core Principles
1. **Transparency** - Show user exactly what will happen before doing it
2. **Opt-out approach** - Default to including all available package managers, let user exclude
3. **Timeout-based** - Don't block automation, proceed after timeout
4. **Numbered lists** - Easy selection via numbers (e.g., "1 3 5" to exclude items 1, 3, and 5)

## Command Enhancements

### 1. `just configure` - Machine Class + Package Manager Selection

**Current**: Only selects machine class
**Enhanced**: 
1. Select machine class
2. Show available package managers for the platform
3. Allow user to opt-out of specific package managers
4. Save configuration to `~/.dotfiles.env`

**Flow**:
```
🔧 Configuring dotfiles for this machine...

Step 1: Select machine class
1. laptop_personal_mac
2. laptop_work_mac  
3. desktop_home_ubuntu
[Continue with current machine class selection...]

Step 2: Package Manager Configuration
Available package managers for osx:
  1. brew (Homebrew) - 19 formulae, 3 casks
  2. pip (Python) - 7 packages  
  3. npm (Node.js) - 5 packages
  4. mas (Mac App Store) - 0 apps

Enter numbers to EXCLUDE (e.g., "2 4" to skip pip and mas) [timeout: 10s]: _
```

### 2. `just install-packages` - Preview + Confirm

**Current**: Directly installs packages
**Enhanced**:
1. Show what will be installed by each package manager
2. Show estimated time/impact
3. Allow opt-out of specific package managers
4. Proceed with timeout

**Flow**:
```
📦 Installing packages for laptop_work_mac...

The following package managers will install packages:

  1. brew (Homebrew)
     └─ 19 formulae, 3 casks (est. 5-10 min)
     └─ Requires: Internet connection
  
  2. pip (Python) 
     └─ 7 packages (est. 1-2 min)
     └─ Requires: Python 3.11+
  
  3. npm (Node.js)
     └─ 5 global packages (est. 30s)
     └─ Requires: Node.js 18+

Enter numbers to SKIP (e.g., "2" to skip pip) [timeout: 15s]: _

⏳ No input received, proceeding with all package managers...
```

### 3. `just check-packages` - Preview Updates

**Current**: Shows available updates
**Enhanced**:
1. Show update counts by package manager
2. Allow selective checking
3. Show what would be updated

**Flow**:
```
🔍 Checking for package updates...

Available package managers to check:

  1. brew (Homebrew)
     └─ Last checked: 2 hours ago
  
  2. pip (Python)
     └─ Last checked: Never
  
  3. npm (Node.js)
     └─ Last checked: 1 day ago

Enter numbers to SKIP (e.g., "3" to skip npm) [timeout: 10s]: _

Checking updates for: brew, pip...
```

### 4. `just upgrade-packages` - Preview + Confirm Upgrades

**Current**: Directly upgrades all
**Enhanced**:
1. Show what will be upgraded
2. Show potential risks/breaking changes
3. Allow selective upgrades
4. Confirmation with timeout

**Flow**:
```
⬆️  Upgrading packages for laptop_work_mac...

Available upgrades:

  1. brew (Homebrew)
     └─ 3 formulae updates available
     └─ node: 18.17.0 → 20.5.0 (major version!)
     └─ git: 2.41.0 → 2.42.0
  
  2. pip (Python)
     └─ 2 packages to upgrade
     └─ requests: 2.28.0 → 2.31.0
  
  3. npm (Node.js)
     └─ No updates available

⚠️  Note: Major version upgrades may have breaking changes

Enter numbers to SKIP (e.g., "1" to skip brew) [timeout: 20s]: _
```

## Technical Implementation

### Configuration Storage
Extend `~/.dotfiles.env`:
```bash
# Current
export DOTFILES_PLATFORM=osx
export DOTFILES_MACHINE_CLASS=laptop_work_mac

# Enhanced
export DOTFILES_PACKAGE_MANAGERS="brew,pip,npm"  # Enabled PMs
export DOTFILES_PACKAGE_MANAGERS_DISABLED="mas"  # Disabled PMs
```

### Numbered List Interface
```bash
# Function for opt-out selection
prompt_opt_out_selection() {
    local items=("$@")
    local timeout=${TIMEOUT:-10}
    
    echo "Enter numbers to EXCLUDE (e.g., '1 3 5') [timeout: ${timeout}s]:"
    
    if read -t $timeout -r input; then
        # Process user input
        local excluded_numbers=($input)
        # Return array with excluded items removed
    else
        echo "⏳ No input received, proceeding with all items..."
        # Return all items
    fi
}
```

### Package Manager Detection
```bash
# Detect available package managers for platform
detect_package_managers() {
    local platform="$1"
    local machine_class="$2"
    
    case "$platform" in
        osx)
            available_pms=("brew" "pip" "npm" "gem" "mas")
            ;;
        ubuntu|arch)
            available_pms=("apt" "brew" "pip" "npm" "gem")
            # arch uses pacman instead of apt
            ;;
    esac
    
    # Check what's actually configured for this machine class
    # Check what's installed on system
    # Return intersection
}
```

## File Changes Required

### 1. New Files
- `package-management/scripts/interactive-prompts.sh` - Common prompt functions
- `package-management/scripts/configure-interactive.sh` - Enhanced configure

### 2. Modified Files
- `package-management/scripts/import.sh` - Add interactive mode
- `package-management/scripts/show-packages.sh` - Add package manager summaries
- `justfile` - Update command descriptions
- `configure.sh` - Integrate package manager selection

### 3. Enhanced Functions
- Package manager detection and validation
- Interactive timeout-based prompts
- Configuration file management
- Preview generation for all operations

## Benefits

1. **User Control** - Users can exclude problematic package managers
2. **Transparency** - See exactly what will happen before it happens
3. **Safety** - Preview major version upgrades and breaking changes
4. **Automation-Friendly** - Timeouts ensure scripts don't hang
5. **Platform-Aware** - Different PM options per platform
6. **Machine-Class Aware** - Respects existing package configurations

## Next Steps

1. Implement interactive prompt library
2. Enhance configure script with PM selection
3. Add preview modes to install/check/upgrade commands
4. Test timeout behavior and user experience
5. Update documentation and help text

This approach maintains the simplicity of the current system while adding the control and transparency that power users need.