{
  inputs,
  pkgs,
  osConfig,
  config,
  lib,
  ...
}:

let
  cfg = config.userConfig;
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  options.userConfig = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "User name";
    };

    email = lib.mkOption {
      type = lib.types.str;
      description = "User email address";
    };
    gitName = lib.mkOption {
      type = lib.types.str;
      description = "Git user name";
      default = cfg.name;
    };
  };

  config = {
    # Set the home directory for the user, adjust if on darwin or linux
    home.homeDirectory = if isDarwin then "/Users/${cfg.name}" else "/home/${cfg.name}";

    home.packages = with pkgs; [
      # core
      bat
      eza
      fd
      file
      fzf
      gh
      jq
      ripgrep
      tree
      unzip
      zip

      # Network tools
      curl
      wget
      httpie

      man-pages
    ];


    programs.bash = {
      enable = true;

      initExtra = ''
        # Eg: start your session with zsh and run bash, you'll have the wrong SHELL
        if [[ $(basename "$SHELL") != bash ]]; then
          SHELL=bash
        fi

        if [[ "\$$user" = $(id -u -n) ]]; then
          # Remove \u
          PS1=$(echo "$PS1" | sed 's|\\u||g')
        fi
      '';
    };

    programs.direnv = {
      enable = true;
    };

    programs.fzf.enable = true;

    programs.git = {
      enable = true;
      userName = cfg.name;
      userEmail = cfg.email;
    };

    programs.htop.enable = true;

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
    };

    programs.ssh = {
      enable = true;
      compression = true;
      matchBlocks = {
        "git.adminforge.de" = {
          user = "git";
          port = 222;
          identityFile = "~/Share/Secrets/.ssh/homelab/homelab";
          identitiesOnly = true;
        };
      };
    };

    programs.starship = {
      enable = true;
      settings = {
        git_status.disabled = true;
      };
    };

    programs.tmux.enable = true;

    programs.zoxide.enable = true;

    home.sessionVariables = {
      EDITOR = "nvim";
      PAGER = "bat";
      BAT_THEME = "base16";
    };
    # Shell aliases available on all systems
    home.shellAliases = {
      ll = "eza -la";
      ls = "eza";
      cat = "bat";
      find = "fd";
      grep = "rg";
      cd = "z"; # zoxide

      # Git shortcuts
      g = "git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline";
      gd = "git diff";

      # Development shortcuts
      v = "nvim";
      vim = "nvim";
      cy = "claude --dangerously-skip-permissions";

      # Quick directory navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
    };

    # only available on linux, disabled on macos
    services.ssh-agent.enable = pkgs.stdenv.isLinux;

    home.stateVersion = lib.mkDefault "25.05"; # initial home-manager state
  };
}
