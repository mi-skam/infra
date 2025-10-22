{ config, lib, pkgs, ... }:
let
  cfg = config.mxmlabs.roles.workstation;
in
{
  options.mxmlabs.roles.workstation = {
    enable = lib.mkEnableOption "workstation role configuration";
    
    development = {
      python.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Python development environment";
      };
      go.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Go development environment";
      };
      containers.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable container development tools";
      };
    };
    
    communication.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable communication tools (Slack, Zoom)";
    };
    
    productivity.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable productivity tools";
    };
  };
  
  # Import base modules and development modules unconditionally
  # Platform-specific modules will be imported by the specific machine configs
  imports = [
    ../base/nix-config.nix
    ../development/python.nix
    ../development/go.nix
    ../development/containers.nix
  ];
  
  config = lib.mkIf cfg.enable {
    # Enable base configuration
    mxmlabs.base.nix-config.enable = true;
    
    # Conditionally enable development modules
    mxmlabs.development.python.enable = cfg.development.python.enable;
    mxmlabs.development.go.enable = cfg.development.go.enable;
    mxmlabs.development.containers.enable = cfg.development.containers.enable;
    
    # Platform-agnostic workstation packages
    environment.systemPackages = with pkgs; 
      lib.optionals cfg.communication.enable [
        # Communication tools will be added here
      ] ++ lib.optionals cfg.productivity.enable [
        # Productivity tools will be added here
      ] ++ [
        # Always included for workstations
        git
        direnv
        nix-direnv
      ];
  };
}
