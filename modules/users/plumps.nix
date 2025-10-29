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
  name = "plumps";
  uid = 1001;
  description = "plumps";
  secretName = "plumps";
}
