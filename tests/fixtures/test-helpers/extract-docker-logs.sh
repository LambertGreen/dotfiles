#!/usr/bin/env bash
# Extract logs from Docker test containers

set -euo pipefail

IMAGE_NAME="${1:-dotfiles-test-docker_developer_arch}"
OUTPUT_DIR="${2:-./docker-extracted-logs}"

echo "📁 Extracting logs from Docker image: $IMAGE_NAME"
echo "📂 Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run container and copy logs
echo "🚀 Starting temporary container..."
CONTAINER_ID=$(docker create "$IMAGE_NAME")

echo "📋 Copying logs..."
docker cp "$CONTAINER_ID:/home/user/dotfiles/logs" "$OUTPUT_DIR/" 2>/dev/null || {
    echo "❌ No logs directory found in container"
}

# Also try to get the test results
echo "📊 Extracting test results..."
docker run --rm "$IMAGE_NAME" bash -c 'just show-package-stats 2>/dev/null || true' > "$OUTPUT_DIR/package-stats.txt" 2>&1

# Clean up
echo "🧹 Cleaning up container..."
docker rm "$CONTAINER_ID" > /dev/null

echo "✅ Logs extracted to: $OUTPUT_DIR"
echo ""
echo "📄 Available logs:"
ls -la "$OUTPUT_DIR/logs/" 2>/dev/null | tail -n +2 || echo "No logs found"

echo ""
echo "💡 To view a specific log:"
echo "  cat $OUTPUT_DIR/logs/<logfile>"