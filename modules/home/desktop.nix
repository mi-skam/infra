{ pkgs, pkgs-unstable, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  imports = [
    ./common.nix
    ./qbittorrent.nix
    ./ghostty.nix
  ];

  programs = {
    firefox.enable = isLinux;
    ghostty.enable = isLinux;
  };


  home.packages =
    with pkgs;
    # Common packages available in nixpkgs for both platforms
    [
      # Keep packages that work well from nixpkgs on both platforms
      pkgs-unstable.obsidian
    ]
    # Linux-only packages (GUI apps via nixpkgs)
    ++ lib.optionals isLinux [
      brave
      vivaldi
      bitwarden-desktop
      freecad-wayland
      signal-desktop
      spotify-qt
      kdePackages.kasts
      wl-clipboard
    ]
    # Darwin-specific packages (minimal, most GUI apps via Homebrew casks)
    ++ lib.optionals isDarwin [
      # Keep only packages that work better from nixpkgs on Darwin
      # Most GUI apps are handled by Homebrew casks
    ];
}
