#!/usr/bin/env bash
# Run a command with tracking, logging, and clean output

OPERATION="$1"
COMMAND="$2"
LOG_FILE="$3"
STATUS_FILE="$4"
AUTO_CLOSE="${5:-false}"

# === Environment Setup ===
# Source user's shell environment for PATH without loading interactive configs
# Priority: zsh (if available) → bash (fallback)

if command -v zsh >/dev/null 2>&1; then
    # Zsh available: Source .zshenv + .zprofile (PATH setup, no interactive bloat)
    eval "$(zsh -c '
        [[ -f ~/.zshenv ]] && source ~/.zshenv
        [[ -f ~/.zprofile ]] && source ~/.zprofile
        # Export only environment variables with proper quoting
        env | grep -E "^(PATH|HOMEBREW|GEM_HOME|PIPX|LANG|LC_|LD_LIBRARY_PATH|PKG_CONFIG_PATH|CPATH|COMPILER_PATH|LIBRARY_PATH)=" | while IFS= read -r line; do
            # Split into name and value, then export with proper quoting
            name="${line%%=*}"
            value="${line#*=}"
            printf "export %s=%q\n" "$name" "$value"
        done
    ')"
else
    # Bash fallback: Source .bash_profile (which sources .profile_{platform})
    [ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile"
fi

# Clear for clean start
clear

# Header
echo "🚀 $OPERATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💻 Command: $COMMAND"
echo ""

# Write starting status
echo "{\"status\": \"running\", \"timestamp\": $(date +%s), \"operation\": \"$OPERATION\"}" > "$STATUS_FILE"

# Run command with tee to capture output
eval "$COMMAND" 2>&1 | tee "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}

# Write completion status
echo "{\"status\": \"completed\", \"exit_code\": $EXIT_CODE, \"timestamp\": $(date +%s), \"operation\": \"$OPERATION\"}" > "$STATUS_FILE"

# Footer
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ $OPERATION completed successfully"
    if [ "$AUTO_CLOSE" = "true" ]; then
        # Quick operations - no need to wait
        sleep 1
    else
        echo ""
        echo "🖥️  Terminal ready for closure via automation"
        # Terminal will be closed by automation - no sleep needed
    fi
else
    echo "❌ $OPERATION failed (exit code: $EXIT_CODE)"
    echo ""
    echo "📄 Log saved to: $LOG_FILE"
    echo ""
    echo "🖥️  Terminal ready for closure via automation"
    # Terminal will be closed by automation - no sleep needed
fi
