{ config, lib, pkgs, pkgs-unstable, ... }:

{
  home.packages = with pkgs;
    if stdenv.isDarwin then [
      # Mullvad CLI tools (GUI app managed via nix-darwin homebrew.casks)
    ] else [
      # Mullvad VPN app for Linux
      pkgs-unstable.mullvad-vpn
    ];
}