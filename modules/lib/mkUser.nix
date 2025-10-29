{
  lib,
  pkgs,
  config,
  ...
}:
{
  mkUser = {
    name,
    uid,
    description,
    secretName,
    groups ? [
      "audio"
      "docker"
      "input"
      "libvirtd"
      "networkmanager"
      "sound"
      "tty"
      "video"
      "wheel"
    ],
  }:
  let
    isDarwin = pkgs.stdenv.isDarwin;
    isLinux = pkgs.stdenv.isLinux;
  in
  {
    users.users.${name} = lib.mkMerge [
      {
        uid = uid;
        shell = pkgs.fish;
        openssh.authorizedKeys.keyFiles = [ ../../secrets/authorized_keys ];
      }

      (lib.mkIf isDarwin {
        home = "/Users/${name}";
      })

      (lib.mkIf isLinux {
        description = description;
        isNormalUser = true;
        extraGroups = groups;
        hashedPasswordFile = config.sops.secrets."${secretName}".path;
      })
    ];

    # Note: users.mutableUsers should be set in modules/nixos/common.nix, not here
    # (this option doesn't exist on Darwin)
  };
}
