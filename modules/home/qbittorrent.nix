{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs;
    if stdenv.isDarwin then [
      # qBittorrent GUI app managed via nix-darwin homebrew.casks
    ] else [
      # qBittorrent for Linux
      qbittorrent
    ];
}