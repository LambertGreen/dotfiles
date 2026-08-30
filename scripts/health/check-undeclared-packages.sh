#!/usr/bin/env bash
#
# Report packages installed on this machine but declared in no Brewfile
# -> just doctor-check-undeclared
#
# WHY THIS EXISTS
# ---------------
# `brew bundle check` answers "is everything I declared installed?". Nothing
# answered the mirror question: "is anything installed that I never declared?"
#
# That gap bit on 2026-08-29. `isort` was installed twice -- a brew formula and
# a pip copy squatting on /opt/homebrew/bin/isort -- and declared nowhere for
# this machine class. The work machine had already retired it:
#
#     # brew "isort"  # Let projects manage import sorters via dev dependencies
#
# `brew upgrade` touches everything INSTALLED, not just what the Brewfile
# declares, so it tried to upgrade isort, could not link over the pip script,
# and failed the whole brew upgrade step. A package nobody had declared in over
# a year broke the upgrade, and no check would have told you it was there.
#
# WHAT COUNTS AS "UNDECLARED"
# ---------------------------
# Only leaf formulae installed ON REQUEST. Dependencies pulled in by declared
# packages are legitimate and must never be flagged -- there are hundreds of
# them, and flagging them would make this check pure noise that everyone learns
# to ignore. `brew leaves --installed-on-request` is exactly the set of things
# you deliberately installed that nothing else depends on. isort was one.
#
# This check reports; it does not change anything. Exit code stays 0 so it can
# sit in a doctor sweep without failing the run.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$DOTFILES_DIR"

echo "👩‍⚕️ Checking for installed-but-undeclared packages..."

if ! command -v brew >/dev/null 2>&1; then
    echo "  ⏭️  Homebrew not installed — skipping"
    exit 0
fi

# ── Resolve the machine class Brewfile (same approach as doctor-check-taps) ──
if [ -f "$HOME/.dotfiles.env" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.dotfiles.env"
fi
MACHINE_CLASS="${DOTFILES_MACHINE_CLASS:-}"
if [ -z "$MACHINE_CLASS" ]; then
    echo "  ❌ DOTFILES_MACHINE_CLASS not set — run: just configure"
    exit 0
fi

BREWFILE="machine-classes/${MACHINE_CLASS}/brew/Brewfile"
if [ ! -f "$BREWFILE" ]; then
    echo "  ❌ Brewfile not found: $BREWFILE"
    exit 0
fi

echo "  Machine class: $MACHINE_CLASS"
echo ""

# Declared names. Note the '^' anchors: a commented-out line (`# brew "isort"`)
# must NOT count as declared -- that retirement is precisely the signal we want
# this check to respect.
#
# Handles `brew "name"`, `brew "name", link: false`, and tap-qualified
# `brew "tap/repo/name"`. Both the full string and the basename are recorded,
# because `brew leaves` may print either form.
#
# Formulae and casks are tracked SEPARATELY. A flat name set lets a declared
# cask vouch for an installed formula of the same name, which is exactly wrong:
# `cask "neovide"` silently satisfied an installed neovide FORMULA, hiding that
# the same app was installed from both sources.
DECLARED=$(mktemp)
DECLARED_C=$(mktemp)
trap 'rm -f "$DECLARED" "$DECLARED_C"' EXIT

while read -r name; do
    [ -n "$name" ] || continue
    printf '%s\n%s\n' "$name" "${name##*/}" >> "$DECLARED"
done < <(sed -n 's/^brew "\([^"]*\)".*/\1/p' "$BREWFILE")

while read -r name; do
    [ -n "$name" ] || continue
    printf '%s\n%s\n' "$name" "${name##*/}" >> "$DECLARED_C"
done < <(sed -n 's/^cask "\([^"]*\)".*/\1/p' "$BREWFILE")

_is_declared() {
    grep -qxF "$1" "$DECLARED" 2>/dev/null
}

_is_declared_cask() {
    grep -qxF "$1" "$DECLARED_C" 2>/dev/null
}

# Resolve a declared name to the token Homebrew currently uses for it, so an
# upstream rename is not mistaken for drift. `neovide` became `neovide-app`:
# the cask installs under the new token while the Brewfile still says the old
# one. That is a stale declaration, not an undeclared package, and calling it
# drift would be crying wolf.
#
# Only called for declared names not installed under their own name, so this
# costs a brew call for a handful of entries at most.
#
# Emits "<current-name>\t<is-true-rename>" where is-true-rename is 1 only when
# the declared name appears in Homebrew's oldnames/old_tokens for the package.
#
# That distinction matters. Three things all look like "declared name differs
# from installed name", and only one is worth reporting:
#   - true rename:  neovide -> neovide-app        (declared name in old_tokens)
#   - alias:        python  -> python@3.14        (declaring `python` to track
#                                                  latest is deliberate)
#   - tap form:     user/tap/foo -> foo           (same package, longer name)
# Reporting the last two would be noise, and a noisy check gets ignored.
_current_token() {
    local kind="$1" name="$2"
    if [ "$kind" = "cask" ]; then
        brew info --json=v2 --cask "$name" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)['casks'][0]
declared = sys.argv[1]
print(d['token'], int(declared in (d.get('old_tokens') or [])), sep='\t')
" "$name" 2>/dev/null || true
    else
        brew info --json=v2 --formula "$name" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)['formulae'][0]
