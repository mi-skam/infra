# Placeholder for Go development module
{ config, lib, pkgs, ... }:
{
  options.mxmlabs.development.go = {
    enable = lib.mkEnableOption "Go development environment";
  };
  
  config = lib.mkIf config.mxmlabs.development.go.enable {
    environment.systemPackages = with pkgs; [
      go
      gopls
      gotools
    ];
  };
}
