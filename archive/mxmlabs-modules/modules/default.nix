# Default module imports for the shared modules
{ ... }:
{
  imports = [
    ./base/nix-config.nix
    ./development/python.nix
    ./roles/workstation.nix
    ./platforms/darwin/base.nix
    ./platforms/nixos/server.nix
    ./platforms/nixos/desktop.nix
  ];
}
