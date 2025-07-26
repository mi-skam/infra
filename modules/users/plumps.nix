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
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [ ../../secrets/authorized_keys ];
    }

    (lib.mkIf isDarwin {
      home = "/Users/plumps";
    })

    (lib.mkIf isLinux {
      description = "plumps";
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
      hashedPasswordFile = config.sops.secrets."plumps".path;
    })
  ];
  
  users.mutableUsers = false;
}
