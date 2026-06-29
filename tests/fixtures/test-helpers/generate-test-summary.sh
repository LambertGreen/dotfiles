#!/usr/bin/env bash
# Generate a comprehensive test summary report

set -euo pipefail

# Arguments
TEST_DIR="${1:-}"
MACHINE_CLASS="${2:-unknown}"
PLATFORM="${3:-unknown}"
BUILD_SUCCESS="${4:-false}"

if [[ -z "$TEST_DIR" ]]; then
    echo "Usage: $0 <test-directory> [machine-class] [platform] [build-success]"
    exit 1
fi

# Helper functions
count_lines() {
    local file=$1
    if [[ -f "$file" ]]; then
        wc -l < "$file" | tr -d ' '
    else
        echo "0"
    fi
}

extract_value() {
    local file=$1
    local pattern=$2
    if [[ -f "$file" ]]; then
        grep -E "$pattern" "$file" 2>/dev/null | head -1 || echo ""
    else
        echo ""
    fi
}

# Print the most recently modified file matching the given glob(s), or nothing.
# Args are the glob-expanded paths; an unmatched glob arrives as a literal and
# is skipped by the -f test, so this is safe without nullglob.
newest_log() {
    local newest="" f
    for f in "$@"; do
        [[ -f "$f" ]] || continue
        if [[ -z "$newest" || "$f" -nt "$newest" ]]; then
            newest="$f"
        fi
    done
    [[ -n "$newest" ]] && printf '%s\n' "$newest"
    return 0  # never fail: an empty result is valid (caller checks with -n)
}

# Generate report
cat <<EOF
# Docker Test Summary Report

**Test Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Machine Class:** $MACHINE_CLASS
**Platform:** $PLATFORM
**Build Status:** $(if [[ "$BUILD_SUCCESS" == "true" ]]; then echo "✅ SUCCESS"; else echo "❌ FAILED"; fi)
**Test Duration:** $(if [[ -f "$TEST_DIR/docker-build-output.log" ]]; then stat -f %Sm -t '%H:%M:%S' "$TEST_DIR/docker-build-output.log" 2>/dev/null || echo 'unknown'; else echo "unknown"; fi)

---

## 📊 Package Installation Summary

### Dev Package Verification

EOF

# Extract initialization timing if available
INIT_LOG=$(newest_log "$TEST_DIR/logs/init-dev-packages"*.log)
if [[ -n "$INIT_LOG" ]]; then
    # Extract initialization timing
    EMACS_INIT_TIME=$(extract_value "$INIT_LOG" "Emacs.*completed.*\([0-9]+s\)" | grep -oE '\([0-9]+s\)' | tr -d '()' || echo "")
    NVIM_INIT_TIME=$(extract_value "$INIT_LOG" "Neovim.*completed.*\([0-9]+s\)" | grep -oE '\([0-9]+s\)' | tr -d '()' || echo "")
    ZSH_INIT_TIME=$(extract_value "$INIT_LOG" "Zsh.*completed.*\([0-9]+s\)" | grep -oE '\([0-9]+s\)' | tr -d '()' || echo "")
fi

