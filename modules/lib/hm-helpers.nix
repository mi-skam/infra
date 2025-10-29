{ pkgs, lib }:

{
  # Common CLI packages used across all users
  cliPackages = with pkgs; [
    # Core utilities
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

    # Documentation
    man-pages
  ];

  # Neovim configuration builder with Catppuccin theme
  # Usage: programs.neovim = hmHelpers.mkNeovimConfig {};
  mkNeovimConfig = {
    theme ? "mocha",
  }: {
    enable = true;
    defaultEditor = true;
    vimAlias = true;

    extraLuaConfig = ''
      vim.cmd.colorscheme "catppuccin-${theme}"
    '';

    plugins = with pkgs.vimPlugins; [
      {
        plugin = catppuccin-nvim;
        config = ''
          require("catppuccin").setup({
            flavour = "${theme}",
            background = {
              light = "latte",
              dark = "${theme}",
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

  # Starship prompt configuration builder with Catppuccin palette
  # Usage: programs.starship = hmHelpers.mkStarshipConfig {};
  mkStarshipConfig = {
    palette ? "catppuccin_mocha",
    disableGitStatus ? true,
  }: {
    enable = true;
    settings = {
      git_status.disabled = disableGitStatus;
      palette = palette;
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
}
