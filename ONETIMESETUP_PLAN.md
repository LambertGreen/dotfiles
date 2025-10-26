# Onetime Setup System - Implementation Plan

## Overview

Create a unified onetime setup system that runs platform-specific configuration tasks once per machine. These are distinct from bootstrap (tool installation) and regular shell setup (runs every login).

## Design Principles

1. **Idempotent**: Safe to re-run without side effects
2. **Platform-aware**: Detects OS and only runs relevant tasks
3. **Non-blocking**: Shell startup warns if incomplete but doesn't block
4. **Granular**: Individual tasks can be run separately
5. **Tracked**: State managed in `~/.dotfiles/`
6. **Secure**: Functions sourced, not executable scripts

---

## Architecture

### 1. State Management in `~/.dotfiles/`

All dotfiles system state goes in `~/.dotfiles/` (NOT in repo):

```
~/.dotfiles/
├── logs/                           # All logs (bootstrap, packages, etc.)
│   ├── bootstrap-*.log
│   ├── check-packages-*.log
│   └── onetimesetup-*.log
├── onetimesetup.done               # Completion marker
└── machine-config.env              # Machine-specific config (if needed)
```

**Changes Required:**
- Move `logs/` from repo to `~/.dotfiles/logs/`
- Update `bootstrap.sh`: `LOG_DIR="${HOME}/.dotfiles/logs"`
- Update `.gitignore` to ignore repo's `logs/` directory

### 2. Config Structure (Platform-Specific via Stow)

```
configs/
├── onetimesetup_common/
│   └── dot-onetimesetup.sh         # → ~/.onetimesetup.sh
├── onetimesetup_linux/
│   └── dot-onetimesetup_linux.sh   # → ~/.onetimesetup_linux.sh
├── onetimesetup_osx/
│   └── dot-onetimesetup_osx.sh     # → ~/.onetimesetup_osx.sh
└── onetimesetup_wsl/
    └── dot-onetimesetup_wsl.sh     # → ~/.onetimesetup_wsl.sh
```

**Deployment:**
```bash
# On Linux:
stow onetimesetup_common onetimesetup_linux

# On macOS:
stow onetimesetup_common onetimesetup_osx

# On WSL:
stow onetimesetup_common onetimesetup_linux onetimesetup_wsl
```

### 3. Shell Integration (in `dot-zprofile`)

Add after `lgreen_start_agents()`:

```bash
# * Onetime Setup
# Source onetime setup functions (platform-specific)
[ -f ~/.onetimesetup.sh ] && source ~/.onetimesetup.sh

if [ "$(uname_cached)" = "Darwin" ]; then
    [ -f ~/.onetimesetup_osx.sh ] && source ~/.onetimesetup_osx.sh
elif [ "$(uname_cached)" = "Linux" ]; then
    [ -f ~/.onetimesetup_linux.sh ] && source ~/.onetimesetup_linux.sh
    [ -f ~/.onetimesetup_wsl.sh ] && source ~/.onetimesetup_wsl.sh
fi

# Warn if not complete (non-blocking)
if command -v lgreen_onetimesetup_check_done >/dev/null 2>&1; then
    if ! lgreen_onetimesetup_check_done; then
        echo ""
        echo "⚠  Onetime setup not complete. Run: lgreen_onetimesetup_run_all"
        echo ""
    fi
fi
```

---

## Task Inventory

### Cross-Platform Tasks (`onetimesetup_common`)

#### 1. Git Remote URL Configuration
**Source**: `deprecated/setup/setup.sh`
- Function: `lgreen_onetimesetup_git_remotes()`
- Purpose: Configure GitHub SSH hosts for personal vs work accounts
- Requires: `~/.ssh/config` with `github.com-personal` and `github.com-work`
- Interactive: Prompt user which account type

#### 2. Wezterm Shell Completions
**Source**: `deprecated/setup/setup.sh`
- Function: `lgreen_onetimesetup_wezterm_completions()`
- Purpose: Generate shell completions for wezterm
- Requires: wezterm installed
- Output: `~/.config/zsh/completions/_wezterm`

