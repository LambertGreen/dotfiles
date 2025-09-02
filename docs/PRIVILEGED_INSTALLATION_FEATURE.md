# Privileged Installation Feature

## Overview

Implement a multi-stage installation system that separates packages based on privilege requirements, giving users control over when to provide admin/sudo credentials and making the system more suitable for CI/Docker and corporate environments.

## Problem Statement

Currently, package installation mixes operations that require administrative privileges with those that don't, leading to:
1. Unnecessary privilege escalation for userspace tools
2. Difficulty in CI/Docker environments where sudo isn't available
3. Problems in corporate environments where users may lack admin rights
4. Security concerns from running too much with elevated privileges
5. Poor user experience with repeated password prompts

## Design Goals

1. **Clear Separation** - Distinct stages for privileged vs unprivileged operations
2. **Cross-Platform** - Works on macOS, Linux, and Windows
3. **Flexible** - Support both coarse-grained (by stage) and fine-grained (by package) control
4. **CI-Friendly** - Can skip privileged operations with a flag
5. **User Control** - Single password prompt per privileged stage
6. **Backwards Compatible** - Existing commands continue to work

## Proposed Architecture

### Explicit Classification Model

Instead of assuming privilege requirements based on package manager type, we use **explicit classification** to give users granular control over admin usage and enable fire-and-forget updates for the majority of packages.

#### Package Classification (4-way split):
```
machine-classes/laptop_personal_mac/brew/
├── Brewfile.formulas.non_admin      # CLI tools, libraries, dev utilities
├── Brewfile.formulas.requires_admin # System services, background daemons, privileged helpers
├── Brewfile.casks.non_admin         # GUI apps without services (cursor, stats, firefox)
└── Brewfile.casks.requires_admin    # GUI apps with services (vscode, docker, etc.)
```

#### Abstract Update Commands:
```bash
# Fire-and-forget updates (majority of packages)
just upgrade-packages-non-admin      # All formulas + casks marked as non-admin

# Scheduled/supervised updates (minimal set)
just upgrade-packages-requires-admin # Only packages explicitly requiring admin
```

### Platform-Specific Classifications

#### macOS
- **Formulas (non-admin)**: git, tmux, neovim, ripgrep, fd, jq, etc.
- **Formulas (requires-admin)**: docker (privileged helper), nginx (system service)
- **Casks (non-admin)**: cursor, stats, firefox, raycast, keycastr (most GUI apps)
- **Casks (requires-admin)**: visual-studio-code (launchctl service), docker-desktop, etc.

#### Linux
- **Formulas (non-admin)**: brew formulas, pip --user, npm prefix, gem --user-install
- **Formulas (requires-admin)**: System services installed via brew
- **System packages (requires-admin)**: apt/pacman/dnf packages (always need sudo)
- **Casks (non-admin)**: Homebrew casks on Linux (when available)

#### Windows
- **Scoop (non-admin)**: Primary package manager, local user installs
- **Scoop (requires-admin)**: Global installs with -g flag (fonts, system tools)
- **Chocolatey (requires-admin)**: Always requires admin privileges by design
- **Language packages (non-admin)**: pip --user, npm prefix

### Benefits of Explicit Classification

1. **Minimize Admin Usage**: User explicitly controls what requires privileges
2. **Fire-and-Forget Updates**: Majority of packages can update unattended
3. **Performance Incentive**: Apps requiring admin become "second-class citizens"
4. **Security**: Minimal privilege escalation, explicit attack surface
5. **Flexibility**: A package can move between classifications as needed
6. **Platform Consistency**: Same pattern across macOS, Linux, Windows

### Implementation Strategy

#### Package File Structure:
```
machine-classes/{machine_class}/{package_manager}/
├── {type}.non_admin           # No admin privileges required
└── {type}.requires_admin      # Admin privileges required

# Examples:
brew/Brewfile.formulas.non_admin
brew/Brewfile.casks.requires_admin
apt/packages.non_admin.txt
scoop/packages.requires_admin.json
```

#### Classification Process:
1. **Default Assumption**: Most packages are non-admin
2. **Explicit Marking**: Only mark packages as requires-admin when tested/confirmed
3. **Conservative Approach**: When in doubt, start with requires-admin, move to non-admin after testing
4. **Documentation**: Track why specific packages require admin (services, drivers, etc.)

## Platform-Specific Considerations

### macOS
- Homebrew official method: `brew upgrade --cask --greedy` for comprehensive cask updates
- Some formulas need sudo for services or privileged helpers
- macOS Ventura+ allows some casks without admin if Terminal has "App Management" permission
- Mac App Store apps use separate authentication

### Linux
- System package managers (apt, pacman, dnf) always need sudo
- Homebrew on Linux generally doesn't need sudo (installed in home)
- Snap/Flatpak can work without sudo if configured
- systemd user services don't need sudo

### Windows
- Scoop: Preferred for userspace, supports `-g` flag for global (needs admin)
- Chocolatey: Always requires admin, but more packages available
- WinGet: Mixed - some packages need admin, others don't
- MSYS2: Can work without admin if installed in user directory

