FROM archlinux/archlinux:base-devel
# Install packages for dotfiles valiation
RUN pacman --sync --refresh --sysupgrade --noconfirm --noprogressbar --quiet && \
  pacman --sync --noconfirm --noprogressbar --quiet \
    sudo git openssh stow coreutils zsh tmux neovim emacs fd ripgrep python3 python-pip
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Create a test user
RUN useradd --create-home --comment "Arch dotfiles user" user && \
    usermod -aG wheel user  # Grant sudo to the user
# Add user to sudoers
RUN sed -i /etc/sudoers -re 's/^#includedir.*/## **Removed the include directive** ##"/g' && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# Set user's password to 'user'
RUN echo 'user:user' | chpasswd
USER user
ENV HOME /home/user
# Clone the dotfiles repo and also pull down sub-modules
RUN git clone https://github.com/LambertGreen/dotfiles.git ~/dev/my/dotfiles && \
    cd ~/dev/my/dotfiles && \
    git submodule update --init --recursive
# Remove users existing Bash scripts (otherwise stow will not work for the Bash scripts).
RUN rm ~/.bash*
# Use stow to link in the dotfiles
RUN cd ~/dev/my/dotfiles && \
    stow shell shell_linux git git_my git_work git_linux tmux vim nvim emacs
# Run a bash instance for manual testing: user should validate apps run fine before and after unstowing
WORKDIR /home/user/dev/my/dotfiles
CMD ["/bin/bash"]
