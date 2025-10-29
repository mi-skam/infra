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

  # Import shared libraries for reusable configurations and platform detection
  platform = import ../lib/platform.nix { inherit pkgs; };
  hmHelpers = import ../lib/hm-helpers.nix { inherit pkgs lib; };
in
{
  imports = [
    ./syncthing.nix
    # ./wireguard.nix
    ./ssh.nix
    ./secrets.nix
  ];
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
    home.homeDirectory = if platform.isDarwin then "/Users/${cfg.name}" else "/home/${cfg.name}";

    # Use shared CLI package list from hm-helpers
    home.packages = hmHelpers.cliPackages;

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

        # Function to create a random temp directory and cd to it
        rcd() {
          local tmpdir=$(mktemp -d)
          echo "Created and moved to: $tmpdir"
          cd "$tmpdir"
        }
      '';
    };

    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting # Disable greeting
      '';
      functions = {
        rcd = ''
          set tmpdir (mktemp -d)
          echo "Created and moved to: $tmpdir"
          cd $tmpdir
        '';
      };
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

    # Use shared neovim configuration with Catppuccin theme
    programs.neovim = hmHelpers.mkNeovimConfig {};


    # Use shared starship configuration with Catppuccin palette
    programs.starship = hmHelpers.mkStarshipConfig {};

    programs.tmux.enable = true;

    programs.zoxide.enable = true;

    home.sessionVariables = {
      EDITOR = "nvim";
      PAGER = "bat";
      BAT_THEME = "Catppuccin Mocha";
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

      # File operations
      rf = "rm -rf";
    };

    # only available on linux, disabled on macos
    services.ssh-agent.enable = platform.isLinux;

    home.stateVersion = lib.mkDefault "25.05"; # initial home-manager state
  };
}
