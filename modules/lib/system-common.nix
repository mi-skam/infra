{ pkgs, lib, ... }:
{
  # Common nix settings (cross-platform)
  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];
  nixpkgs.config.allowUnfree = true;

  # Time zone configuration (Linux only - Darwin handles this via system.defaults)
  time.timeZone = lib.mkIf pkgs.stdenv.isLinux "Europe/Berlin";

  # Shell configuration (cross-platform)
  programs.fish.enable = true;
}
