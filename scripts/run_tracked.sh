#!/usr/bin/env bash
# Run a command with tracking, logging, and clean output

OPERATION="$1"
COMMAND="$2"
LOG_FILE="$3"
STATUS_FILE="$4"
AUTO_CLOSE="${5:-false}"

# Ensure brew is in PATH (common locations)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Clear for clean start
clear

# Header
echo "🚀 $OPERATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
