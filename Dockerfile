FROM archlinux/archlinux:base-devel

# Install minimal packages for dotfiles testing + realistic system defaults
RUN pacman --sync --refresh --sysupgrade --noconfirm --noprogressbar --quiet && \
  pacman --sync --noconfirm --noprogressbar --quiet \
    sudo git openssh stow just bash zsh && \
  pacman -Scc --noconfirm && \
  rm -rf /var/cache/pacman/pkg/* /tmp/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Create a test user (Note: we need to give the user an explicit uid, since we need to reference it
# in the ssh mount command.)
RUN useradd -u 100 --create-home --comment "Arch dotfiles user" user && \
    usermod -aG wheel user  # Grant sudo to the user

# Add user to sudoers
RUN sed -i /etc/sudoers -re 's/^#includedir.*/## **Removed the include directive** ##"/g' && \
    echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set user's password to 'user'
RUN echo 'user:user' | chpasswd
USER user
ENV HOME=/home/user

# Download public key for github.com
RUN mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    echo "Host remotehost\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config && \
    sudo chmod 0600 ~/.ssh/* && \
    sudo chown -v user ~/.ssh/*

# Clone the dotfiles repo and sync submodules (stable layer - cached unless submodules change)
ARG GITHUB_TOKEN
RUN git clone https://${GITHUB_TOKEN}@github.com/LambertGreen/dotfiles.git ~/dev/my/dotfiles && \
    cd ~/dev/my/dotfiles && \
    git submodule update --init --recursive

# Switch to specific branch and run tests (this layer rebuilds when code changes)
ARG CACHE_BUST=1
RUN cd ~/dev/my/dotfiles && \
    git fetch origin && \
    git checkout feature/reorganize-stow-configs && \
    git pull origin feature/reorganize-stow-configs && \
    cd ~/dev/my/dotfiles/configs && \
    just stow-arch && \
    cd ~/.package_management/install && \
    just install-test

# Run a bash instance for manual testing: user should validate apps run fine before and after unstowing
WORKDIR /home/user/dev/my/dotfiles
CMD ["/bin/bash"]
