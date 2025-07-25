{ inputs, ... }:
{
  imports = [
    ../users/plumps.nix
  ];

  # Set primary user for system defaults
  system.primaryUser = "plumps";

  # common nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Europe/Berlin";

  
  # Locale settings - handled differently on macOS
  system.defaults.NSGlobalDomain = {
    AppleICUForce24HourTime = true;
  };

  # Shell completion (similar to Bash completion)
  programs.bash.enable = true;
  programs.bash.completion.enable = true;
  
  # Darwin-specific system settings
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.finder.AppleShowAllFiles = true;
  system.defaults.finder.ShowPathbar = true;
  system.defaults.dock.autohide = true;
  
  # Enable touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}