#### 3. GPG Key Trust Setup
**New task** (from recent keychain work)
- Function: `lgreen_onetimesetup_gpg_trust()`
- Purpose: Set GPG key trust to avoid "unknown" warnings
- Keys: `C1D12B816253EFFD`, `66C09F6FD3D4A735`
- Command: `echo "KEYID:6:" | gpg --import-ownertrust`

### macOS-Specific Tasks (`onetimesetup_osx`)

#### 4. SSH Keys → macOS Keychain Integration
**New task** (from recent keychain work)
- Function: `lgreen_onetimesetup_macos_ssh_keychain()`
- Purpose: Store SSH passphrases in macOS Keychain.app
- Command: `ssh-add --apple-use-keychain ~/.ssh/id_*`
- Benefit: Automatic unlock on login, integrates with system keychain

#### 5. Finder Configuration
**Source**: `deprecated/setup_osx/setup.sh`
- Function: `lgreen_onetimesetup_macos_finder()`
- Purpose: Show hidden files in Finder
- Command: `defaults write com.apple.finder AppleShowAllFiles TRUE`

#### 6. Disable Scroll Inversion
**Source**: `deprecated/setup_osx/setup.sh`
- Function: `lgreen_onetimesetup_macos_scroll()`
- Purpose: Disable "natural" scrolling
- Command: `defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false`

### Linux-Specific Tasks (`onetimesetup_linux`)

#### 7. Nerd Font Installation
**Source**: `deprecated/setup_linux/setup.sh`
- Function: `lgreen_onetimesetup_linux_nerd_font()`
- Purpose: Install Iosevka Nerd Font for terminal icons
- Location: `~/.local/share/fonts/IosevkaNerdFont-Regular.ttf`
- Post-install: `fc-cache -fv`

#### 8. Minimap Font Installation
**Source**: `deprecated/setup_linux/setup.sh`
- Function: `lgreen_onetimesetup_linux_minimap_font()`
- Purpose: Install minimap font for code editors
- Location: `~/.local/share/fonts/Minimap.ttf`
- Post-install: `fc-cache -fv`

### WSL-Specific Tasks (`onetimesetup_wsl`)

#### 9. Set Zsh as Default Shell
**Source**: `deprecated/setup_wsl/setup.sh`
- Function: `lgreen_onetimesetup_wsl_default_shell()`
- Purpose: Set zsh as default shell in WSL
- Command: `chsh -s $(which zsh)`
- Note: May require password

---

## Implementation Structure

### Common Functions (`onetimesetup_common`)

