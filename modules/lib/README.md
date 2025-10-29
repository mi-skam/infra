# Shared Library Modules

This directory contains reusable Nix module patterns extracted from the infrastructure codebase to reduce code duplication and improve maintainability.

## Overview

The shared libraries in this directory provide common functionality that can be imported by both system modules (NixOS/Darwin) and home-manager modules. They follow Nix module best practices with clear options definition, config implementation, and proper platform abstraction.

## Available Libraries

### mkUser.nix - User Account Builder

A function that creates standardized user account configurations with platform-specific handling for Darwin and Linux systems.

**Purpose**: Eliminates duplicate user account definitions by providing a single function that generates the appropriate configuration for both Darwin and NixOS systems.

**Parameters**:
- `name` (string, required): Username for the account
- `uid` (integer, required): User ID (UID)
- `description` (string, required): Full name or description of the user
- `secretName` (string, required): Name of the SOPS secret containing the user's password
- `groups` (list, optional): Additional groups for Linux systems. Defaults to: `["audio" "docker" "input" "libvirtd" "networkmanager" "sound" "tty" "video" "wheel"]`

**Return Value**: A Nix module containing:
- `users.users.<name>` configuration with platform-specific settings
- `users.mutableUsers = false` (system-level setting)

**Platform Handling**:
- **Common** (all platforms): UID, shell (fish), SSH authorized keys
- **Darwin only**: Home directory path (`/Users/<name>`)
- **Linux only**: Description, isNormalUser flag, extraGroups, hashed password from SOPS

**Example Usage**:

```nix
# modules/users/example-user.nix
{
  pkgs,
  config,
  lib,
  ...
}:
let
  userLib = import ../lib/mkUser.nix { inherit lib pkgs config; };
in
userLib.mkUser {
  name = "example-user";
  uid = 1002;
  description = "Example User";
  secretName = "example-user";
  # Optional: override default groups
  # groups = [ "wheel" "docker" ];
}
```

**Code Reduction**: Using this library reduces user module size from ~44 lines to ~15 lines (66% reduction).

### system-common.nix - Common System Configuration

A module that provides shared system-level configuration settings used across both NixOS and Darwin systems.

**Purpose**: Eliminates duplicate system configuration boilerplate by providing a single source of common settings.

**Provides**:
- **Nix settings**: Experimental features (flakes, nix-command)
- **Package management**: allowUnfree configuration
- **Time zone**: Europe/Berlin
- **Shell configuration**: Fish shell enabled, command-not-found disabled

**Platform Compatibility**: All settings in this module are cross-platform compatible. Platform-specific settings should remain in the respective system modules (nixos/common.nix, darwin/common.nix).

**Example Usage**:

```nix
# modules/nixos/common.nix or modules/darwin/common.nix
{ inputs, ... }:
{
  imports = [
    ../lib/system-common.nix
    # ... other imports
  ];

  # Add platform-specific settings here
}
```

**Code Reduction**: Using this library reduces duplication of 11 lines across 2 system modules (22 total lines eliminated).

## Design Principles

1. **DRY (Don't Repeat Yourself)**: Extract common patterns that appear in multiple modules
2. **Platform Abstraction**: Use `lib.mkIf` with `pkgs.stdenv.isDarwin`/`isLinux` for platform-specific logic
3. **Minimal and Focused**: Each library has a single, clear purpose
4. **Composable**: Libraries can be combined with other modules without conflicts
5. **Documentation**: Each library includes clear parameter descriptions and usage examples

## Testing

After modifying shared libraries, test with the following commands:

```bash
# Check syntax
nix-instantiate --parse modules/lib/mkUser.nix
nix-instantiate --parse modules/lib/system-common.nix

# Validate flake configuration
nix flake check

# Build specific configurations
nix build '.#nixosConfigurations.xmsi.config.system.build.toplevel' --no-link
nix build '.#darwinConfigurations.xbook.system' --no-link
```

## Contributing

When adding new shared libraries:

1. Ensure at least 3 modules would benefit from the abstraction
2. Follow 2-space indentation and alphabetically sorted imports
3. Document all parameters and provide usage examples
4. Update this README with the new library documentation
5. Update the module dependency graph at `docs/diagrams/nix_module_dependencies_refactored.dot`
6. Test all affected configurations before committing
