{ pkgs, lib, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in {
  imports = [
    ./common.nix
  ];

  programs = {
    firefox.enable = isLinux;
    ghostty.enable = isLinux;
  };

  home.packages = with pkgs; 
    # Common packages for both platforms
    [
      brave
      obsidian
      vivaldi
    ] 
    # Linux-only packages
    ++ lib.optionals isLinux [
      bitwarden-desktop
      freecad-wayland
      signal-desktop
      spotify-qt
      kdePackages.kasts
    ]
    # Darwin-specific packages
    ++ lib.optionals isDarwin [
      # Add macOS-specific alternatives if needed
      # For example, you might want to use the native macOS app for Spotify
      # instead of spotify-qt
    ];
}
