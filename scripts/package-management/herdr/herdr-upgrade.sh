#!/usr/bin/env bash
# Upgrade herdr on purpose: brew upgrade herdr → stop live servers → relaunch the Council.
#
# WHY THIS EXISTS: a herdr upgrade can bump the client/server protocol. On
# 2026-10-03 `brew upgrade` took the client 0.8.2 (protocol 20) → 0.9.3
# (protocol 22) under a live protocol-20 server, and every herdr call failed
# until `herdr server stop`, which closes ALL panes. So `just upgrade` now holds
# herdr back while a server is live (src/dotfiles_pm/herdr_guard.py), and this
# is the deliberate path it points at.
#
# It STOPS EVERY LIVE HERDR SERVER, KILLING ALL PANES (Council and missions
# included). So it:
#   - refuses to run non-interactively (needs a TTY on stdin and stdout),
#   - refuses to run inside a herdr pane (stopping the server would kill it),
#   - asks you to type a confirmation word before touching anything.
#
# Usage: just herdr-upgrade
#    or: bash scripts/package-management/herdr/herdr-upgrade.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/../../../src/dotfiles_pm/herdr_guard.py"
CONFIRM_WORD="restart"

# Prefer a brew already on PATH (tests stub it); otherwise load Homebrew's env.
if ! command -v brew &>/dev/null; then
    for prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
        if [[ -x "$prefix/bin/brew" ]]; then
            eval "$("$prefix/bin/brew" shellenv)"
            break
        fi
    done
fi

# --- Preconditions -----------------------------------------------------------
if [[ ! -t 0 || ! -t 1 ]]; then
    echo "❌ herdr-upgrade refuses to run non-interactively: it kills every herdr pane." >&2
    echo "   Run it yourself in a terminal tab OUTSIDE herdr: just herdr-upgrade" >&2
    exit 2
fi
if [[ "${HERDR_ENV:-0}" == "1" ]]; then
    echo "❌ You are inside a herdr pane. Stopping the server would kill this script mid-run." >&2
    echo "   Open a plain terminal tab (not herdr) and run: just herdr-upgrade" >&2
    exit 2
fi
for tool in brew herdr python3; do
    if ! command -v "$tool" &>/dev/null; then
        echo "❌ $tool not found on PATH." >&2
        exit 1
    fi
done

echo "🔍 herdr upgrade picture:"
python3 "$GUARD" status | sed 's/^/   /'

outdated="$(brew outdated --formula --quiet herdr 2>/dev/null || true)"
if [[ -z "$outdated" ]]; then
    echo "✅ herdr is already the latest version; nothing to do."
    exit 0
fi

if ! sessions_out="$(python3 "$GUARD" live-sessions)"; then
    echo "❌ Cannot list herdr sessions; not upgrading blind." >&2
    exit 1
fi
sessions=()
while IFS= read -r name; do
    [[ -n "$name" ]] && sessions+=("$name")
done <<< "$sessions_out"

# --- Confirm -----------------------------------------------------------------
echo
if (( ${#sessions[@]} )); then
    echo "⚠️  This will upgrade herdr and then STOP these live herdr servers:"
    printf '      - %s\n' "${sessions[@]}"
    echo "   That CLOSES EVERY PANE in them: the Council and all missions."
    echo "   Afterwards it relaunches the Council with ai_council (resumes by session id)."
else
    echo "ℹ️  No live herdr server: this only upgrades herdr."
fi
read -r -p "Type '$CONFIRM_WORD' to continue, anything else aborts: " answer
if [[ "$answer" != "$CONFIRM_WORD" ]]; then
    echo "Aborted; nothing changed."
    exit 1
fi

# --- Upgrade → stop → relaunch ----------------------------------------------
before="$(herdr --version 2>/dev/null || echo unknown)"
echo "⬆️  brew upgrade herdr (was: $before)"
if ! brew upgrade herdr; then
    echo "❌ brew upgrade herdr failed; servers left running, panes intact." >&2
    exit 1
fi
echo "   now: $(herdr --version 2>/dev/null || echo unknown)"

stop_failed=0
for name in "${sessions[@]+"${sessions[@]}"}"; do
    echo "🛑 herdr --session $name server stop"
    if ! herdr --session "$name" server stop; then
        echo "   ⚠️  stop failed for session '$name'; stop it by hand." >&2
        stop_failed=1
    fi
done
if (( stop_failed )); then
    exit 1
fi

if (( ${#sessions[@]} == 0 )); then
    echo "✅ herdr upgraded."
    exit 0
fi

if ! command -v ai_council &>/dev/null; then
    echo "✅ herdr upgraded and servers stopped. ai_council is not on PATH; relaunch your sessions by hand."
    exit 0
fi
echo "🚀 Relaunching the Council: ai_council"
echo "   Once inside herdr, run ai_council again to wake Claude (resumes the recorded Council session id)."
exec ai_council
