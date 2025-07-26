{ config, lib, pkgs-unstable, ... }:

{
  services.mullvad-vpn = {
    enable = true;
    package = pkgs-unstable.mullvad-vpn;  # Use the Mullvad VPN package from latest Nixpkgs
  };
}