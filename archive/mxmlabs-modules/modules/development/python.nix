{ config, lib, pkgs, ... }:
let
  cfg = config.mxmlabs.development.python;
in
{
  options.mxmlabs.development.python = {
    enable = lib.mkEnableOption "Python development environment";
    
    version = lib.mkOption {
      type = lib.types.str;
      default = "311";
      description = "Python version to use";
    };
    
    packages = {
      pydantic.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include Pydantic for data validation";
      };
      httpx.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include HTTPX for HTTP requests";
      };
    };
    
    tools = {
      linting.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable linting tools (ruff, mypy)";
      };
      testing.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable testing frameworks";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Core Python setup based on your preferences
      uv
      pkgs."python${cfg.version}"
    ] ++ lib.optionals cfg.packages.pydantic.enable [
      pkgs."python${cfg.version}Packages".pydantic
    ] ++ lib.optionals cfg.packages.httpx.enable [
      pkgs."python${cfg.version}Packages".httpx
    ] ++ lib.optionals cfg.tools.linting.enable [
      ruff
      mypy
    ] ++ lib.optionals cfg.tools.testing.enable [
      pkgs."python${cfg.version}Packages".pytest
      pkgs."python${cfg.version}Packages".pytest-cov
    ];
    
    # Environment variables
    environment.variables = {
      UV_CACHE_DIR = "$HOME/.cache/uv";
      PYTHONPATH = "$HOME/.local/lib/python${cfg.version}/site-packages:$PYTHONPATH";
    };
  };
}