```bash
#!/usr/bin/env sh
# Onetime setup tasks - Common across all platforms

ONETIMESETUP_MARKER="${HOME}/.dotfiles/onetimesetup.done"
ONETIMESETUP_LOG="${HOME}/.dotfiles/logs/onetimesetup-$(date +%Y%m%d-%H%M%S).log"

# =============================================================================
# Marker & Status Functions
# =============================================================================

lgreen_onetimesetup_check_done() {
    [ -f "$ONETIMESETUP_MARKER" ]
}

lgreen_onetimesetup_mark_done() {
    mkdir -p "$(dirname "$ONETIMESETUP_MARKER")"
    {
        echo "=== Onetime Setup Completion ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostname 2>/dev/null || echo 'unknown')"
        echo "User: ${USER:-$(whoami)}"
        echo "Platform: $(uname -s)"
        echo ""
        echo "Completed tasks:"
    } > "$ONETIMESETUP_MARKER"
}

lgreen_onetimesetup_record_task() {
    local task_name="$1"
    echo "  - $task_name ($(date))" >> "$ONETIMESETUP_MARKER"
}

lgreen_onetimesetup_status() {
    if lgreen_onetimesetup_check_done; then
        echo "✓ Onetime setup completed"
        echo ""
        echo "Details:"
        cat "$ONETIMESETUP_MARKER" | sed 's/^/  /'
        echo ""
        echo "To re-run: rm $ONETIMESETUP_MARKER && lgreen_onetimesetup_run_all"
        return 0
    else
        echo "⚠ Onetime setup NOT complete"
        echo ""
        echo "Run: lgreen_onetimesetup_run_all"
        echo "Or run individual tasks: lgreen_onetimesetup_<tab>"
        return 1
    fi
}

lgreen_onetimesetup_init_log() {
    mkdir -p "$(dirname "$ONETIMESETUP_LOG")"
    {
        echo "=== Onetime Setup Log ==="
        echo "Date: $(date)"
        echo "Platform: $(uname -s)"
        echo "========================="
        echo ""
    } > "$ONETIMESETUP_LOG"
}

lgreen_onetimesetup_log() {
    echo "$1" | tee -a "$ONETIMESETUP_LOG"
}

# =============================================================================
# Cross-Platform Tasks
# =============================================================================

lgreen_onetimesetup_wezterm_completions() {
    lgreen_onetimesetup_log "==> Wezterm Shell Completions"

    if ! command -v wezterm >/dev/null 2>&1; then
        lgreen_onetimesetup_log "  ⚠ wezterm not installed, skipping"
        return 0
    fi

    mkdir -p ~/.config/zsh/completions
    mkdir -p ~/.config/bash/completions

    lgreen_onetimesetup_log "  Generating completions..."
    wezterm shell-completion --shell zsh > ~/.config/zsh/completions/_wezterm
    wezterm shell-completion --shell bash > ~/.config/bash/completions/_wezterm

    lgreen_onetimesetup_log "  ✓ Completions generated"
    lgreen_onetimesetup_record_task "wezterm_completions"
}

lgreen_onetimesetup_gpg_trust() {
    lgreen_onetimesetup_log "==> GPG Key Trust Setup"

    if ! command -v gpg >/dev/null 2>&1; then
        lgreen_onetimesetup_log "  ⚠ gpg not installed, skipping"
        return 0
    fi

    # Set ultimate trust for your GPG keys
    for key_id in C1D12B816253EFFD 66C09F6FD3D4A735; do
        if gpg --list-keys "$key_id" >/dev/null 2>&1; then
            lgreen_onetimesetup_log "  Setting trust for key $key_id..."
            echo "${key_id}:6:" | gpg --import-ownertrust 2>&1 | tee -a "$ONETIMESETUP_LOG"
        fi
    done

    lgreen_onetimesetup_log "  ✓ GPG trust configured"
    lgreen_onetimesetup_record_task "gpg_trust"
}

lgreen_onetimesetup_git_remotes() {
    lgreen_onetimesetup_log "==> Git Remote URL Configuration"

    if [ ! -f ~/.ssh/config ]; then
        lgreen_onetimesetup_log "  ⚠ ~/.ssh/config not found, skipping"
        return 0
    fi

    if ! grep -q "github.com-personal\|github.com-work" ~/.ssh/config; then
        lgreen_onetimesetup_log "  ⚠ No GitHub SSH config found, skipping"
        return 0
    fi

    lgreen_onetimesetup_log "  Configure GitHub SSH host for dotfiles repo?"
    lgreen_onetimesetup_log "    1) Personal account (github.com-personal)"
    lgreen_onetimesetup_log "    2) Work account (github.com-work)"
    lgreen_onetimesetup_log "    3) Skip"
    read -r choice

    case "$choice" in
        1)
            lgreen_onetimesetup_log "  Setting remote to github.com-personal..."
            # TODO: Implement from deprecated/setup/setup.sh
            ;;
        2)
            lgreen_onetimesetup_log "  Setting remote to github.com-work..."
            # TODO: Implement from deprecated/setup/setup.sh
            ;;
        *)
            lgreen_onetimesetup_log "  Skipped"
            ;;
    esac

    lgreen_onetimesetup_record_task "git_remotes"
}

# =============================================================================
# Orchestration
# =============================================================================

lgreen_onetimesetup_run_all() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Dotfiles Onetime Setup                                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    if lgreen_onetimesetup_check_done; then
        echo "⚠ Onetime setup already completed!"
        echo ""
        lgreen_onetimesetup_status
        echo ""
        echo "To re-run, delete marker file:"
        echo "  rm $ONETIMESETUP_MARKER"
        return 0
    fi

    lgreen_onetimesetup_init_log
    lgreen_onetimesetup_log "Platform: $(uname -s)"
    lgreen_onetimesetup_log ""

    # Initialize marker
    lgreen_onetimesetup_mark_done

    # Run common tasks
    lgreen_onetimesetup_wezterm_completions
    lgreen_onetimesetup_gpg_trust
    lgreen_onetimesetup_git_remotes

    # Platform-specific tasks run from their respective files
    if command -v lgreen_onetimesetup_run_platform >/dev/null 2>&1; then
        lgreen_onetimesetup_run_platform
    fi

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Onetime Setup Complete!                                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Marker: $ONETIMESETUP_MARKER"
    echo "Log: $ONETIMESETUP_LOG"
    echo ""
}
```

