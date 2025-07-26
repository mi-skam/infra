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
      shell = pkgs.fish;
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
      hashedPasswordFile = config.sops.secrets."mi-skam".path;
    })
  ];
  
  users.mutableUsers = false;
}
