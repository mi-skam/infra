{ pkgs, lib, ... }:
{
  # Common nix settings (cross-platform)
  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];
  nixpkgs.config.allowUnfree = true;

  # Time zone configuration (cross-platform)
  time.timeZone = "Europe/Berlin";

  # Shell configuration (cross-platform)
  programs.command-not-found.enable = false;
  programs.fish.enable = true;
}
