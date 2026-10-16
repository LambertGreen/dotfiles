#!/usr/bin/env bash
# Shared by stow.sh (just stow) and check.sh (just stow-check): which packages a
# machine class stows, and with which folding rule. Source it; run from configs/.

# Print the package names in a class's stow.txt, skipping blanks and comments.
stow_packages() {
    local entry
    while IFS= read -r entry; do
        [[ -z "$entry" || "$entry" =~ ^[[:space:]]*# ]] && continue
        printf '%s\n' "$entry"
    done < "$1"
}

# Print --no-folding when the package's .stowrc marker asks for file-level
# links (e.g. ssh_common: ~/.ssh holds keys, so only `config` is linked).
# Packages without the marker fold: stow links the whole directory, as for
# ~/.emacs.d and ~/.claude.
stow_fold_opts() {
    if [ -f "$1/.stowrc" ] && grep -q "no-folding" "$1/.stowrc"; then
        printf -- '--no-folding'
    fi
}
