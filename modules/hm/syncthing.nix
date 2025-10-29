{ config, lib, pkgs, ... }:

let
  platform = import ../lib/platform.nix { inherit pkgs; };
in
{
  services.syncthing = {
    enable = true;
    tray = lib.mkIf platform.isLinux {
      enable = true;
      command = "syncthingtray --wait";
    };
  };

  # Install Syncthing package
  home.packages = with pkgs; [
    syncthing
  ] ++ lib.optionals platform.isLinux [
    syncthingtray
  ];
}