declared = sys.argv[1]
print(d['name'], int(declared in (d.get('oldnames') or [])), sep='\t')
" "$name" 2>/dev/null || true
    fi
}

RENAMES=$(mktemp)
ACCOUNTED=$(mktemp)
trap 'rm -f "$DECLARED" "$DECLARED_C" "$RENAMES" "$ACCOUNTED"' EXIT

# For each declared name absent from the installed list under its own name,
# check whether it now lives under a new token that IS installed.
_resolve_renames() {
    local kind="$1" installed_list="$2" declared_name info current renamed
    while read -r declared_name; do
        [ -n "$declared_name" ] || continue
        if grep -qxF "$declared_name" "$installed_list"; then
            continue
        fi
        info=$(_current_token "$kind" "$declared_name")
        [ -n "$info" ] || continue
        current=${info%%$'\t'*}
        renamed=${info##*$'\t'}
        [ -n "$current" ] || continue
        [ "$current" = "$declared_name" ] && continue
        grep -qxF "$current" "$installed_list" || continue

        # Either way the package IS installed, so it must not be reported as
        # undeclared drift.
        printf '%s\n' "$current" >> "$ACCOUNTED"

        # ...but only a genuine rename is worth telling the user about.
        if [ "$renamed" = "1" ]; then
            printf '%s\t%s\t%s\n' "$kind" "$declared_name" "$current" >> "$RENAMES"
        fi
    done
}

_is_accounted() {
    grep -qxF "$1" "$ACCOUNTED" 2>/dev/null
}

findings=0

# ── Formulae: deliberately installed, nothing depends on them ───────────────
INSTALLED_F=$(mktemp)      # leaves only — the candidates for "undeclared"
INSTALLED_ALL_F=$(mktemp)  # every formula — used for rename resolution
INSTALLED_C=$(mktemp)
trap 'rm -f "$DECLARED" "$DECLARED_C" "$RENAMES" "$ACCOUNTED" "$INSTALLED_F" "$INSTALLED_ALL_F" "$INSTALLED_C"' EXIT

brew leaves --installed-on-request 2>/dev/null > "$INSTALLED_F" || true
brew list --formula 2>/dev/null > "$INSTALLED_ALL_F" || true

# `brew list --cask` reports Homebrew's own backward-compatibility shims as if
# they were separately installed casks. When a cask is renamed, the Caskroom
# keeps a SYMLINK at the old token pointing to the new directory:
#
#     Caskroom/alfred@4/4.8,1312          <- the real install
#     Caskroom/alfred4 -> alfred@4        <- compat shim, same app
#
# Both get listed, so the old token looks undeclared while the Brewfile
# correctly declares the new one. Skipping symlinked entries counts each cask
# once, by its current name.
CASKROOM="$(brew --prefix 2>/dev/null)/Caskroom"
while read -r c; do
    [ -n "$c" ] || continue
    [ -L "$CASKROOM/$c" ] && continue
    printf '%s\n' "$c"
done < <(brew list --cask 2>/dev/null || true) > "$INSTALLED_C"

# Account for upstream renames before judging anything as undeclared.
#
# Resolve against the FULL installed list, not the leaves list: most declared
# formulae are legitimately absent from `brew leaves` (they have dependents),
# so checking against leaves made almost every declared formula look missing
# and fired a `brew info` call for each -- 19s instead of ~1s. Only genuinely
# absent declarations should cost a lookup.
_resolve_renames formula "$INSTALLED_ALL_F" < <(sed -n 's/^brew "\([^"]*\)".*/\1/p' "$BREWFILE")
_resolve_renames cask "$INSTALLED_C" < <(sed -n 's/^cask "\([^"]*\)".*/\1/p' "$BREWFILE")

undeclared_formulae=()
while read -r f; do
    [ -n "$f" ] || continue
    _is_declared "$f" || _is_declared "${f##*/}" || _is_accounted "$f" \
        || undeclared_formulae+=("$f")
done < "$INSTALLED_F"

if [ ${#undeclared_formulae[@]} -gt 0 ]; then
    echo "  ⚠ Formulae installed on request but not in the Brewfile:"
    for f in "${undeclared_formulae[@]}"; do
        echo "      $f"
    done
    echo ""
    findings=1
fi

# ── Casks ───────────────────────────────────────────────────────────────────
undeclared_casks=()
while read -r c; do
    [ -n "$c" ] || continue
    _is_declared_cask "$c" || _is_declared_cask "${c##*/}" || _is_accounted "$c" \
        || undeclared_casks+=("$c")
done < "$INSTALLED_C"

if [ ${#undeclared_casks[@]} -gt 0 ]; then
    echo "  ⚠ Casks installed but not in the Brewfile:"
    for c in "${undeclared_casks[@]}"; do
        echo "      $c"
    done
    echo ""
    findings=1
fi

# ── Stale declarations (upstream renamed the package) ───────────────────────
if [ -s "$RENAMES" ]; then
    echo "  ℹ Declared under a name upstream has since renamed:"
    while IFS=$'\t' read -r kind old new; do
        printf '      %s "%s"  →  should now be "%s"\n' "$kind" "$old" "$new"
    done < "$RENAMES"
    echo ""
    echo "    Installed correctly — but a rebuilt machine resolves the old name"
    echo "    through a deprecation shim that will not last. Update $BREWFILE."
    echo ""
fi

# ── Verdict ─────────────────────────────────────────────────────────────────
if [ "$findings" -eq 0 ]; then
    echo "  ✓ Everything installed is declared"
else
    echo "  These are installed but undeclared: 'just upgrade' will upgrade them,"
    echo "  yet a rebuilt machine will not have them. Decide, do not ignore:"
    echo ""
    echo "    declare it → add to $BREWFILE"
    echo "                 A global that projects fall back to is FINE — declare"
    echo "                 it in the Project-Tool Fallbacks section and say so."
    echo "    remove it  → brew uninstall <name>   (brew uninstall --cask <name>)"
    echo ""
    echo "  Before declaring, check for a second copy from another package"
    echo "  manager (pip/npm/cargo). Two copies of one tool is what broke"
    echo "  'brew upgrade': a pip isort script squatted on brew's link target."
    echo ""
    echo "  See docs/PACKAGE_POLICY.md for which tier a tool belongs in."
fi

exit 0
