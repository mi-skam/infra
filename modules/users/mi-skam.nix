{
  pkgs,
  config,
  lib,
  ...
}:
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  username = "mi-skam";
in
{
  users.users.${username} = lib.mkMerge [
    {
      uid = 1000;
      shell = "/run/current-system/sw/bin/bash";
      openssh.authorizedKeys.keyFiles = [ ../../secrets/authorized_keys ];
    }

    (lib.mkIf isDarwin {
      home = "/Users/${username}";
    })

    (lib.mkIf isLinux {
      description = "Maksim Bronsky";
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
