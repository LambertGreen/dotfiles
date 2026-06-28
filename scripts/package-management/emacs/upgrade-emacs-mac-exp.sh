#!/usr/bin/env bash
# Upgrade the macOS emacs-mac-exp@31 HEAD build, with backup/restore safety.
#
# SCOPE: macOS ONLY. This is specifically for the Homebrew `emacs-mac-exp@31`
# formula (YAMAMOTO Mitsuharu's Mac port, jdtsmith experimental fork) installed
# with --HEAD. It is NOT a general/cross-platform Emacs upgrade — Linux/Windows
# Emacs is managed entirely separately and is untouched by this script.
#
# WHY THIS EXISTS: emacs-mac-exp@31 is a --HEAD build. `brew upgrade` skips it
# unless given --fetch-HEAD, and once upgraded brew cannot rebuild the previous
# commit. So the only reliable recourse is to back up the current keg first.
# This script automates that: back up the current keg, upgrade from HEAD,
# smoke-test the new build, and restore the backup if the new build is broken
# (e.g. a dependency's dylib changed out from under it).
#
# Usage: just upgrade-emacs-mac-exp
#    or: bash scripts/package-management/emacs/upgrade-emacs-mac-exp.sh

set -euo pipefail

FORMULA="pkryger/emacsmacport-exp/emacs-mac-exp@31"
SHORT="emacs-mac-exp@31"
BACKUP_ROOT="${HOME}/.dotfiles/backups/emacs-mac-exp"
KEEP_BACKUPS=3

# --- Initialize Homebrew environment -----------------------------------------
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# On Apple Silicon, force brew to run natively (arm64) even if this shell is
# under Rosetta 2 — Homebrew refuses to build from source in an emulated
# process ("Cannot install under Rosetta 2 in ARM default prefix"). On a native
# arm64 shell this prefix is a harmless no-op. Detect the *hardware* via sysctl
# because `uname -m` reports x86_64 when translated.
BREW=(brew)
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" == "1" ]]; then
    BREW=(arch -arm64 brew)
fi

# --- Preconditions -----------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "⏭️  upgrade-emacs-mac-exp is macOS-only (emacs-mac-exp@31). Skipping."
    exit 0
fi
if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew not found. This recipe is macOS-only."
    exit 1
fi
if ! brew list --versions "$SHORT" &>/dev/null; then
    echo "❌ $SHORT is not installed — nothing to upgrade."
    exit 1
fi

CELLAR="$(brew --cellar "$SHORT")"
OPT="$(brew --prefix "$SHORT")"

# Resolve the currently linked keg (e.g. HEAD-648979c) via the opt symlink,
# falling back to the most recent keg in the Cellar.
linked_keg() {
    if [[ -L "$OPT" ]]; then
        basename "$(readlink "$OPT")"
    else
        # shellcheck disable=SC2012
        ls -1t "$CELLAR" | head -1
    fi
}

CURRENT_KEG="$(linked_keg)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${CURRENT_KEG}-${TIMESTAMP}"

echo "🧩 emacs-mac-exp@31 HEAD upgrade (with backup/restore safety)"
echo "============================================================"
echo "  • Formula:  $FORMULA"
echo "  • Current:  $CURRENT_KEG"
echo ""

# --- 1. Back up the current (working) keg ------------------------------------
# This is the real safety net: brew cannot reconstruct a past HEAD commit.
echo "💾 Backing up current keg → ${BACKUP_DIR}"
mkdir -p "$BACKUP_ROOT"
cp -a "${CELLAR}/${CURRENT_KEG}" "$BACKUP_DIR"
echo "  ✅ Backup complete ($(du -sh "$BACKUP_DIR" | awk '{print $1}'))"
echo ""

# --- restore helper ----------------------------------------------------------
restore_backup() {
    echo ""
    echo "♻️  Restoring previous build ($CURRENT_KEG) from backup..."
    set +e
    "${BREW[@]}" uninstall --force "$SHORT" >/dev/null 2>&1
    mkdir -p "$CELLAR"
    rm -rf "${CELLAR:?}/${CURRENT_KEG}"
    cp -a "$BACKUP_DIR" "${CELLAR}/${CURRENT_KEG}"
    "${BREW[@]}" link --overwrite "$SHORT" >/dev/null 2>&1
    set -e
    if "${CELLAR}/${CURRENT_KEG}/bin/emacs" --version >/dev/null 2>&1; then
        echo "  ✅ Restored and verified $CURRENT_KEG. Your editor is back to its working state."
    else
        echo "  ⚠️  Restore ran but the restored binary failed to launch."
        echo "     Manual backup is preserved at: $BACKUP_DIR"
    fi
}

# --- 2. Upgrade from HEAD (keep cleanup off so the old keg also survives) -----
echo "⬆️  Upgrading from HEAD (this compiles from source — may take a while)..."
if ! HOMEBREW_NO_INSTALL_CLEANUP=1 "${BREW[@]}" upgrade --fetch-HEAD "$FORMULA"; then
    echo ""
    echo "❌ brew upgrade failed to build."
    echo "   Homebrew builds atomically, so your previous build ($CURRENT_KEG) is"
    echo "   untouched and still linked. Backup also kept at: $BACKUP_DIR"
    exit 1
fi

# --- 3. Detect whether anything actually changed -----------------------------
NEW_KEG="$(linked_keg)"
if [[ "$NEW_KEG" == "$CURRENT_KEG" ]]; then
    echo ""
    echo "✅ Already on the latest HEAD ($CURRENT_KEG) — no change."
    rm -rf "$BACKUP_DIR"   # redundant backup, nothing changed
    exit 0
fi
echo ""
echo "🔁 Upgraded:  $CURRENT_KEG → $NEW_KEG"

# --- 4. Smoke-test the new build ---------------------------------------------
# A missing/renamed dependency dylib makes the binary fail to even launch, so
# launching it at all catches that whole class of breakage.
echo "🔬 Smoke-testing new build..."
NEW_BIN="${CELLAR}/${NEW_KEG}/bin/emacs"
if "$NEW_BIN" --version >/dev/null 2>&1 \
   && "$NEW_BIN" --batch --eval '(kill-emacs 0)' >/dev/null 2>&1; then
    echo "  ✅ New build launches: $("$NEW_BIN" --version | head -1)"
else
    echo "  ❌ New build ($NEW_KEG) failed to launch."
    restore_backup
    exit 1
fi

# --- 5. Success: prune old backups, leave the latest as recourse -------------
echo ""
# shellcheck disable=SC2012
ls -1dt "${BACKUP_ROOT}"/*/ 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | while read -r old; do
    echo "🗑️  Pruning old backup: $old"
    rm -rf "$old"
done

echo ""
echo "🎉 emacs-mac-exp@31 upgraded successfully: $CURRENT_KEG → $NEW_KEG"
echo "   Rollback available — restore the keg from:"
echo "     $BACKUP_DIR"
echo "   (kept alongside up to $KEEP_BACKUPS most recent backups in $BACKUP_ROOT)"
