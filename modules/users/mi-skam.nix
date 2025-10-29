{
  pkgs,
  config,
  lib,
  ...
}:
let
  userLib = import ../lib/mkUser.nix { inherit lib pkgs config; };
in
userLib.mkUser {
  name = "mi-skam";
  uid = 1000;
  description = "Maksim Bronsky";
  secretName = "mi-skam";
}
