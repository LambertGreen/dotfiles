# Dotfiles Repository Cleanup Assessment

## Overview

This assessment identifies cleanup opportunities to standardize on Python over shell scripts and consolidate test files.

## Current State

### Shell Scripts Analysis
- **Total shell scripts**: ~150+ files
- **Package management scripts**: 45 files
- **Bootstrap scripts**: 15 files  
- **Health check scripts**: 2 files
- **Third-party scripts**: ~80+ (in configs/, mostly Alfred workflows and Emacs packages)

### Python Scripts Analysis
- **Package management Python**: 6 files (new, modern)
- **Third-party Python**: ~200+ (mostly Alfred workflows and Emacs packages)
- **Our Python**: 6 files

### Test Files Analysis
- **Proper test location** (`./test/` and `./tests/`): ✅ Good
- **Scattered test files**: ~50+ files outside test directories
- **Test script files in root**: 3 files that should move

## Cleanup Priorities

### 🚨 HIGH PRIORITY: Package Management Migration

**Target**: Replace 45 shell scripts with Python implementations

**Current Python Coverage**:
- ✅ `pm.py` - Unified entry point (check, upgrade, list, configure)  
- ✅ `pm_detect.py` - PM detection
- ✅ `pm_select.py` - Interactive selection
- ✅ `pm_check.py` - Check for updates
- ✅ `pm_upgrade.py` - Upgrade packages
- ✅ `pm_configure.py` - Configure enabled/disabled PMs

**Shell Scripts to Migrate**:

1. **Install Scripts** (Priority 1):
   ```
   install-system-packages.sh  → pm.py install system
   install-dev-packages.sh     → pm.py install dev  
   install-app-packages.sh     → pm.py install app
   ```

2. **Category-specific Scripts** (Priority 2):
   ```
   check-system-packages.sh    → pm.py check --category system
   check-dev-packages.sh       → pm.py check --category dev
   check-app-packages.sh       → pm.py check --category app
   upgrade-system-packages.sh  → pm.py upgrade --category system
   upgrade-dev-packages.sh     → pm.py upgrade --category dev
   upgrade-app-packages.sh     → pm.py upgrade --category app
   ```

3. **PM-specific Scripts** (Priority 3):
   ```
   brew/install-brew-packages.sh
   npm/install-npm-packages.sh
   pip/install-pip-packages.sh
   cargo/install-cargo-packages.sh
   gem/install-gem-packages.sh
   apt/install-apt-packages.sh
   pacman/install-pacman-packages.sh
   ```

4. **Utility Scripts** (Priority 4):
   ```
   show-packages.sh            → pm.py show
   show-package-stats.sh       → pm.py stats
   verify-dev-package-install.sh → pm.py verify
   export-and-update-machine.sh → pm.py export
   ```

5. **Legacy/Obsolete Scripts** (Priority 5 - Delete):
   ```
   list-pms.sh                 → Already replaced by pm.py list
   check-packages.sh           → Already replaced by pm.py check  
   upgrade-packages.sh         → Already replaced by pm.py upgrade
   check-packages-new.sh       → Experimental, can delete
   orchestrator.sh             → Complex, assess if needed
   ```

### 🔶 MEDIUM PRIORITY: Test File Consolidation

**Target**: Move scattered test files to proper locations

**Files to Move**:
```bash
# Move to test/ directory
./test-e2e-fake.py          → ./test/test_e2e_fake.py
./test-interactive.sh       → ./test/test_interactive.sh  
./test-pm-selection.sh      → ./test/test_pm_selection.sh
./pytest.ini               → Keep in root (standard location)
./requirements-test.txt     → Keep in root (standard location)

# Files already in correct location
./test/                     ✅ Good
./tests/                    ✅ Good  
```

**Third-party Test Files**:
- ~50+ test files in `configs/` - these are part of Alfred/Emacs packages, leave alone

### 🔷 LOW PRIORITY: Other Shell Scripts

**Bootstrap Scripts**: Keep as shell (platform-specific, simple)
```
scripts/bootstrap/install-*.sh   → Keep (platform installers)
bootstrap.sh                    → Keep (entry point)
configure.sh                    → Keep (interactive config)
```

**Health/Utility Scripts**: Consider migrating
```
scripts/health/dotfiles-health.sh         → Python for better testing
scripts/health/test-dotfiles-health.sh    → Python  
scripts/show-config.sh                    → Python
scripts/stow/stow.sh                      → Keep (simple wrapper)
```

**Third-party Scripts**: Don't touch
```
configs/alfred-settings/.../*.sh          → Leave alone
configs/emacs_common/.../.../*.sh         → Leave alone  
deprecated/.../*.sh                       → Leave alone
```

## Migration Strategy

### Phase 1: Complete Package Management Migration
1. Extend `pm.py` with install functionality
2. Add category support (system/dev/app)
3. Migrate high-priority install scripts
4. Update justfile recipes
5. Test with fake PMs

### Phase 2: Test Consolidation  
1. Move root-level test files to `test/`
2. Ensure all tests work from new locations
3. Update CI/documentation

### Phase 3: Utility Migration
1. Convert `show-packages.sh` → `pm.py show`
2. Convert `show-package-stats.sh` → `pm.py stats`
3. Convert health check scripts to Python
4. Remove obsolete shell scripts

### Phase 4: Cleanup
1. Delete replaced shell scripts
2. Update documentation
3. Remove unused shared shell utilities

## Expected Benefits

1. **Consistency**: All PM operations through single Python interface
2. **Maintainability**: Python easier to debug/test than shell
3. **Cross-platform**: Better Windows/Linux compatibility
4. **Testing**: Easier to unit test Python than shell
5. **Editor Support**: Jump-to-definition, LSP features
6. **Reduced Complexity**: Fewer languages/approaches

## Risk Assessment

**Low Risk**:
- Package management migration (already proven with check/upgrade)
- Test file moves (just file relocations)

**Medium Risk**:
- Complex shell scripts (orchestrator.sh, export scripts)
- Breaking existing workflows during transition

**Mitigation**:
- Keep old scripts during transition
- Extensive testing with fake PMs
- Gradual migration with fallbacks

## File Count Impact

**Before Cleanup**:
- Shell scripts: ~150
- Python scripts: ~6 (ours)
- Test files scattered: ~50

**After Cleanup**:
- Shell scripts: ~100 (remove 45 PM scripts + ~5 utilities)
- Python scripts: ~15 (add 9 PM modules)
- Test files consolidated: 0 scattered

**Net Result**: -45 shell scripts, +9 Python scripts, cleaner organization
