# Development and testing workflows

# Default test platform
test_platform := env_var_or_default("DOTFILES_TEST_PLATFORM", "arch")

# Show dev help
@dev-help:
    echo "🛠️  Development & Testing"
    echo ""
    echo "Testing (Docker):"
    echo "  just dev test [platform]     - Test with Docker"
    echo "  just dev test-all           - Test all platforms"
    echo "  just dev test-local [platform] - Test with local files"
    echo ""
    echo "Development:"
    echo "  just dev status             - Show git status"
    echo "  just dev update             - Update submodules"
    echo "  just dev validate           - Run all validations"
    echo ""
    echo "Docker platforms: {{docker_platforms}}"
    echo "Default: {{test_platform}}"

# Quick test with Docker
@dev-test platform=test_platform:
    echo "🐳 Testing {{platform}} with Docker..."
    just dev-test-local {{platform}}

# Test with local files (faster iteration)
dev-test-local platform:
    docker build -f dockerfiles/Dockerfile.{{platform}}.local \
        -t dotfiles-test-{{platform}} .
    docker run -it --rm dotfiles-test-{{platform}}

# Test with GitHub (full integration test)
dev-test-remote platform:
    #!/usr/bin/env bash
    source .env
    docker build \
        --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} \
        --build-arg CACHE_BUST=$(date +%s) \
        -f dockerfiles/Dockerfile.{{platform}} \
        -t dotfiles-test-{{platform}} .
    docker run -it --rm dotfiles-test-{{platform}}

# Test all Docker platforms
@dev-test-all:
    #!/usr/bin/env bash
    for platform in {{docker_platforms}}; do
        echo "━━━ Testing $platform ━━━"
        just dev-test-local $platform
    done

# Show development status
@dev-status:
    echo "📊 Repository Status"
    echo "━━━━━━━━━━━━━━━━━━━━"
    git status --short
    echo ""
    echo "📦 Submodules:"
    git submodule status

# Update submodules
dev-update:
    git submodule update --init --recursive

# Validate everything
@dev-validate:
    echo "🔍 Running validations..."
    just dev-test-all
    echo "✅ All validations passed"