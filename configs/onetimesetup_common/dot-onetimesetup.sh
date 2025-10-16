#!/usr/bin/env sh
# Onetime setup tasks - Common across all platforms
#
# Usage:
#   source ~/.onetimesetup.sh
#   lgreen_onetimesetup_run_all              # Run all tasks
#   lgreen_onetimesetup_status               # Check completion status
#   LGREEN_ONETIMESETUP_DRYRUN=1 lgreen_onetimesetup_run_all  # Dry-run mode
#
# Test hook for brother instances:
#   lgreen_onetimesetup_test                 # Run all with dry-run

# =============================================================================
# Configuration
# =============================================================================

ONETIMESETUP_MARKER="${HOME}/.dotfiles/onetimesetup.done"
ONETIMESETUP_LOG="${HOME}/.dotfiles/logs/onetimesetup-$(date +%Y%m%d-%H%M%S).log"

# Dry-run mode: set LGREEN_ONETIMESETUP_DRYRUN=1 to test without executing
_onetimesetup_is_dryrun() {
    [ "${LGREEN_ONETIMESETUP_DRYRUN:-0}" = "1" ]
}

# =============================================================================
# Marker & Status Functions
# =============================================================================

lgreen_onetimesetup_check_done() {
    [ -f "$ONETIMESETUP_MARKER" ]
}

lgreen_onetimesetup_mark_done() {
    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "DRYRUN: Would create marker file: $ONETIMESETUP_MARKER"
        return 0
    fi

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
    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "DRYRUN: Would record task: $task_name"
        return 0
    fi
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
        echo ""
        echo "Test mode: LGREEN_ONETIMESETUP_DRYRUN=1 lgreen_onetimesetup_run_all"
        return 1
    fi
}

# =============================================================================
# Logging Functions
# =============================================================================

_onetimesetup_init_log() {
    if _onetimesetup_is_dryrun; then
        return 0
    fi

    mkdir -p "$(dirname "$ONETIMESETUP_LOG")"
    {
        echo "=== Onetime Setup Log ==="
        echo "Date: $(date)"
        echo "Platform: $(uname -s)"
        echo "Dry-run: ${LGREEN_ONETIMESETUP_DRYRUN:-0}"
        echo "========================="
        echo ""
    } > "$ONETIMESETUP_LOG"
}

_onetimesetup_log() {
    local msg="$1"
    echo "$msg"
    if ! _onetimesetup_is_dryrun; then
        echo "$msg" >> "$ONETIMESETUP_LOG"
    fi
}

# =============================================================================
# Cross-Platform Tasks
# =============================================================================

lgreen_onetimesetup_wezterm_completions() {
    _onetimesetup_log "==> Wezterm Shell Completions"

    if ! command -v wezterm >/dev/null 2>&1; then
        _onetimesetup_log "  ⚠ wezterm not installed, skipping"
        return 0
    fi

    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "  DRYRUN: Would create ~/.config/zsh/completions/_wezterm"
        _onetimesetup_log "  DRYRUN: Would create ~/.config/bash/completions/_wezterm"
        lgreen_onetimesetup_record_task "wezterm_completions"
        return 0
    fi

    mkdir -p ~/.config/zsh/completions
    mkdir -p ~/.config/bash/completions

    _onetimesetup_log "  Generating completions..."
    if wezterm shell-completion --shell zsh > ~/.config/zsh/completions/_wezterm && \
       wezterm shell-completion --shell bash > ~/.config/bash/completions/_wezterm; then
        _onetimesetup_log "  ✓ Completions generated"
        lgreen_onetimesetup_record_task "wezterm_completions"
    else
        _onetimesetup_log "  ✗ Failed to generate completions"
    fi
}