# Check for package installation results
VERIFY_LOG=$(newest_log "$TEST_DIR/logs/verify-dev-package-install"*.log)
if [[ -n "$VERIFY_LOG" ]]; then
    # Extract verification results
    EMACS_RESULT=$(extract_value "$VERIFY_LOG" "Emacs:.*packages")
    NEOVIM_RESULT=$(extract_value "$VERIFY_LOG" "Neovim:.*plugins")
    ZSH_RESULT=$(extract_value "$VERIFY_LOG" "Zsh:.*")

    echo "| Package Manager | Status | Details | Init Time | Verify Time |"
    echo "|-----------------|--------|---------|-----------|-------------|"

    if [[ -n "$EMACS_RESULT" ]]; then
        if echo "$EMACS_RESULT" | grep -q "✅"; then
            EMACS_COUNT=$(echo "$EMACS_RESULT" | grep -oE '[0-9]+' | head -1)
            EMACS_VERIFY_TIME=$(echo "$EMACS_RESULT" | grep -oE '\([^)]*[0-9]+s[^)]*\)' | tr -d '()' || echo "")
            echo "| **Emacs (elpaca)** | ✅ | $EMACS_COUNT packages | ${EMACS_INIT_TIME:-n/a} | ${EMACS_VERIFY_TIME:-n/a} |"
        else
            echo "| **Emacs (elpaca)** | ❌ | Installation failed | ${EMACS_INIT_TIME:-n/a} | n/a |"
        fi
    fi

    if [[ -n "$NEOVIM_RESULT" ]]; then
        if echo "$NEOVIM_RESULT" | grep -q "✅"; then
            NVIM_COUNT=$(echo "$NEOVIM_RESULT" | grep -oE '[0-9]+' | head -1)
            NVIM_VERIFY_TIME=$(echo "$NEOVIM_RESULT" | grep -oE '\([^)]*[0-9]+s[^)]*\)' | tr -d '()' || echo "")
            echo "| **Neovim (lazy)** | ✅ | $NVIM_COUNT plugins | ${NVIM_INIT_TIME:-n/a} | ${NVIM_VERIFY_TIME:-n/a} |"
        else
            echo "| **Neovim (lazy)** | ❌ | Installation failed | ${NVIM_INIT_TIME:-n/a} | n/a |"
        fi
    fi

    if [[ -n "$ZSH_RESULT" ]]; then
        if echo "$ZSH_RESULT" | grep -q "✅"; then
            ZSH_COUNT=$(echo "$ZSH_RESULT" | grep -oE '[0-9]+' | head -1)
            ZSH_VERIFY_TIME=$(echo "$ZSH_RESULT" | grep -oE '\([^)]*[0-9]+s[^)]*\)' | tr -d '()' || echo "")
            echo "| **Zsh (zinit)** | ✅ | $ZSH_COUNT plugins | ${ZSH_INIT_TIME:-n/a} | ${ZSH_VERIFY_TIME:-n/a} |"
        else
            echo "| **Zsh (zinit)** | ❌ | Verification failed | ${ZSH_INIT_TIME:-n/a} | n/a |"
        fi
    fi
    echo ""
else
    echo "*No dev package verification log found*"
    echo ""
fi

# System package summary
echo "### System Packages"
echo ""

