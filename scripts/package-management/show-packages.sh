#!/usr/bin/env bash
# Show actual package lists for current machine class

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
echo "==============================================="
echo ""

# Show each package manager's packages
for pm_dir in "${MACHINE_DIR}"/*; do
    if [[ -d "${pm_dir}" ]]; then
        pm_name=$(basename "${pm_dir}")
        
        case "${pm_name}" in
            brew)
                if [[ -f "${pm_dir}/Brewfile" ]]; then
                    echo "🍺 Homebrew (Brewfile):"
                    echo "--------------------"
                    cat "${pm_dir}/Brewfile"
                    echo ""
                fi
                ;;
            pip)
                if [[ -f "${pm_dir}/requirements.txt" ]]; then
                    echo "🐍 Python (pip) packages:"
                    echo "------------------------"
                    cat "${pm_dir}/requirements.txt"
                    echo ""
                fi
                ;;
            npm)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    echo "📦 NPM global packages:"
                    echo "----------------------"
                    cat "${pm_dir}/packages.txt"
                    echo ""
                fi
                ;;
            apt)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    echo "📦 APT packages:"
                    echo "---------------"
                    cat "${pm_dir}/packages.txt"
                    echo ""
                fi
                ;;
            pacman)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    echo "📦 Pacman packages:"
                    echo "------------------"
                    cat "${pm_dir}/packages.txt"
                    echo ""
                fi
                ;;
            cargo)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    echo "🦀 Cargo packages:"
                    echo "-----------------"
                    cat "${pm_dir}/packages.txt"
                    echo ""
                fi
                ;;
            gem)
                if [[ -f "${pm_dir}/Gemfile" ]]; then
                    echo "💎 RubyGems (Gemfile):"
                    echo "---------------------"
                    cat "${pm_dir}/Gemfile"
                    echo ""
                fi
                ;;
            scoop)
                if [[ -f "${pm_dir}/scoopfile.json" ]]; then
                    echo "🪣 Scoop packages:"
                    echo "-----------------"
                    cat "${pm_dir}/scoopfile.json"
                    echo ""
                fi
                ;;
            choco)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    echo "🍫 Chocolatey packages:"
                    echo "----------------------"
                    cat "${pm_dir}/packages.txt"
                    echo ""
                fi
                ;;
        esac
    fi
done

echo "💡 For summary stats: just show-package-stats"