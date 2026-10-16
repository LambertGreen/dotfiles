#!/usr/bin/env bash
# Switch ~/.claude from a real directory (with per-file stow links) to one stow folder
# link into configs/<pkg>/dot-claude (B25), or back again with --rollback.
#
#   scripts/claude/migrate-dir.sh [--dry-run]              migrate
#   scripts/claude/migrate-dir.sh --rollback [--dry-run]   undo
#
# Nothing in ~/.claude is lost or copied. Each entry is mv'd: on the same volume that is
# a rename, so the entry keeps its inode, mtime and xattrs. Runtime state (sessions,
# transcripts, memory, plugins, caches) moves into the package directory, where the
# submodule's allow-list .gitignore hides it. A ditto/cp backup is taken first anyway.
#
# Run it with NO Claude session running on this machine (the Council and missions
# included): they write to ~/.claude all the time. The script refuses while
# `pgrep -x claude` finds one. Run it from a plain terminal: stage it with attune.
#
# Migrate refuses, and changes nothing, when:
#   - the submodule is not initialized or has uncommitted changes
#   - an entry would be committable (not hidden by the submodule's .gitignore)
#   - an entry already exists in the package directory
# After the move it gates on `git status`: anything untracked or deleted triggers an
# automatic rollback. A live curated file (settings.json, CLAUDE.md) that is a plain file
# differing from the repo copy is adopted: it replaces the repo copy and shows as a diff
# to review and commit (the work Mac's drifted settings.json).
#
# TARGET_HOME and DOTFILES_DIR override HOME and the repo for tests and rehearsals.
# CLAUDE_MIGRATE_ALLOW_RUNNING=1 skips the running-session check, and only when
# TARGET_HOME is not the real $HOME. CLAUDE_MIGRATE_TRASH replaces `trash` (tests).

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TARGET_HOME="${TARGET_HOME:-$HOME}"
CURATED=(settings.json CLAUDE.md) # tracked files that a pre-migration ~/.claude holds as stow links

mode=migrate
dry_run=false
for arg in "$@"; do
    case "$arg" in
        --rollback) mode=rollback ;;
        --dry-run) dry_run=true ;;
        -h | --help)
            sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "migrate-dir: unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

die() {
    echo "❌ $*" >&2
    exit 1
}
say() { echo "   $*"; }
is_curated() {
    local c
    for c in "${CURATED[@]}"; do [ "$1" = "$c" ] && return 0; done
    return 1
}

# --- which package -------------------------------------------------------------------------
if [ -f "$TARGET_HOME/.dotfiles.env" ]; then
    # shellcheck disable=SC1091
    source "$TARGET_HOME/.dotfiles.env"
fi
class="${DOTFILES_MACHINE_CLASS:-}"
[ -n "$class" ] || die "DOTFILES_MACHINE_CLASS not set (run: just configure)"
stow_file="$DOTFILES_DIR/machine-classes/$class/stow/stow.txt"
[ -f "$stow_file" ] || die "$stow_file not found"
pkg=""
for candidate in ai_claude_my ai_claude_work; do
    if grep -qx "$candidate" "$stow_file"; then pkg="$candidate"; fi
done
[ -n "$pkg" ] || die "$class stows no Claude folder package (ai_claude_my / ai_claude_work)"

live="$TARGET_HOME/.claude"
dir="$DOTFILES_DIR/configs/$pkg/dot-claude"
configs="$DOTFILES_DIR/configs"

echo "🔀 ~/.claude folder link: $mode$($dry_run && echo ' (dry run)')"
say "class $class → package $pkg"
say "live: $live"
say "repo: $dir"

# --- preconditions shared by both directions -------------------------------------------------
if [ "${CLAUDE_MIGRATE_ALLOW_RUNNING:-}" = 1 ] && [ "$TARGET_HOME" != "$HOME" ]; then
    say "running-session check skipped (rehearsal: TARGET_HOME is not \$HOME)"
elif pids=$(pgrep -x claude); then
    die "Claude is running (pids: $(echo "$pids" | paste -sd ' ' -)). Quit every Claude session on this machine (the Council and missions included), then re-run."
fi
[ -e "$dir/.git" ] || die "$dir is not an initialized submodule. Run: just git-sync"
command -v stow >/dev/null 2>&1 || die "stow not on PATH"

stow_pkg() { (cd "$configs" && stow --dotfiles --target="$TARGET_HOME" "$@" "$pkg"); }

