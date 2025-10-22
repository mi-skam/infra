# Containers development module
{ config, lib, pkgs, ... }:
let
  cfg = config.mxmlabs.development.containers;
in
{
  options.mxmlabs.development.containers = {
    enable = lib.mkEnableOption "Container development tools";
  };
  
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      docker
      docker-compose
      podman
    ];
  };
}
