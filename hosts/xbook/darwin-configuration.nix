{ config, inputs, pkgs, ... }:

{
  imports = [
    ../../modules/darwin/desktop.nix
  ];

  networking.hostName = "xbook";
  nixpkgs.hostPlatform = "aarch64-darwin";

    nix.settings.trusted-users = [ "plumps" ];


}
