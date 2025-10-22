{ config, lib, pkgs, ... }:

{
  config = {
    # Link the ghostty config from dotfiles directory
    xdg.configFile."ghostty/config".source = ../../dotfiles/ghostty/config;
    
    # Install ghostty package if available
    home.packages = lib.optionals (pkgs ? ghostty) [
      pkgs.ghostty
    ];
  };
}