# Untracked, ignored top-level entries of the package dir: the runtime state.
runtime_entries() {
    local name tracked
    tracked=$(git -C "$dir" ls-files | cut -d/ -f1 | sort -u)
    for entry in "$dir"/* "$dir"/.[!.]*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        name=$(basename "$entry")
        [ "$name" = .git ] && continue
        grep -qxF "$name" <<< "$tracked" && continue
        printf '%s\n' "$name"
    done
}

rollback() {
    if [ -L "$live" ]; then
        if $dry_run; then say "would unstow the folder link: stow -D $pkg"; else stow_pkg -D; say "unstowed the folder link"; fi
    elif [ -e "$live" ] && [ ! -d "$live" ]; then
        die "$live is neither the folder link nor a directory; inspect it by hand"
    fi
    $dry_run || mkdir -p "$live"
    local n=0 name
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if [ -e "$live/$name" ] || [ -L "$live/$name" ]; then
            die "$live/$name already exists; not overwriting it. Resolve by hand, then re-run --rollback."
        fi
        $dry_run || mv "$dir/$name" "$live/$name"
        n=$((n + 1))
    done < <(runtime_entries)
    say "$($dry_run && echo 'would move' || echo 'moved') $n runtime entr(ies) back into $live"
    if $dry_run; then
        say "would restore per-file links: stow --no-folding $pkg"
    else
        stow_pkg --no-folding
        say "restored per-file links: $(cd "$live" && for c in "${CURATED[@]}"; do [ -L "$c" ] && printf '%s ' "$c"; done)"
    fi
}

# --- rollback ----------------------------------------------------------------------------------
if [ "$mode" = rollback ]; then
    rollback
    $dry_run || echo "✅ Rolled back: ~/.claude is a real directory again. Curated files stay in the repo."
    exit 0
fi

# --- migrate: plan ----------------------------------------------------------------------------
if [ -L "$live" ]; then
    if [[ "$(readlink "$live")" == *"configs/$pkg/dot-claude" ]]; then
        echo "✅ Already migrated: $live → $(readlink "$live")"
        exit 0
    fi
    die "$live is a symlink to $(readlink "$live"), not into $pkg; inspect it by hand"
fi
[ -d "$live" ] || die "$live is not a directory (nothing to migrate: just stow creates the link)"
[ -z "$(git -C "$dir" status --porcelain --untracked-files=all)" ] ||
    die "$dir has uncommitted changes; commit or revert them first"

drop=() adopt=() move=() problems=()
for entry in "$live"/* "$live"/.[!.]*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    name=$(basename "$entry")
    if is_curated "$name"; then
        if [ -L "$entry" ]; then
            drop+=("$name") # the old per-file stow link
        elif [ -f "$entry" ] && cmp -s "$entry" "$dir/$name"; then
            drop+=("$name")
        elif [ -f "$entry" ]; then
            adopt+=("$name")
        else
            problems+=("$name: not a file or link")
        fi
    elif [ -e "$dir/$name" ] || [ -L "$dir/$name" ]; then
        problems+=("$name: already exists in $dir")
    elif ! git -C "$dir" check-ignore -q -- "$name$([ -d "$entry" ] && [ ! -L "$entry" ] && echo /)"; then
        # (a trailing / makes git match directory rules such as !/agents/: the path does not exist in the repo yet)
        problems+=("$name: NOT ignored by $dir/.gitignore, so it would be committable")
    else
        move+=("$name")
    fi
done

say "move into the repo dir (git-ignored): ${#move[@]} entr(ies)"
[ ${#drop[@]} -eq 0 ] || say "trash (old stow links / copies identical to the repo): ${drop[*]}"
[ ${#adopt[@]} -eq 0 ] || say "adopt (live file differs from the repo; becomes a diff to review): ${adopt[*]}"
if [ ${#problems[@]} -gt 0 ]; then
    for p in "${problems[@]}"; do echo "   ✗ $p" >&2; done
    die "refusing to migrate; nothing was changed"
fi
if $dry_run; then
    say "would back up $live, move, gate on git status, then: stow $pkg (folder link)"
    echo "✅ Dry run: the migration would proceed."
    exit 0
fi

# --- migrate: act -----------------------------------------------------------------------------
backup="$live.pre-dirstow-$(date +%Y%m%d-%H%M%S)"
if command -v ditto >/dev/null 2>&1; then ditto "$live" "$backup"; else cp -a "$live" "$backup"; fi
say "backup: $backup"

# ${a[@]+"${a[@]}"}: an empty array is "unbound" under set -u in macOS /bin/bash 3.2
for name in ${move[@]+"${move[@]}"}; do mv "$live/$name" "$dir/$name"; done
for name in ${drop[@]+"${drop[@]}"}; do "${CLAUDE_MIGRATE_TRASH:-trash}" "$live/$name"; done
for name in ${adopt[@]+"${adopt[@]}"}; do mv "$live/$name" "$dir/$name"; done

if ! rmdir "$live" 2>/dev/null; then
    # shellcheck disable=SC2012  # display only
    echo "   ✗ $live is not empty after the move (something wrote to it): $(ls -A "$live" | paste -sd ' ' -)" >&2
    echo "   rolling back" >&2
    rollback
    die "migration rolled back; backup kept at $backup"
fi

leaks=$(git -C "$dir" status --porcelain --untracked-files=all | grep -v '^ M ' || true)
if [ -n "$leaks" ]; then
    echo "   ✗ git sees more than curated edits:" >&2
    printf '     %s\n' "$leaks" >&2
    echo "   rolling back" >&2
    rollback
    die "migration rolled back; backup kept at $backup"
fi

stow_pkg
if [ ! -L "$live" ] || [ ! -f "$live/settings.json" ]; then
    rollback
    die "stow did not create the folder link; rolled back (backup: $backup)"
fi
say "stowed: $live → $(readlink "$live")"
echo "✅ Migrated. Next: just doctor-check-claude-settings, then start Claude and check that memory and resume work."
[ ${#adopt[@]} -eq 0 ] || echo "   Review the adopted file(s): git -C configs/$pkg/dot-claude diff"
echo "   When satisfied, trash the backup: trash $backup"
