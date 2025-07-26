{ inputs, ... }:
{
  imports = [
    ../users/mi-skam.nix
    inputs.srvos.nixosModules.common
  ];

  # common nix settings
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  # Configure console keymap
  console.keyMap = "de";

  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  programs.fish.enable = true;
  programs.command-not-found.enable = false;
  
  # Add home-manager to system packages for remote deployment
  environment.systemPackages = with inputs.home-manager.packages.x86_64-linux; [
    home-manager
  ];

  networking.firewall.allowPing = true;

  # Enable Docker daemon for development
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  services.userborn.enable = true;
}
