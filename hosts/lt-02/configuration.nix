{ config, inputs, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      inputs.srvos.nixosModules.mixins-systemd-boot

      inputs.self.nixosModules.plasma
      inputs.self.nixosModules.desktop

      inputs.nixos-hardware.nixosModules.msi-gl65-10SDR-492
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "lt-02"; # Define your hostname.

  nixpkgs.hostPlatform = "x86_64-linux";

  home-manager.users.mi-skam = {
    imports = [ inputs.self.homeModules.desktop ];
    config.home.stateVersion = "24.11";
  };

  services.printing.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
