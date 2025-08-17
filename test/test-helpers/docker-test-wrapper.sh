#!/usr/bin/env bash
# Wrapper script for Docker tests with automatic log extraction and summary

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR_ROOT/.." && pwd)"
TEST_LOGS_DIR="${TEST_DIR_ROOT}/test-logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Parse arguments
MACHINE_CLASS="${1:-docker_developer_arch}"
PLATFORM="${2:-arch}"
TEST_NAME="${MACHINE_CLASS}_${TIMESTAMP}"
TEST_DIR="${TEST_LOGS_DIR}/${TEST_NAME}"

print_color "$BLUE" "🧪 Docker Test Wrapper"
print_color "$BLUE" "====================="
print_color "$BLUE" "Machine Class: $MACHINE_CLASS"
print_color "$BLUE" "Platform: $PLATFORM"
print_color "$BLUE" "Test Directory: $TEST_DIR"
echo ""

# Create test directory
mkdir -p "$TEST_DIR"

# Step 1: Run the actual test
print_color "$YELLOW" "📦 Step 1: Running Docker test..."
TEST_OUTPUT="${TEST_DIR}/docker-build-output.log"
if cd "$TEST_DIR_ROOT" && just _test-machine-class "$MACHINE_CLASS" "$PLATFORM" 2>&1 | tee "$TEST_OUTPUT"; then
    BUILD_SUCCESS=true
    print_color "$GREEN" "✅ Docker build succeeded"
else
    BUILD_SUCCESS=false
    print_color "$RED" "❌ Docker build failed"
fi

# Step 2: Extract logs from container
print_color "$YELLOW" "📋 Step 2: Extracting logs from container..."
IMAGE_NAME="dotfiles-test-${MACHINE_CLASS}"
CONTAINER_ID=$(docker create "$IMAGE_NAME" 2>/dev/null || echo "")

if [[ -n "$CONTAINER_ID" ]]; then
    # Extract logs directory
    if docker cp "$CONTAINER_ID:/home/user/dotfiles/logs" "$TEST_DIR/" 2>/dev/null; then
        print_color "$GREEN" "✅ Logs extracted successfully"
    else
        print_color "$YELLOW" "⚠️  No logs directory found in container"
    fi
    
    # Extract machine class configs
    if docker cp "$CONTAINER_ID:/home/user/dotfiles/machine-classes/${MACHINE_CLASS}" "$TEST_DIR/machine-class-config" 2>/dev/null; then
        print_color "$GREEN" "✅ Machine class config extracted"
    else
        print_color "$YELLOW" "⚠️  Machine class config not found"
    fi
    
    # Clean up container
    docker rm "$CONTAINER_ID" > /dev/null
else
    print_color "$RED" "❌ Could not create container for log extraction"
fi

# Step 3: Generate summary report
print_color "$YELLOW" "📊 Step 3: Generating summary report..."
SUMMARY_FILE="${TEST_DIR}/test-summary.md"
"${SCRIPT_DIR}/generate-test-summary.sh" "$TEST_DIR" "$MACHINE_CLASS" "$PLATFORM" "$BUILD_SUCCESS" > "$SUMMARY_FILE"

# Step 4: Display summary
print_color "$BLUE" ""
print_color "$BLUE" "📊 Test Summary"
print_color "$BLUE" "==============="
cat "$SUMMARY_FILE"

# Save test metadata
cat > "${TEST_DIR}/test-metadata.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "machine_class": "$MACHINE_CLASS",
  "platform": "$PLATFORM",
  "build_success": $BUILD_SUCCESS,
  "test_directory": "$TEST_DIR",
  "image_name": "$IMAGE_NAME"
}
EOF

print_color "$BLUE" ""
print_color "$BLUE" "📁 All test artifacts saved to: $TEST_DIR"
print_color "$BLUE" "📄 View full summary: cat $SUMMARY_FILE"
print_color "$BLUE" "📋 View specific log: ls -la $TEST_DIR/logs/"

# Exit with appropriate code
if [[ "$BUILD_SUCCESS" == "true" ]]; then
    exit 0
else
    exit 1
fi