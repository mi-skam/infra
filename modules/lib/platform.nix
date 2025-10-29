{ pkgs }:

{
  # Platform detection utilities for cross-platform Nix configurations
  # Usage: let platform = import ../lib/platform.nix { inherit pkgs; }; in
  #        if platform.isDarwin then ... else ...

  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  isAarch64 = pkgs.stdenv.isAarch64;
  isx86_64 = pkgs.stdenv.isx86_64;
}
