{ config, inputs, pkgs, ... }:

{
  imports = [
    inputs.self.darwinModules.desktop
  ];

  networking.hostName = "lt-01";
  nixpkgs.hostPlatform = "aarch64-darwin";

    nix.settings.trusted-users = [ "plumps" ];


  home-manager.users.plumps = {
    imports = [ inputs.self.homeModules.desktop ];
  };
}
