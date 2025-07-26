{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs;
    if stdenv.isDarwin then [
      # WireGuard tools for macOS (GUI app managed via nix-darwin homebrew.casks)
      wireguard-tools
    ] else [
      # WireGuard client and tools for Linux
      wireguard-tools
      # WireGuard GUI client with system tray support
      wireguard-ui
    ];
}