## Implementation Plan

### Phase 1: macOS Implementation (Current Focus)
1. **Package Classification**: Split current Brewfile into 4 explicit categories
   - Brewfile.formulas.non_admin (majority of CLI tools)
   - Brewfile.formulas.requires_admin (docker, nginx with services)
   - Brewfile.casks.non_admin (cursor, stats, firefox, etc.)
   - Brewfile.casks.requires_admin (vscode with launchctl, docker-desktop)

2. **Abstract Commands**: Implement the two-tier update system
   - `upgrade-packages-non-admin` (fire-and-forget, majority)
   - `upgrade-packages-requires-admin` (scheduled, minimal set)

3. **Brew Script Integration**: Update existing brew upgrade script to handle classification
   - Support filtering by non_admin vs requires_admin
   - Maintain official `brew upgrade --cask --greedy` method

4. **Testing and Classification**: Test current packages to categorize correctly
   - Default to non-admin, move to requires-admin only when proven necessary

### Phase 2: Linux Implementation
1. **APT/Pacman**: Always requires-admin by design (system packages)
2. **Homebrew on Linux**: Primarily non-admin (user-space installs)
3. **Language Packages**: pip --user, npm prefix → non-admin
4. **Docker Testing**: Validate non-admin flows in containers

### Phase 3: Windows Implementation  
1. **Scoop Classification**:
   - Local installs → packages.non_admin.json (preferred)
   - Global installs (-g flag) → packages.requires_admin.json (fonts, system tools)
2. **Chocolatey**: Always packages.requires_admin.json (admin required by design)
3. **Language Packages**: pip --user, npm prefix → non-admin flows

### Phase 4: Enhanced Features
1. **Migration Tools**: Convert existing Brewfiles to classified format
2. **Reporting**: Show counts of non-admin vs requires-admin packages
3. **CI Integration**: Skip requires-admin flows in automated environments  
4. **Package Movement**: Easy tools to reclassify packages between categories

## User Interface

### Primary Commands (Fire-and-Forget vs Scheduled)
```bash
# Fire-and-forget updates (majority of packages, no admin needed)
just upgrade-packages-non-admin      # Most formulas + most casks

# Scheduled/supervised updates (minimal set, may prompt for password)  
just upgrade-packages-requires-admin # Only explicitly admin-requiring packages

# Check what needs updating
just check-packages-non-admin
just check-packages-requires-admin

# Backwards compatible (runs both non-admin and requires-admin)
just upgrade-packages  # Will run non-admin first, then prompt for admin
```

### Package Management Commands
```bash
# Install everything (separated by privilege level)
just install-packages-non-admin      # Fire-and-forget installation
just install-packages-requires-admin # Supervised installation with prompts

# Traditional (backwards compatible)
just install-packages  # Runs both stages
```

### Information Commands  
```bash
# Show classification breakdown
just show-package-classification     # Count of non-admin vs requires-admin

# Show what's in each category
just show-packages-non-admin
just show-packages-requires-admin
```

## Configuration

### Environment Variables
```bash
# Skip privileged operations
SKIP_PRIVILEGED=1

# Force privileged mode (for testing)
FORCE_PRIVILEGED=1

# Specify sudo command (for custom elevation)
SUDO_COMMAND="sudo -E"
```

### Machine Class Configuration
```yaml
# machine-classes/laptop_personal_mac/config.yaml
stages:
  userspace:
    enabled: true
    package_managers: [brew, pip, npm, gem]
  privileged:
    enabled: true
    package_managers: [brew-casks, mas]
  post_install:
    enabled: true
    scripts: [configure-apps.sh]
```

## Testing Strategy

1. **Docker Testing**: Run userspace stage only (SKIP_PRIVILEGED=1)
2. **VM Testing**: Test full privileged flow in VMs
3. **CI Pipeline**: Validate userspace installs in GitHub Actions
4. **Manual Testing**: Test on real machines for each platform

## Migration Path

1. Existing commands continue to work (install both stages)
2. New staged commands available immediately
3. Gradual migration of machine classes to split package files
4. Documentation and examples for new workflow

## Success Metrics

- Reduced privilege escalation (measured by sudo prompts)
- Successful CI/Docker runs without privileged operations
- Support for users without admin rights
- Cleaner separation of concerns in package definitions
- Improved installation speed (parallel userspace installs)

## Open Questions

1. Should we auto-detect packages that need privileges?
2. How to handle packages that can work with degraded functionality without admin?
3. Should we support interactive selection of privileged packages?
4. How to handle package manager updates themselves (brew update, etc.)?

## References

- [Homebrew Cask Upgrade Documentation](https://docs.brew.sh/FAQ)
- [Scoop Global Installs](https://github.com/ScoopInstaller/Scoop/wiki/Global-Installs)
- [Chocolatey Security](https://docs.chocolatey.org/en-us/security)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
