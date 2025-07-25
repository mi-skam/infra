{
  config,
  pkgs,
  lib,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  imports = [
    ./common.nix
  ];

  programs = {
    # Development programs
    git.enable = true;
    gh.enable = true;
    tmux.enable = true;
    htop.enable = true;
    direnv.enable = true;

    # Language-specific tools
    go.enable = true;

    # Editor configurations
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    # VSCode with GUI extension management
    vscode = {
      enable = true;
      # Use profiles structure (modern home-manager)
      profiles.default = {
        # Don't manage extensions through Nix - allows GUI installation
        extensions = [ ];
        # User settings can be managed here if desired, but empty allows GUI management
        userSettings = { };
      };
    };
  };

  home.packages =
    with pkgs;
    # Common development packages for both platforms
    [
      # Version control
      git-lfs
      lazygit
      tig

      # Build tools
      gnumake
      just

      # Languages and runtimes
      nodejs_22
      python3

      # Nix development tools
      nixfmt-rfc-style

      # Container tools
      docker-compose

    ]
    # Linux-only packages
    ++ lib.optionals isLinux [

      # System tools
      strace
      ltrace
      lsof

      # Networking
      netcat-gnu
      nmap

      # Performance tools
      perf-tools
    ]
    # Darwin-specific packages
    ++ lib.optionals isDarwin [
      # macOS alternatives and specific tools
      # Docker Desktop is typically installed via homebrew/manually on macOS

      # System tools
      fswatch

      # Networking
      netcat

      # macOS-specific development tools
      mas # Mac App Store CLI
    ];

  # Home session path for global npm packages
  # This allows global npm packages to be available in the user's PATH
  home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

  # Development-specific environment variables
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  };
}
