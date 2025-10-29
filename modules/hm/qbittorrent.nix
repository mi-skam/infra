{ config, lib, pkgs, ... }:

let
  platform = import ../lib/platform.nix { inherit pkgs; };
in
{
  home.packages = with pkgs;
    if platform.isDarwin then [
      # qBittorrent GUI app managed via nix-darwin homebrew.casks
    ] else [
      # qBittorrent for Linux
      qbittorrent
    ];
}