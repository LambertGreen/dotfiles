# Migration from Shell to Python

## Status: In Progress

We're standardizing on Python for all package management operations. This provides:
- Better cross-platform support
- Easier testing and debugging
- Better editor support (jump to definition, LSP)
- More maintainable code

## Completed ✅

1. **Core Python Modules**
   - `pm.py` - Unified entry point for all PM operations
   - `pm_detect.py` - Package manager detection
   - `pm_select.py` - Interactive PM selection
   - `pm_check.py` - Check for outdated packages
   - `pm_upgrade.py` - Upgrade packages
   - `pm_configure.py` - Configure enabled/disabled PMs

2. **Bootstrap Updates**
   - Added Python3 to required tools for all platforms
   - Created `install-python3-*.sh` scripts for each platform
   - Updated bootstrap flow to install Python before other tools

3. **Justfile Integration**
   - `just list-pms` → `pm.py list`
   - `just check-packages` → `pm.py check`
   - `just upgrade-packages` → `pm.py upgrade`
   - `just configure-pms` → `pm.py configure`

## To Be Migrated 🚧

### High Priority
These are directly called from justfile and should be migrated first:

1. **Install Commands**
   - `install-system-packages.sh` → `pm.py install system`
   - `install-dev-packages.sh` → `pm.py install dev`
   - `install-app-packages.sh` → `pm.py install app`

2. **Category-specific Operations**
   - `check-system-packages.sh`
   - `check-dev-packages.sh`
   - `check-app-packages.sh`
   - `upgrade-system-packages.sh`
   - `upgrade-dev-packages.sh`
   - `upgrade-app-packages.sh`

3. **Package Information**
   - `show-packages.sh` → `pm.py show`
   - `show-package-stats.sh` → `pm.py stats`

### Medium Priority
These are helper scripts that can be gradually replaced:

1. **PM-specific Scripts** (in subdirectories)
   - `brew/install-brew-packages.sh`
   - `npm/install-npm-packages.sh`
   - `pip/install-pip-packages.sh`
   - etc.

2. **Initialization Scripts**
   - `init-dev-packages.sh`
   - `emacs/init-emacs-packages.sh`
   - `neovim/init-neovim-packages.sh`
   - `zsh/init-zsh-packages.sh`

### Low Priority
These can remain as shell for now:

1. **Shared Utilities** (being phased out)
   - `shared/common.sh`
   - `shared/logging.sh`
   - `shared/package-utils.sh`
   - `shared/pm-detection.sh`
   - `shared/brew-lock-utils.sh`

2. **Configuration Scripts**
   - `configure-machine-class.sh`
   - `export-and-update-machine.sh`

## Migration Strategy

1. **Phase 1** (Current)
   - ✅ Create unified `pm.py` module
   - ✅ Migrate core check/upgrade functionality
   - ✅ Update bootstrap to ensure Python

2. **Phase 2** (Next)
   - Migrate install functionality to Python
   - Add category support (system/dev/app) to `pm.py`
   - Update justfile recipes

3. **Phase 3**
   - Migrate PM-specific logic to Python modules
   - Create Python package classes for each PM
   - Remove dependency on shell scripts

4. **Phase 4**
   - Clean up and remove obsolete shell scripts
   - Update documentation
   - Update tests

## Testing Strategy

- Use fake PMs for fast iteration
- E2E tests that don't impact the system
- CI-friendly test mode with `DOTFILES_PM_ONLY_FAKES=true`

## Environment Variables

The Python scripts respect:
- `DOTFILES_PM_ENABLED` - Comma-separated enabled PMs
- `DOTFILES_PM_DISABLED` - Comma-separated disabled PMs  
- `DOTFILES_PM_ONLY_FAKES` - Testing mode
- `DOTFILES_PM_DISABLE_REAL` - CI mode

## Commands for Testing

```bash
# Test with fake PMs
PATH="./test:$PATH" just list-pms
PATH="./test:$PATH" just check-packages
PATH="./test:$PATH" just upgrade-packages

# Run E2E tests
just test-e2e
just test-e2e-ci
```
