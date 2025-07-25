{
  pkgs,
  config,
  lib,
  ...
}:
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  users.users.plumps = lib.mkMerge [
    {
      uid = 1001;
      shell = "/run/current-system/sw/bin/bash";
      openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
    }

    (lib.mkIf isDarwin {
      home = "/Users/plumps";
    })

    (lib.mkIf isLinux {
      isNormalUser = true;
      extraGroups = [
        "audio"
        "docker"
        "input"
        "libvirtd"
        "networkmanager"
        "sound"
        "tty"
        "video"
        "wheel"
      ];
      hashedPassword = "$y$j9T$TfS4OF5Gxi.lsH/lnPiXO/$9i8iVkE1r0Z8.EEDOUC/SzM4edMmBWv.KAYzIUHJi19";
    })
  ];
}
