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

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      
      extraLuaConfig = ''
        vim.cmd.colorscheme "catppuccin-mocha"
      '';
      
      plugins = with pkgs.vimPlugins; [
        {
          plugin = catppuccin-nvim;
          config = ''
            require("catppuccin").setup({
              flavour = "mocha",
              background = {
                light = "latte",
                dark = "mocha",
              },
              transparent_background = false,
              show_end_of_buffer = false,
              term_colors = false,
              dim_inactive = {
                enabled = false,
                shade = "dark",
                percentage = 0.15,
              },
              no_italic = false,
              no_bold = false,
              no_underline = false,
              styles = {
                comments = { "italic" },
                conditionals = { "italic" },
                loops = {},
                functions = {},
                keywords = {},
                strings = {},
                variables = {},
                numbers = {},
                booleans = {},
                properties = {},
                types = {},
                operators = {},
              },
              color_overrides = {},
              custom_highlights = {},
              integrations = {
                cmp = true,
                gitsigns = true,
                nvimtree = true,
                treesitter = true,
                notify = false,
                mini = {
                  enabled = true,
                  indentscope_color = "",
                },
              },
            })
          '';
          type = "lua";
        }
      ];
    };


    programs.starship = {
      enable = true;
      settings = {
        git_status.disabled = true;
        palette = "catppuccin_mocha";
        palettes.catppuccin_mocha = {
          rosewater = "#f5e0dc";
          flamingo = "#f2cdcd";
          pink = "#f5c2e7";
          mauve = "#cba6f7";
          red = "#f38ba8";
          maroon = "#eba0ac";
          peach = "#fab387";
          yellow = "#f9e2af";
          green = "#a6e3a1";
          teal = "#94e2d5";
          sky = "#89dceb";
          sapphire = "#74c7ec";
          blue = "#89b4fa";
          lavender = "#b4befe";
          text = "#cdd6f4";
          subtext1 = "#bac2de";
          subtext0 = "#a6adc8";
          overlay2 = "#9399b2";
          overlay1 = "#7f849c";
          overlay0 = "#6c7086";
          surface2 = "#585b70";
          surface1 = "#45475a";
          surface0 = "#313244";
          base = "#1e1e2e";
          mantle = "#181825";
          crust = "#11111b";
        };
      };
    };

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
    services.ssh-agent.enable = pkgs.stdenv.isLinux;

    home.stateVersion = lib.mkDefault "25.05"; # initial home-manager state
  };
}
