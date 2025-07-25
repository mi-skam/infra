{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/plasma.nix
    ../../modules/nixos/desktop.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "xmsi"; # Define your hostname.

  nixpkgs.hostPlatform = "x86_64-linux";

  services.printing.enable = true;

  # PipeWire audio configuration
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable rtkit for real-time audio scheduling
  security.rtkit.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
