{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "lgreen";
  home.homeDirectory = "/home/tsi/lgreen";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.05";

  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url =
        "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz";
    }))
  ];

  home = {
    packages = with pkgs; [
      git
      tmux
      zsh
      # aspell - installing this via Homebrew
      binutils
      ripgrep
      tree
      fd
      bat
      tldr
      neofetch
      direnv
      nixfmt
      # Installing python and pyenv via Homebrew
      # (python39.withPackages (ps: with ps; [
      #   pip
      #   pynvim
      # ]))
      (nerdfonts.override { fonts = [ "Iosevka" ]; })
      glibcLocales
    ];
  };

  programs = {
    home-manager.enable = true;
    jq.enable = true;
    bat.enable = true;
    command-not-found.enable = true;
    dircolors.enable = true;
    info.enable = true;
    exa.enable = true;

    emacs = {
      enable = true;
      package = pkgs.emacsNativeComp;
      extraPackages = (epkgs: [ epkgs.vterm ]);
    };
  };

  fonts = { fontconfig.enable = true; };
}
