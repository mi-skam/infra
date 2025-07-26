{ config, lib, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    tray = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      command = "syncthingtray --wait";
    };
  };

  # Install Syncthing package
  home.packages = with pkgs; [
    syncthing
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    syncthingtray
  ];
}