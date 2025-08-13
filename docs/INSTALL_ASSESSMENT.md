# Dotfiles Install System Assessment

## Current Issues

### 1. Missing `stow-*-minimal` recipes
- `just/install.just:50` references `stow-{{platform}}-minimal` 
- These recipes don't exist in `configs/justfile`
- Only full platform stowing recipes exist (`stow-osx`, `stow-ubuntu`, etc.)

### 2. Circular Dependency
- Install commands require stowed package_management configs to work
- `install-cli` runs: `cd ~/.package_management/install && just install-cli-{{platform}}`
- But `~/.package_management/install` only exists after stowing package_management configs
- Creates a chicken-and-egg problem

### 3. No Bootstrap Mechanism
- No way to install initial tools (just, stow, git) needed to run the system
- Assumes these tools are already present

## Proper Machine Setup Order

1. **Bootstrap** (manual or scripted)
   - Install package manager (homebrew/apt/pacman)
   - Install essential tools: git, just, stow

2. **Clone & Initialize**
   - Clone dotfiles repo
   - Update git submodules

3. **Stow Minimal Configs**
   - Stow only package_management configs first
   - This creates ~/.package_management/install/

4. **Install Packages**
   - Now `just install cli/dev/gui` commands will work
   - Uses the stowed package management configs

5. **Stow Remaining Configs**
   - Stow all other application configs
   - Full environment is now set up

## Immediate Fixes Needed

1. Create `stow-*-minimal` recipes that only stow package_management
2. Update install commands to handle missing directories gracefully
3. Add clear documentation about prerequisites
4. Consider adding dry-run options for testing