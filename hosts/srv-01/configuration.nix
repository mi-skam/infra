{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/server.nix
    ../../modules/nixos/monitoring.nix
  ];

  networking = {
    hostName = "srv-01";
    domain = "dev.zz";
  };

  nixpkgs.hostPlatform = "x86_64-linux";


  system.stateVersion = "24.11";
}