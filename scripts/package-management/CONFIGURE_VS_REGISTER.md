# Configure vs Register Package Managers

## The Problem

When setting up a fresh machine:
1. `just configure` sets up platform and machine class
2. Machine class defines *desired* package managers (what should be installed)
3. `just bootstrap` installs core tools (Python, stow, just)
4. `just install-packages` installs the package managers themselves
5. Only AFTER install do we know what PMs are actually available

## The Solution: Two Separate Commands

### `just configure` (Initial Setup)
- Sets platform (osx, ubuntu, arch)
- Sets machine class (laptop_work_mac, etc.)
- Shows what PMs the machine class *expects* to have
- Does NOT enable/disable PMs (they may not exist yet)

### `just register-pms` (Post-Install)
- Detects what PMs are ACTUALLY installed on the system
- Lets user enable/disable specific PMs
- Saves to `DOTFILES_PM_ENABLED` and `DOTFILES_PM_DISABLED`
- Should be run AFTER installing packages

## Workflow

```bash
# Fresh machine setup
just configure          # Set platform & machine class
just bootstrap          # Install Python, stow, just
just stow              # Deploy dotfiles
just install-packages   # Install package managers

# After packages are installed
just register-pms       # Enable/disable installed PMs
just check-packages     # Check for updates
just upgrade-packages   # Upgrade packages
```

## Implementation Notes

- `configure.sh` should NOT set `DOTFILES_PACKAGE_MANAGERS`
- `configure.sh` shows machine class PMs for information only
- `pm.py configure` detects and manages actual installed PMs
- The Python code already handles this correctly with `detect_all_pms()`
