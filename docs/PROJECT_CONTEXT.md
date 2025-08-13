# Dotfiles Reorganization Project Context

## Project Goal
Refactor dotfiles repository to use a new organized structure with the `configs/` directory system and merge to main branch for deployment across all machines.

## Current State (feature/reorganize-stow-configs branch)
- **New Structure**: All stowable configs moved to `configs/` directory
- **Platform Organization**: Platform-specific configs use suffixes (_osx, _win, _linux, _msys2)
- **Justfile System**: Tiered installation system (basic, typical, max levels)
- **Docker Testing**: Comprehensive testing infrastructure for Linux distributions
- **Package Management**: Refactored from sys_maintenance to package_management

## Old vs New System Detection
**Old System Indicators:**
- Symlinks pointing directly to ~/dotfiles/{package} (no configs/ in path)
- Packages at root level: emacs, hammerspoon, nvim, alfred-settings, autohotkey, nvim_win

**New System Indicators:**
- Symlinks containing ~/dotfiles/configs/ in their path
- Organized structure with platform suffixes

## Migration Requirements
1. **Detection Script**: Check symlinks in:
   - Home directory (~)
   - XDG config directory (~/.config)
   - Windows AppData directories (~/AppData/Local, ~/AppData/Roaming)
   - Other standard locations

2. **Migration Steps**:
   - Unstow old packages from root directory
   - Stow new packages from configs/ directory
   - Preserve any local modifications or additional files
   - Update any hardcoded paths in scripts

3. **Platform Considerations**:
   - macOS: Check for Homebrew, Mac-specific app configs
   - Windows: Handle both MSYS2 and native Windows paths
   - Linux: Consider distribution differences

## Progress Tracking
- [x] Repository reorganization complete
- [x] Justfile system implemented
- [x] Docker testing infrastructure
- [x] Health check system with comprehensive tests
- [x] Health check integrated into top-level justfile
- [ ] Migration helper scripts
- [ ] Test migration on all platforms
- [ ] Document migration process
- [ ] Merge to main
- [ ] Deploy to all machines

## Next Steps
1. Create migration detection script
2. Create automated migration script
3. Test on each platform
4. Document the migration process
5. Prepare for merge to main

## Notes
- The end goal is to have all machines using the new structure
- Migration must be safe and reversible
- Should detect mixed states (partially migrated systems)