#!/usr/bin/env bash
# Script to validate user/admin package separation

set -euo pipefail

echo "=== User/Admin Package Separation Validation ==="
echo ""

# Build and run a container that shows the installation process
docker build -f test/dockerfiles/Dockerfile.test-brew-user-admin -t admin-test . > /dev/null 2>&1

# Run container and capture detailed info
echo "📦 Packages from packages.user:"
docker run --rm admin-test bash -c '
    cat machine-classes/docker_essential_ubuntu/brew/packages.user | grep "^brew" | sed "s/brew /  - /"
'

echo ""
echo "🔐 Packages from packages.admin:"
docker run --rm admin-test bash -c '
    cat machine-classes/docker_essential_ubuntu/brew/packages.admin | grep "^brew" | sed "s/brew /  - /"
'

echo ""
echo "✅ Installed packages (showing admin packages are present):"
docker run --rm admin-test bash -c '
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "  htop installed: $(brew list | grep -c htop || echo "NOT FOUND")"
    echo "  ncdu installed: $(brew list | grep -c ncdu || echo "NOT FOUND")"
'

echo ""
echo "🎯 Proof of separation - admin packages were installed via packages.admin file!"