### macOS Functions (`onetimesetup_osx`)

```bash
#!/usr/bin/env sh
# Onetime setup tasks - macOS specific

lgreen_onetimesetup_macos_ssh_keychain() {
    lgreen_onetimesetup_log "==> macOS SSH Keychain Integration"

    local added_count=0
    for key in ~/.ssh/id_*; do
        [[ "$key" == *.pub ]] && continue
        [[ -f "$key" ]] || continue

        lgreen_onetimesetup_log "  Adding $key to macOS Keychain..."
        if ssh-add --apple-use-keychain "$key" 2>&1 | tee -a "$ONETIMESETUP_LOG"; then
            added_count=$((added_count + 1))
        fi
    done

    lgreen_onetimesetup_log "  ✓ Added $added_count SSH keys to Keychain"
    lgreen_onetimesetup_record_task "macos_ssh_keychain"
}

lgreen_onetimesetup_macos_finder() {
    lgreen_onetimesetup_log "==> macOS Finder Configuration"

    defaults write com.apple.finder AppleShowAllFiles TRUE
    killall Finder 2>/dev/null || true

    lgreen_onetimesetup_log "  ✓ Finder configured to show hidden files"
    lgreen_onetimesetup_record_task "macos_finder"
}

lgreen_onetimesetup_macos_scroll() {
    lgreen_onetimesetup_log "==> macOS Scroll Direction"

    defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

    lgreen_onetimesetup_log "  ✓ Natural scrolling disabled"
    lgreen_onetimesetup_record_task "macos_scroll"
}

lgreen_onetimesetup_run_platform() {
    lgreen_onetimesetup_log ""
    lgreen_onetimesetup_log "Running macOS-specific tasks..."
    lgreen_onetimesetup_log ""

    lgreen_onetimesetup_macos_ssh_keychain
    lgreen_onetimesetup_macos_finder
    lgreen_onetimesetup_macos_scroll
}
```

### Linux Functions (`onetimesetup_linux`)

```bash
#!/usr/bin/env sh
# Onetime setup tasks - Linux specific

lgreen_onetimesetup_linux_nerd_font() {
    lgreen_onetimesetup_log "==> Installing Nerd Font (Iosevka)"

    mkdir -p ~/.local/share/fonts
    cd ~/.local/share/fonts || return

    if [ -f "IosevkaNerdFont-Regular.ttf" ]; then
        lgreen_onetimesetup_log "  ✓ Already installed"
        return 0
    fi

    lgreen_onetimesetup_log "  Downloading..."
    if curl -fLo "IosevkaNerdFont-Regular.ttf" \
        https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Iosevka/IosevkaNerdFont-Regular.ttf; then

        lgreen_onetimesetup_log "  Updating font cache..."
        fc-cache -fv >> "$ONETIMESETUP_LOG" 2>&1

        lgreen_onetimesetup_log "  ✓ Nerd font installed"
        lgreen_onetimesetup_record_task "linux_nerd_font"
    else
        lgreen_onetimesetup_log "  ✗ Download failed"
    fi
}

lgreen_onetimesetup_linux_minimap_font() {
    lgreen_onetimesetup_log "==> Installing Minimap Font"

    mkdir -p ~/.local/share/fonts
    cd ~/.local/share/fonts || return

    if [ -f "Minimap.ttf" ]; then
        lgreen_onetimesetup_log "  ✓ Already installed"
        return 0
    fi

    lgreen_onetimesetup_log "  Downloading..."
    if curl -fLo "Minimap.ttf" \
        https://github.com/davestewart/minimap-font/raw/master/src/Minimap.ttf; then

        lgreen_onetimesetup_log "  Updating font cache..."
        fc-cache -fv >> "$ONETIMESETUP_LOG" 2>&1

        lgreen_onetimesetup_log "  ✓ Minimap font installed"
        lgreen_onetimesetup_record_task "linux_minimap_font"
    else
        lgreen_onetimesetup_log "  ✗ Download failed"
    fi
}

lgreen_onetimesetup_run_platform() {
    lgreen_onetimesetup_log ""
    lgreen_onetimesetup_log "Running Linux-specific tasks..."
    lgreen_onetimesetup_log ""

    lgreen_onetimesetup_linux_nerd_font
    lgreen_onetimesetup_linux_minimap_font
}
```

