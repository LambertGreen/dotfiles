#!/usr/bin/env bash
# Show packages configured for current machine class

set -euo pipefail

MACHINE_CLASS_ENV="${HOME}/.dotfiles.env"
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MACHINES_DIR="${DOTFILES_ROOT}/machine-classes"

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
                    formulae=$(grep -c '^brew ' "${pm_dir}/Brewfile" 2>/dev/null || echo "0")
                    casks=$(grep -c '^cask ' "${pm_dir}/Brewfile" 2>/dev/null || echo "0")
                    mas=$(grep -c '^mas ' "${pm_dir}/Brewfile" 2>/dev/null || echo "0")
                    taps=$(grep -c '^tap ' "${pm_dir}/Brewfile" 2>/dev/null || echo "0")
                    # Ensure no newlines in variables
                    formulae="${formulae//[$'\r\n']/}"
                    casks="${casks//[$'\r\n']/}"
                    mas="${mas//[$'\r\n']/}"
                    taps="${taps//[$'\r\n']/}"
                    echo "🍺 Homebrew: ${formulae} formulae, ${casks} casks, ${mas} Mac App Store, ${taps} taps"
                    total_packages=$((total_packages + ${formulae:-0} + ${casks:-0} + ${mas:-0}))
                fi
                ;;
            pip)
                if [[ -f "${pm_dir}/requirements.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/requirements.txt" 2>/dev/null || echo "0")
                    count="${count//[$'\r\n']/}"
                    echo "🐍 Python (pip): ${count} packages"
                    total_packages=$((total_packages + ${count:-0}))
                fi
                ;;
            npm)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo "0")
                    count="${count//[$'\r\n']/}"
                    echo "📦 NPM: ${count} global packages"
                    total_packages=$((total_packages + ${count:-0}))
                fi
                ;;
            apt)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo "0")
                    count="${count//[$'\r\n']/}"
                    echo "📦 APT: ${count} packages"
                    total_packages=$((total_packages + ${count:-0}))
                fi
                ;;
            pacman)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo "0")
                    count="${count//[$'\r\n']/}"
                    echo "📦 Pacman: ${count} packages"
                    total_packages=$((total_packages + ${count:-0}))
                fi
                ;;
            cargo)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo "0")
                    count="${count//[$'\r\n']/}"
                    echo "🦀 Cargo: ${count} packages"
                    total_packages=$((total_packages + ${count:-0}))
                fi
                ;;
            gem)
                if [[ -f "${pm_dir}/Gemfile" ]]; then
                    count=$(grep -c '^gem ' "${pm_dir}/Gemfile" 2>/dev/null || echo "0")
                    count="${count//[$'\r\n']/}"
                    echo "💎 RubyGems: ${count} gems"
                    total_packages=$((total_packages + ${count:-0}))
                fi
                ;;
            scoop)
                if [[ -f "${pm_dir}/scoopfile.json" ]]; then
                    echo "🪣 Scoop: configuration file present"
                fi
                ;;
            choco)
                if [[ -f "${pm_dir}/packages.txt" ]]; then
                    count=$(grep -c . "${pm_dir}/packages.txt" 2>/dev/null || echo "0")
                    count="${count//[$'\r\n']/}"
                    echo "🍫 Chocolatey: ${count} packages"
                    total_packages=$((total_packages + ${count:-0}))
                fi
                ;;
        esac
    fi
done

echo ""
echo "📊 Total: ${total_packages} packages across all package managers"
echo ""
echo "💡 To view package details:"
echo "  View detailed package lists"
echo "  cd machine-classes/${DOTFILES_MACHINE_CLASS}  # View raw files"