{ config, lib, pkgs, ... }:
let
  cfg = config.mxmlabs.base.nix-config;
in
{
  options.mxmlabs.base.nix-config = {
    enable = lib.mkEnableOption "Nix configuration";
    
    experimentalFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nix-command" "flakes" ];
      description = "Experimental Nix features to enable";
    };
    
    binaryCaches = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable additional binary caches";
      };
    };
    
    garbageCollection = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic garbage collection";
      };
      frequency = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "Garbage collection frequency";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    nix = {
      settings = {
        experimental-features = cfg.experimentalFeatures;
        trusted-users = [ "root" "@wheel" "plumps"];
      } // lib.optionalAttrs cfg.binaryCaches.enable {
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
      
      # Use new optimise option instead of auto-optimise-store
      optimise = lib.mkIf cfg.garbageCollection.enable {
        automatic = true;
      };
      
      gc = lib.mkIf cfg.garbageCollection.enable {
        automatic = true;
        options = "--delete-older-than 30d";
      };
    };
  };
}
