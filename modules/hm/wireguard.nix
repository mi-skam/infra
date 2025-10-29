{ config, lib, pkgs, ... }:

let
  platform = import ../lib/platform.nix { inherit pkgs; };
in
{
  home.packages = with pkgs;
    if platform.isDarwin then [
      # WireGuard tools for macOS (GUI app managed via nix-darwin homebrew.casks)
      wireguard-tools
    ] else [
      # WireGuard client and tools for Linux
      wireguard-tools
      # WireGuard GUI client with system tray support
      wireguard-ui
    ];
}