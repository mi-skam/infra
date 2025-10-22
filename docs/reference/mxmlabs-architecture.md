# Architecture Documentation

## Overview

This infrastructure uses a layered, modular approach with Nix Flakes and flake-parts to manage configurations across multiple systems and platforms.

## Directory Structure

```
├── flake.nix                   # Main flake definition
├── parts/                      # flake-parts modules
│   ├── nixos-configurations.nix
│   ├── darwin-configurations.nix  
│   ├── dev-shells.nix
│   ├── packages.nix
│   ├── deploy.nix
│   └── terraform.nix
├── infrastructure/             # System-specific configurations
│   ├── local-machines/         # Development workstations
│   ├── local-server/           # Local hypervisor
│   └── hetzner/                # Cloud infrastructure
└── shared/                     # Reusable modules and configurations
    ├── modules/                # Modular configuration system
    ├── lib/                    # Custom Nix functions
    ├── secrets/                # Encrypted secrets (sops-nix)
    └── packages/               # Custom packages
```

## Module System

The shared module system uses configuration options for maximum flexibility:

### Base Modules
- `base/nix-config.nix` - Core Nix settings, caches, garbage collection
- `base/users.nix` - Common user definitions
- `base/security.nix` - SSH keys, basic security

### Development Modules  
- `development/python.nix` - Python ecosystem (uv, pydantic, httpx)
- `development/go.nix` - Go development tools
- `development/containers.nix` - Docker/Podman setup

### Platform Modules
- `platforms/nixos/` - NixOS-specific configurations
- `platforms/darwin/` - macOS-specific configurations  
- `platforms/home-manager/` - Cross-platform user configs

### Role Modules
- `roles/workstation.nix` - Development machine role
- `roles/server.nix` - Server role with web/database options
- `roles/hypervisor.nix` - VM host role

## Configuration Pattern

All modules follow this pattern:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.mxmlabs.module.name;
in {
  options.mxmlabs.module.name = {
    enable = lib.mkEnableOption "description";
    # Additional options...
  };
  
  config = lib.mkIf cfg.enable {
    # Configuration implementation
  };
}
```

This enables declarative machine configurations like:

```nix
mxmlabs = {
  roles.workstation = {
    enable = true;
    development.python.enable = true;
    development.go.enable = true;
  };
};
```