### WSL Functions (`onetimesetup_wsl`)

```bash
#!/usr/bin/env sh
# Onetime setup tasks - WSL specific

lgreen_onetimesetup_wsl_default_shell() {
    lgreen_onetimesetup_log "==> Set Zsh as Default Shell"

    if ! command -v zsh >/dev/null 2>&1; then
        lgreen_onetimesetup_log "  ⚠ zsh not installed, skipping"
        return 0
    fi

    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    local zsh_path=$(which zsh)

    if [ "$current_shell" = "$zsh_path" ]; then
        lgreen_onetimesetup_log "  ✓ Already using zsh"
        return 0
    fi

    lgreen_onetimesetup_log "  Changing default shell to $zsh_path..."
    lgreen_onetimesetup_log "  (may require password)"

    if chsh -s "$zsh_path"; then
        lgreen_onetimesetup_log "  ✓ Default shell set to zsh"
        lgreen_onetimesetup_record_task "wsl_default_shell"
    else
        lgreen_onetimesetup_log "  ✗ Failed to change shell"
    fi
}

lgreen_onetimesetup_run_platform() {
    # Only run if actually in WSL
    if [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        return 0
    fi

    lgreen_onetimesetup_log ""
    lgreen_onetimesetup_log "Running WSL-specific tasks..."
    lgreen_onetimesetup_log ""

    lgreen_onetimesetup_wsl_default_shell
}
```

---

## Testing Plan

### Phase 1: Infrastructure (Current Linux Machine)
1. Create directory structure
2. Implement common functions
3. Test marker creation/checking
4. Add shell integration
5. Test warning on fresh shell

### Phase 2: Linux Tasks
1. Implement Linux-specific functions
2. Test font installation
3. Test `lgreen_onetimesetup_run_all`
4. Verify logging

### Phase 3: macOS Tasks (Mac Machine)
1. Deploy to macOS
2. Test platform detection
3. Implement macOS SSH keychain
4. Test Finder/scroll configs

### Phase 4: Logs Migration
1. Move existing logs to `~/.dotfiles/logs/`
2. Update `bootstrap.sh`
3. Update `.gitignore`
4. Archive old `logs/` directory

---

## .gitignore Updates

```gitignore
# Logs moved to ~/.dotfiles/
logs/

# State directory (machine-specific)
.dotfiles/
```

---

## Future Enhancements

1. **Task-level markers**: Track individual tasks for partial re-runs
2. **Interactive mode**: Menu-driven task selection
3. **Dry-run mode**: Preview without executing
4. **Health check integration**: `lgreen_checkhealth_onetimesetup`
5. **Windows/MSYS2 support**: When needed

---

## Notes on Excluded Tasks

Tasks from deprecated scripts NOT included (and why):

1. **TCC Database Reset** (macOS): Too destructive, manual only
2. **Divvy Scheduled Task** (Windows): App-specific, not dotfiles
3. **WSL SSH Forwarding** (Windows): Complex networking, manual only
4. **Office Key Fix** (Windows): External project
5. **Clink Plugins** (Windows): Prefer manual clone

Document these separately if needed.
