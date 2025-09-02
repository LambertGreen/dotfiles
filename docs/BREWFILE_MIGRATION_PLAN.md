# Brewfile Migration Plan: Monolithic → Classified System

## Current State
The project currently uses both systems:
- **Legacy**: Single `Brewfile` with all packages mixed together
- **New**: Classified `Brewfile.{formulas|casks}.{non_admin|requires_admin}` + `Brewfile.mas`

## Goal
Migrate all scripts from the monolithic `Brewfile` to the classified system while maintaining backward compatibility.

## Migration Strategy

### Phase 1: Dual System Support (Current)
- ✅ New upgrade scripts use classified system
- ✅ Classified Brewfiles created for both machine classes  
- ✅ Main Brewfiles kept for legacy script compatibility
- 📝 **Status**: Upgrade system complete, legacy scripts still functional

### Phase 2: Script Migration (In Progress)
Update core scripts to prefer classified system with fallback to legacy:

#### Priority Order:
1. **import.sh** - Package installation (highest impact)
2. **export.sh** - Package export and machine updates  
3. **show-packages.sh** - Package listing and display
4. **dotfiles-health.sh** - Health checks and validation
5. **show-package-stats.sh** - Statistics and counting
6. **interactive-prompts.sh** - User interface components

#### Implementation Approach:
```bash
# Preferred: Use classified system
if [[ -f "${pm_dir}/Brewfile.formulas.non_admin" ]]; then
    # Use new classified system
    process_classified_brewfiles
else
    # Fallback: Use legacy system
    if [[ -f "${pm_dir}/Brewfile" ]]; then
        process_legacy_brewfile
    fi
fi
```

### Phase 3: Legacy Deprecation
Once all scripts support classified system:
1. Add deprecation warnings for legacy Brewfiles
2. Update documentation to recommend classified system
3. Migrate any remaining legacy Brewfiles

### Phase 4: Legacy Removal
After sufficient deprecation period:
1. Remove main `Brewfile` support from scripts
2. Delete legacy `Brewfile` files
3. Update all documentation

## Benefits of Classified System

### For Users:
- **Fire-and-forget upgrades**: Non-admin packages upgrade without password prompts
- **Explicit privilege control**: Clear separation of admin vs non-admin packages  
- **Faster operations**: Smaller, focused package lists
- **Better organization**: Logical separation by type and privilege level

### For Scripts:
- **Targeted operations**: Process only relevant package subsets
- **Improved performance**: Avoid processing irrelevant packages
- **Clearer logic**: Explicit handling of different package types
- **Better error handling**: Granular failure modes per category

## Implementation Notes

### Classified File Structure:
```
machine-classes/{MACHINE_CLASS}/brew/
├── Brewfile.formulas.non_admin      # CLI tools, libraries
├── Brewfile.formulas.requires_admin # Docker, system services  
├── Brewfile.casks.non_admin        # GUI apps, fonts
├── Brewfile.casks.requires_admin   # System integration apps
├── Brewfile.mas                    # Mac App Store apps
└── Brewfile                        # Legacy (to be deprecated)
```

### Admin vs Non-Admin Classification:
- **Non-Admin**: Standard applications, CLI tools, fonts
- **Requires Admin**: System integration, services, privileged helpers, kernel extensions

### Backward Compatibility:
During transition, scripts should:
1. Check for classified files first
2. Fall back to legacy Brewfile if needed
3. Log deprecation warnings for legacy usage
4. Maintain identical functionality regardless of system used

## Current Progress
- ✅ Upgrade system migrated (upgrade-brew-packages-v2.sh)
- ✅ Classified Brewfiles created for laptop_work_mac and laptop_personal_mac
- ✅ Pinning system implemented for admin-required formulas
- 🔄 Script migration in progress (import.sh next priority)

## Next Steps
1. Update `import.sh` to support classified installation
2. Create migration utilities to convert existing Brewfiles
3. Update health checks to validate classified system
4. Add deprecation warnings to legacy code paths