lgreen_onetimesetup_gpg_trust() {
    _onetimesetup_log "==> GPG Key Trust Setup"

    if ! command -v gpg >/dev/null 2>&1; then
        _onetimesetup_log "  ⚠ gpg not installed, skipping"
        return 0
    fi

    # Hardcoded personal GPG keys
    local keys="C1D12B816253EFFD 66C09F6FD3D4A735"

    for key_id in $keys; do
        if ! gpg --list-keys "$key_id" >/dev/null 2>&1; then
            _onetimesetup_log "  ⚠ Key $key_id not found in keyring, skipping"
            continue
        fi

        if _onetimesetup_is_dryrun; then
            _onetimesetup_log "  DRYRUN: Would set ultimate trust for key $key_id"
        else
            _onetimesetup_log "  Setting ultimate trust for key $key_id..."
            echo "${key_id}:6:" | gpg --import-ownertrust 2>&1 | grep -v "already in trustdb" || true
        fi
    done

    _onetimesetup_log "  ✓ GPG trust configured"
    lgreen_onetimesetup_record_task "gpg_trust"
}

lgreen_onetimesetup_git_remotes() {
    _onetimesetup_log "==> Git Remote URL Configuration"

    if [ ! -f ~/.ssh/config ]; then
        _onetimesetup_log "  ⚠ ~/.ssh/config not found, skipping"
        return 0
    fi

    if ! grep -q "github.com-personal\|github.com-work" ~/.ssh/config; then
        _onetimesetup_log "  ⚠ No GitHub SSH config found in ~/.ssh/config, skipping"
        return 0
    fi

    _onetimesetup_log "  Configure GitHub SSH host for dotfiles repo?"
    _onetimesetup_log "    1) Personal account (github.com-personal)"
    _onetimesetup_log "    2) Work account (github.com-work)"
    _onetimesetup_log "    3) Skip"

    if _onetimesetup_is_dryrun; then
        _onetimesetup_log "  DRYRUN: Would prompt for choice and update git remote"
        lgreen_onetimesetup_record_task "git_remotes"
        return 0
    fi

    read -r choice
    case "$choice" in
        1)
            _onetimesetup_log "  TODO: Implement personal remote update"
            # TODO: Port from deprecated/setup/setup.sh
            ;;
        2)
            _onetimesetup_log "  TODO: Implement work remote update"
            # TODO: Port from deprecated/setup/setup.sh
            ;;
        *)
            _onetimesetup_log "  Skipped"
            ;;
    esac

    lgreen_onetimesetup_record_task "git_remotes"
}

# =============================================================================
# Orchestration
# =============================================================================

lgreen_onetimesetup_run_all() {
    if _onetimesetup_is_dryrun; then
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  Dotfiles Onetime Setup (DRY-RUN MODE)                    ║"
        echo "╚════════════════════════════════════════════════════════════╝"
    else
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  Dotfiles Onetime Setup                                    ║"
        echo "╚════════════════════════════════════════════════════════════╝"
    fi
    echo ""

    if lgreen_onetimesetup_check_done && ! _onetimesetup_is_dryrun; then
        echo "⚠ Onetime setup already completed!"
        echo ""
        lgreen_onetimesetup_status
        echo ""
        echo "To re-run, delete marker file:"
        echo "  rm $ONETIMESETUP_MARKER"
        return 0
    fi

    _onetimesetup_init_log
    _onetimesetup_log "Platform: $(uname -s)"
    _onetimesetup_log ""

    # Initialize marker
    lgreen_onetimesetup_mark_done

    # Run common tasks
    lgreen_onetimesetup_wezterm_completions
    lgreen_onetimesetup_gpg_trust
    lgreen_onetimesetup_git_remotes

    # Platform-specific tasks run from their respective files
    if command -v lgreen_onetimesetup_run_platform >/dev/null 2>&1; then
        _onetimesetup_log ""
        _onetimesetup_log "Running platform-specific tasks..."
        _onetimesetup_log ""
        lgreen_onetimesetup_run_platform
    fi

    echo ""
    if _onetimesetup_is_dryrun; then
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  ✅ Onetime Setup Dry-Run Complete!                        ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "No changes were made. To run for real:"
        echo "  lgreen_onetimesetup_run_all"
    else
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  ✅ Onetime Setup Complete!                                ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Marker: $ONETIMESETUP_MARKER"
        echo "Log: $ONETIMESETUP_LOG"
    fi
    echo ""
}

# =============================================================================
# Test Hook for Brother Instances
# =============================================================================

lgreen_onetimesetup_test() {
    echo "Running onetime setup in dry-run mode..."
    echo ""
    LGREEN_ONETIMESETUP_DRYRUN=1 lgreen_onetimesetup_run_all
}
