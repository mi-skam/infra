{ pkgs, ... }:

{
  imports = [
    ./common.nix
  ];

  # Homebrew configuration for Darwin
  homebrew = {
    enable = true;
    
    # CLI tools that work better or are only available via Homebrew
    brews = [
      # Add any CLI tools you need from Homebrew that aren't in nixpkgs
      # or work better from Homebrew on macOS
    ];
    
    # GUI applications via casks
    casks = [
      "firefox"
      "bitwarden"
      "signal"
      "spotify"
      "discord"
      "docker"
      "visual-studio-code"
      "vivaldi"
    ];
  };

  # Darwin-specific desktop environment
  environment.systemPackages = with pkgs; [
    pciutils
  ];

  # macOS keyboard settings (equivalent to keyd on Linux)
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # For Logitech MX keyboard (if you use it on macOS)
  # Note: Custom keyboard modifier mappings removed as they're not supported by nix-darwin
  # These would need to be configured manually or with a different approach

  # Other Darwin-specific desktop settings
  system.defaults.dock = {
    autohide = true;
    mru-spaces = false;
    minimize-to-application = true;
  };

  # Darwin-specific window management
  services.yabai = {
    enable = false; # Set to true to enable tiling window manager
    config = {
      layout = "bsp";
      auto_balance = "on";
      window_placement = "second_child";
      window_gap = 8;
      top_padding = 8;
      bottom_padding = 8;
      left_padding = 8;
      right_padding = 8;
    };
  };

  # Keyboard shortcuts (similar to keyd functionality)
  services.skhd = {
    enable = false; # Set to true if you want keyboard shortcuts
    skhdConfig = ''
      # Application shortcuts
      cmd - return : open -n /Applications/Terminal.app
      cmd + shift - return : open -n /Applications/Firefox.app
    '';
  };
}
