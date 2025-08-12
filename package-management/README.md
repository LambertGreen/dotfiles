# Package Management System

A native package manager export/import system for dotfiles that uses each package manager's own format and provides a unified interface for managing packages across multiple platforms.

## Quick Start

1. **Configure your machine class**
   ```bash
   cd package-management
   just configure
   ```

2. **Preview what will be installed** (safe dry-run)
   ```bash
   just preview
   ```

3. **Install packages**
   ```bash
   just install
   ```

## Core Philosophy

- **Native Formats** - Uses each package manager's own export/import format (Brewfile, requirements.txt, etc.)
- **No Translation Layer** - Direct package manager commands, no intermediate processing
- **Battle-Tested Configs** - Export from real, working machines
- **Safety First** - Defaults to dry-run mode to preview changes
- **Modal Interface** - Quick all-in-one commands with selective control when needed

## Machine Classes

Machine classes use the naming convention: `<form_factor>_<purpose>_<os>`

### Available Classes
- `laptop_personal_mac` - Personal MacBook setup
- `wsl_work_ubuntu` - Work WSL2 Ubuntu environment
- `docker_test_ubuntu_min` - Minimal test environment
- `docker_test_ubuntu_mid` - Extended CLI tools
- `docker_test_ubuntu_max` - Full development environment
- `docker_test_arch` - Arch Linux testing

### Supported Package Managers

| OS | System PMs | Language PMs | App Store |
|----|------------|--------------|-----------|
| macOS | brew | pip, npm, gem, cargo | mas |
| Ubuntu | apt, brew | pip, npm, gem, cargo | snap |
| Arch | pacman | pip, npm, gem, cargo | - |
| Windows | scoop, choco, winget | pip, npm | - |

## Commands

### Basic Commands
```bash
just configure          # Configure machine class
just preview            # Preview what will be installed (dry-run)
just install            # Install all packages
just export             # Export current system to /tmp
```

### Selective Commands (Modal Interface)
```bash
# Show available commands
just installs           # List install commands
just updates            # List update commands

# Install from specific package managers
just install@brew       # Install via Homebrew
just install@pip        # Install via pip
just install@apt        # Install via APT

# Preview specific package managers
just preview@brew       # Preview Homebrew packages
just preview@pip        # Preview pip packages

# Update commands
just update-check       # Check for updates (all)
just update-all         # Update all packages
just update@brew        # Update via Homebrew only
just check@brew         # Check Homebrew updates only
```

### Utility Commands
```bash
just show-config        # Show current machine class
just list-machines      # List available machine classes
just show-packages [pm] # Show packages for current class
just clean              # Clean package manager caches
```

## Configuration

The system uses `~/.dotfiles.machine.class.env` for configuration:

```bash
# Package Management System - Machine Class Configuration
DOTFILES_MACHINE_CLASS=laptop_personal_mac
```

## Directory Structure

```
package-management/
├── machines/                           # Machine class definitions
│   ├── laptop_personal_mac/           # Personal Mac setup
│   │   ├── brew/Brewfile               # Homebrew packages
│   │   ├── pip/requirements.txt        # Python packages
│   │   ├── npm/packages.txt            # NPM packages
│   │   └── gem/Gemfile                 # Ruby gems
│   ├── docker_test_ubuntu_min/         # Minimal Ubuntu
│   │   └── apt/packages.txt            # Essential packages
│   └── ...
├── scripts/
│   ├── configure-machine-class.sh      # Setup machine class
│   ├── import.sh                       # Install packages
│   └── export.sh                       # Export current system
├── justfile                            # Command interface
└── README.md                           # This file
```

## Package Manager Dependencies

The system installs package managers in the correct order:

### macOS
1. **brew** - Installs Python, Node, Ruby
2. **pip** - Python packages (needs Python from brew)
3. **npm** - Node packages (needs Node from brew)
4. **gem** - Ruby gems (needs Ruby from brew)

### Ubuntu
1. **apt** - System packages
2. **brew** - Modern versions of dev tools
3. **pip** - Python packages
4. **npm** - Node packages

## Creating New Machine Classes

1. **Export current system**
   ```bash
   just export
   # Creates /tmp/machine-export-YYYY-MM-DD-HHMMSS/
   ```

2. **Create new machine class**
   ```bash
   mkdir -p machines/laptop_work_mac
   cp -r /tmp/machine-export-*/. machines/laptop_work_mac/
   ```

3. **Organize by package manager**
   ```bash
   # Files are already organized by PM directory
   ls machines/laptop_work_mac/
   # Output: brew/ pip/ npm/ gem/
   ```

## Examples

### Personal Mac Setup
```bash
# Configure
just configure
# Select: laptop_personal_mac

# Preview what will be installed
just preview
# Shows: Homebrew formulae, casks, mas apps, pip packages, etc.

# Install specific package manager first
just install@brew

# Then install everything else
just install
```

### Docker Testing
```bash
# Test minimal environment
DOTFILES_MACHINE_CLASS=docker_test_ubuntu_min just preview
DOTFILES_MACHINE_CLASS=docker_test_ubuntu_min just install

# Test full environment
DOTFILES_MACHINE_CLASS=docker_test_ubuntu_max just preview@brew
```

### Maintenance
```bash
# Check what can be updated
just update-check

# Update only fast package managers
just update@brew

# Update everything
just update-all

# Clean up caches
just clean
```

## Integration with Existing System

This package management system is designed to coexist with the existing TOML-based system during migration:

- Uses separate config file (`~/.dotfiles.machine.class.env`)
- Doesn't interfere with current `~/.dotfiles.env` 
- Can be tested independently
- Will eventually replace the TOML system

## Safety Features

- **Dry-run by default** - All commands preview changes first
- **Package manager native dry-run** - Uses `brew bundle --dry-run`, `apt --dry-run`, etc. where available
- **Dependency ordering** - Installs package managers in correct order
- **Availability checking** - Skips unavailable package managers gracefully
- **Clear output** - Shows what will be installed before doing it

## Querying Package Information

The explicit directory structure enables powerful querying:

```bash
# Which machines use Homebrew?
ls -d machines/*/brew/

# Find all pip packages across machines
cat machines/*/pip/requirements.txt | sort -u

# Where is emacs installed from?
rg "emacs" machines/*/brew/Brewfile machines/*/apt/packages.txt

# Compare packages between machines
diff machines/laptop_personal_mac/brew/Brewfile \
     machines/laptop_work_mac/brew/Brewfile
```

## Troubleshooting

### Machine class not configured
```bash
just configure
```

### Preview shows nothing
Check if your machine class directory exists and has package manager subdirectories:
```bash
just list-machines
just show-config
just show-packages
```

### Package manager not found
The system will skip unavailable package managers. Install them first:
```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install pip
sudo apt install python3-pip  # Ubuntu
brew install python           # macOS
```

### Permission errors
Some package managers require sudo (apt, pacman, snap). The scripts will prompt when needed.