{...}:
{
  users.users.mi-skam = {
    uid = 1000;

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

    shell = "/run/current-system/sw/bin/bash";

    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];

  };
}
