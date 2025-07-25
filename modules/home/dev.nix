{ pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in {
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
  };

  home.packages = with pkgs; 
    # Common development packages for both platforms
    [
      # Version control
      git-lfs
      lazygit
      tig
      
      # Build tools
      gnumake
      cmake
      ninja
      
      # Languages and runtimes
      nodejs_22
      python3
      rustup
      
      # Development utilities
      jq
      yq-go
      tree
      fd
      ripgrep
      bat
      eza
      zoxide
      fzf
      
      # Network tools
      curl
      wget
      httpie
      
      # Container tools
      docker-compose
      
      # Text processing
      sd
      
      # Monitoring
      btop
      
      # File tools
      file
      unzip
      zip
    ] 
    # Linux-only packages
    ++ lib.optionals isLinux [
      # Docker (full engine on Linux)
      docker
      
      # System tools
      strace
      ltrace
      lsof
      
      # Development tools
      gdb
      valgrind
      
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
      mas  # Mac App Store CLI
    ];

  # Development-specific environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "bat";
    BAT_THEME = "base16";
  };

  # Shell aliases for development
  home.shellAliases = {
    ll = "eza -la";
    ls = "eza";
    cat = "bat";
    find = "fd";
    grep = "rg";
    cd = "z";  # zoxide
    
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
    
    # Quick directory navigation
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
  };
}