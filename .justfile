# Justfile for system-level maintenance tasks

# Update Emacs Elpaca packages in batch mode
update-emacs:
    DOTFILES_EMACS_UPDATE=1 emacs --batch --init-directory=~/.emacs.default/ --load=~/.emacs.default/init.el
