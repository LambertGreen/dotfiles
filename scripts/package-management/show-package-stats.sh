#!/usr/bin/env bash
# Show packages configured for current machine class

set -euo pipefail

MACHINE_CLASS_ENV="${HOME}/.dotfiles.env"
PACKAGE_MANAGEMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/package-management"
MACHINES_DIR="${PACKAGE_MANAGEMENT_DIR}/machines"

# Load configuration
if [[ ! -f "${MACHINE_CLASS_ENV}" ]]; then
    echo "❌ Configuration not found. Run: just configure" >&2
    exit 1
fi

source "${MACHINE_CLASS_ENV}"

if [[ -z "${DOTFILES_MACHINE_CLASS:-}" ]]; then
    echo "❌ DOTFILES_MACHINE_CLASS not set. Run: just configure" >&2
    exit 1
fi

MACHINE_DIR="${MACHINES_DIR}/${DOTFILES_MACHINE_CLASS}"

if [[ ! -d "${MACHINE_DIR}" ]]; then
    echo "❌ Machine class directory not found: ${MACHINE_DIR}" >&2
    exit 1
fi

echo "📦 Packages for machine class: ${DOTFILES_MACHINE_CLASS}"
echo ""

# Count total packages across all package managers
total_packages=0

# Check each package manager
for pm_dir in "${MACHINE_DIR}"/*; do
    if [[ -d "${pm_dir}" ]]; then
        pm_name=$(basename "${pm_dir}")
        
        case "${pm_name}" in
            brew)
                if [[ -f "${pm_dir}/Brewfile" ]]; then
                    formulae=$(grep -c '^brew ' "${pm_dir}/Brewfile" 2>/dev/null || echo 0)
                    casks=$(grep -c '^cask ' "${pm_dir}/Brewfile" 2>/dev/null || echo 0)
                    mas=$(grep -c '^mas ' "${pm_dir}/Brewfile" 2>/dev/null || echo 0)
                    taps=$(grep -c '^tap ' "${pm_dir}/Brewfile" 2>/dev/null || echo 0)
                    echo "🍺 Homebrew: ${formulae} formulae, ${casks} casks, ${mas} Mac App Store, ${taps} taps"
                    total_packages=$((total_packages + formulae + casks + mas))
                fi
                ;;
            pip)
                if [[ -f "${pm_dir}/requirements.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/requirements.txt" 2>/dev/null || echo 0)
                    echo "🐍 Python (pip): ${count} packages"
                    total_packages=$((total_packages + count))
                fi
                ;;
            npm)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo 0)
                    echo "📦 NPM: ${count} global packages"
                    total_packages=$((total_packages + count))
                fi
                ;;
            apt)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo 0)
                    echo "📦 APT: ${count} packages"
                    total_packages=$((total_packages + count))
                fi
                ;;
            pacman)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo 0)
                    echo "📦 Pacman: ${count} packages"
                    total_packages=$((total_packages + count))
                fi
                ;;
            cargo)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo 0)
                    echo "🦀 Cargo: ${count} packages"
                    total_packages=$((total_packages + count))
                fi
                ;;
            gem)
                if [[ -f "${pm_dir}/Gemfile" ]]; then
                    count=$(grep -c '^gem ' "${pm_dir}/Gemfile" 2>/dev/null || echo 0)
                    echo "💎 RubyGems: ${count} gems"
                    total_packages=$((total_packages + count))
                fi
                ;;
            scoop)
                if [[ -f "${pm_dir}/scoopfile.json" ]]; then
                    echo "🪣 Scoop: configuration file present"
                fi
                ;;
            choco)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo 0)
                    echo "🍫 Chocolatey: ${count} packages"
                    total_packages=$((total_packages + count))
                fi
                ;;
        esac
    fi
done

echo ""
echo "📊 Total: ${total_packages} packages across all package managers"
echo ""
echo "💡 To view package details:"
echo "  just shell-into-package-manager-hub  # Enter package manager hub"
echo "  cd package-management/machines/${DOTFILES_MACHINE_CLASS}  # View raw files"