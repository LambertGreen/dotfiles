# Deprecated Category System - Files Needing Cleanup

The dotfiles system has migrated from a category-based approach (CLI_EDITORS, CLI_UTILS, etc.) to a machine-class approach. The following files contain references to the old category system and should be updated or removed:

## Files with Category System References

### 1. Docker Test Files (OLD TESTING APPROACH - DEPRECATED)
- `test/dockerfiles/Dockerfile.arch.multi` - Contains old DOTFILES_CLI_* environment variables
- `test/test-*-output.log` - Log files from old category-based tests

**Status**: These Docker tests use the old category system and should be replaced with new machine-class tests.

### 2. Deprecated TOML Package Management (ALREADY MOVED)
- `deprecated/toml-package-management/` - Entire directory with old category-based TOML approach
- Contains: package-definitions/*.toml files with category definitions

**Status**: Already moved to deprecated/ directory. Safe to remove entirely.

## Migration Summary

### Old System (Categories)
```bash
DOTFILES_CLI_EDITORS=true
DOTFILES_CLI_UTILS=true
DOTFILES_CLI_UTILS_HEAVY=false
DOTFILES_DEV_ENV=false
DOTFILES_GUI_APPS=false
```

### New System (Machine Classes)
```bash
DOTFILES_PLATFORM=osx
DOTFILES_MACHINE_CLASS=laptop_work_mac
```

Package definitions are now in:
- `package-management/machines/laptop_work_mac/brew/Brewfile`
- `package-management/machines/laptop_work_mac/pip/requirements.txt`
- etc.

## Action Items

1. **Update Docker Tests**: Create new Docker tests using machine classes instead of categories
2. **Remove Deprecated TOML**: Clean up `deprecated/` directory
3. **Update Test Logs**: Remove old test output logs that reference categories
4. **Documentation**: Update any remaining docs that reference the old category system

## Files Already Fixed

- ✅ `justfile` - Removed category references from help text
- ✅ `tools/dotfiles-health/dotfiles-health.sh` - The `_categorize_symlinks` function is fine (categorizes symlink types, not package categories)
