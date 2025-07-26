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
    ]
    # Darwin-specific packages  
    ++ lib.optionals isDarwin [
      pkgs-unstable.obsidian
      # Keep only packages that work better from nixpkgs on Darwin
      # Most GUI apps are handled by Homebrew casks
    ]
    # Linux-only packages (GUI apps via nixpkgs)
    ++ lib.optionals isLinux [
      brave
      vivaldi
      freecad-wayland
      kdePackages.kasts
      wl-clipboard
    ];

}
