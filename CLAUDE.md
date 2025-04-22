# CLAUDE.md - Nix Infrastructure Project

## Project Overview
This project manages infrastructure as code using Nix for NixOS, Home Manager, and Nix Darwin systems. We use the Blueprint framework to organize our configurations across multiple hosts.

## Project Structure
- `flake.nix`: Main entry point defining inputs, outputs, and system configurations
- `hosts/`: Machine-specific configurations
  - `lt-01/`: Darwin machine configuration
  - `lt-02/`: NixOS machine configuration
  - Each host has its own user configuration in a `users/` subdirectory
- `modules/`: System-specific modules
  - `darwin/`: Darwin-specific configurations
  - `home/`: Home Manager configurations
  - `nixos/`: NixOS-specific configurations
- `authorized_keys`: SSH public keys
- `devshell.nix`: Development environment configuration

## Coding Standards
- 2-space indentation
- Sort imports alphabetically
- Type annotations for functions
- Follow Blueprint framework patterns

## Blueprint Framework
When working with our Blueprint framework:
1. Use the established templates in modules directories
2. Follow the component-based architecture
3. Leverage Blueprint's inheritance system for configuration sharing
4. Use Blueprint's secret management for credentials

## GitHub Fetching
```nix
# Preferred method
inputs.somepackage = {
  url = "github:owner/repo/rev";
  flake = true;
};

# For non-flake sources
pkgs.fetchFromGitHub {
  owner = "username";
  repo = "repo-name";
  rev = "commit-hash";
  sha256 = "sha256-hash";
}
```

## Multi-System Support
- Use system-specific modules in the appropriate directories (`modules/darwin/`, `modules/nixos/`)
- Common Home Manager configurations in `modules/home/`
- Use Blueprint's system detection for cross-platform modules

## Testing
- For NixOS hosts: `nixos-rebuild build --flake .#lt-02`
- For Darwin hosts: `darwin-rebuild build --flake .#lt-01`
- For Home Manager: `home-manager build --flake .#username@hostname`

When assisting with this codebase, prioritize Blueprint framework patterns and maintain compatibility across the system-specific module directories.