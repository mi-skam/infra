{ inputs, ... }:
{
  imports = [
    ../lib/system-common.nix
    ../users/plumps.nix
    ./secrets.nix
  ];

  # Set primary user for system defaults
  system.primaryUser = "plumps";

  # Locale settings - handled differently on macOS
  system.defaults.NSGlobalDomain = {
    AppleICUForce24HourTime = true;
  };


  # Darwin-specific system settings
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.finder.AppleShowAllFiles = true;
  system.defaults.finder.ShowPathbar = true;
  system.defaults.dock.autohide = true;

  # Enable touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  system.stateVersion = 5;
}
