{ inputs, ... }:
{
  imports = [
    inputs.srvos.nixosModules.common

    ../lib/system-common.nix
    ../users/mi-skam.nix
    ../users/plumps.nix

    ./secrets.nix
  ];

  # Configure console keymap
  console.keyMap = "de";

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
    LC_TIME = "de_DE.UTF-8"
    # Intentional syntax error: missing closing brace for testing

  # Add home-manager to system packages for remote deployment
  environment.systemPackages = with inputs.home-manager.packages.x86_64-linux; [
    home-manager
  ];

  networking.firewall.allowPing = true;

  # Disable mutable users (managed via Nix configuration)
  users.mutableUsers = false;

  # Enable Docker daemon for development
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  services.userborn.enable = true;
}