if [[ -d "$TEST_DIR/machine-class-config" ]]; then
    echo "| Package Manager | Count |"
    echo "|-----------------|-------|"

    for pm_dir in "$TEST_DIR/machine-class-config"/*; do
        if [[ -d "$pm_dir" ]]; then
            PM_NAME=$(basename "$pm_dir")
            case "$PM_NAME" in
                pacman|apt)
                    if [[ -f "$pm_dir/packages.txt" ]]; then
                        COUNT=$(grep -cvE '^#|^$' "$pm_dir/packages.txt" 2>/dev/null || true)
                        echo "| **$PM_NAME** | $COUNT |"
                    fi
                    ;;
                npm)
                    if [[ -f "$pm_dir/packages.txt" ]]; then
                        COUNT=$(grep -cvE '^#|^$' "$pm_dir/packages.txt" 2>/dev/null || true)
                        echo "| **npm** | $COUNT |"
                    fi
                    ;;
                pip)
                    if [[ -f "$pm_dir/requirements.txt" ]]; then
                        COUNT=$(grep -cvE '^#|^$' "$pm_dir/requirements.txt" 2>/dev/null || true)
                        echo "| **pip** | $COUNT |"
                    fi
                    ;;
            esac
        fi
    done
    echo ""
fi

# Health check results
echo "## 🏥 Health Check Results"
echo ""

HEALTH_LOG=$(newest_log "$TEST_DIR/logs/health-check"*.log)
if [[ -n "$HEALTH_LOG" ]]; then
    # Extract health status
    HEALTH_STATUS=$(extract_value "$HEALTH_LOG" "Status:.*")
    if [[ -n "$HEALTH_STATUS" ]]; then
        echo "$HEALTH_STATUS"
    else
        echo "Status: ⚠️ Unknown"
    fi
    echo ""

    # Extract symlink info
    SYMLINK_INFO=$(grep -A 3 "Configuration Statistics" "$HEALTH_LOG" 2>/dev/null || echo "")
    if [[ -n "$SYMLINK_INFO" ]]; then
        echo "### Symlink Status"
        echo '```'
        echo "$SYMLINK_INFO"
        echo '```'
        echo ""
    fi
fi

# Known issues
echo "## ⚠️ Known Issues & Warnings"
echo ""

ISSUES_FOUND=false
EMACS_COUNT="${EMACS_COUNT:-0}"
ZSH_RESULT="${ZSH_RESULT:-}"

# Check for emacs package count issue
if [[ "$EMACS_COUNT" -gt 0 ]] && [[ "$EMACS_COUNT" -lt 50 ]]; then
    echo "- **Emacs**: Only $EMACS_COUNT packages installed (expected ~200)"
    ISSUES_FOUND=true
fi

# Check for zsh timeout
if echo "$ZSH_RESULT" | grep -q "timeout\|Failed"; then
    echo "- **Zsh**: Plugin verification timed out (plugins may still be installed)"
    ISSUES_FOUND=true
fi

# Check Docker build warnings
if [[ -f "$TEST_DIR/docker-build-output.log" ]]; then
    if grep -q "warning:" "$TEST_DIR/docker-build-output.log"; then
        WARNING_COUNT=$(grep -c "warning:" "$TEST_DIR/docker-build-output.log")
        echo "- **Docker Build**: $WARNING_COUNT warnings found"
        ISSUES_FOUND=true
    fi
fi

if [[ "$ISSUES_FOUND" == "false" ]]; then
    echo "*No issues detected*"
fi
echo ""

# Log files
echo "## 📁 Available Logs"
echo ""

echo "### Primary Logs"
echo '```'
if [[ -d "$TEST_DIR/logs" ]]; then
    for logfile in "$TEST_DIR/logs"/*.log; do
        if [[ -f "$logfile" ]]; then
            BASENAME=$(basename "$logfile")
            SIZE=$(du -h "$logfile" | cut -f1)
            echo "- $BASENAME ($SIZE)"
        fi
    done
else
    echo "No logs directory found"
fi
echo '```'
echo ""

echo "### Docker Output"
if [[ -f "$TEST_DIR/docker-build-output.log" ]]; then
    SIZE=$(du -h "$TEST_DIR/docker-build-output.log" | cut -f1)
    LINES=$(wc -l < "$TEST_DIR/docker-build-output.log" | tr -d ' ')
    echo "- docker-build-output.log ($SIZE, $LINES lines)"
else
    echo "- No Docker output captured"
fi
echo ""

# Test execution details
echo "## 🔧 Test Execution Details"
echo ""
echo '```yaml'
echo "test_directory: $TEST_DIR"
echo "machine_class: $MACHINE_CLASS"
echo "platform: $PLATFORM"
echo "timestamp: $(basename "$TEST_DIR" | grep -oE '[0-9]{8}-[0-9]{6}' || echo 'unknown')"
echo "image_name: dotfiles-test-${MACHINE_CLASS}"
echo '```'
echo ""

# Recommendations
echo "## 💡 Next Steps"
echo ""

if [[ "$BUILD_SUCCESS" == "false" ]]; then
    echo "1. Review Docker build output: \`cat $TEST_DIR/docker-build-output.log | grep -A 5 -B 5 error\`"
elif [[ "$EMACS_COUNT" -lt 50 ]]; then
    echo "1. Investigate emacs package installation: \`grep -A 20 'Initializing Emacs' $TEST_DIR/logs/init-dev-packages*.log\`"
elif echo "$ZSH_RESULT" | grep -q "Failed"; then
    echo "1. Check zsh plugin installation: \`grep -A 20 'Initializing Zsh' $TEST_DIR/logs/init-dev-packages*.log\`"
else
    echo "1. All systems operational - no immediate action required"
fi

echo "2. View detailed logs: \`ls -la $TEST_DIR/logs/\`"
echo "3. Compare with previous test: \`diff -u .logs/*/test-summary.md | head -50\`"
echo ""

echo "---"
echo "*Generated by generate-test-summary.sh at $(date '+%Y-%m-%d %H:%M:%S')*"
