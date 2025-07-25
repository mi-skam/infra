# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This project manages infrastructure as code using Nix for NixOS, Home Manager, and Nix Darwin systems. Uses flake-parts for simple, modular organization across multiple hosts with shared modules.

## Architecture

### Flake Structure
The project uses flake-parts framework for clean organization. Key inputs include nixpkgs-24.11, nix-darwin-24.11, home-manager-24.11, nixos-hardware, and srvos. Configurations are **completely decoupled** - each can be built and deployed independently.

### Decoupled Configuration Types
1. **System Configurations**: Handle OS-level setup, users, and system services
2. **Home Configurations**: Handle user dotfiles, applications, and personal settings  
3. **Development Shells**: Handle development environments

### Module Organization
- `modules/nixos/`: NixOS-specific system configurations (common.nix for base setup, desktop.nix/plasma.nix for GUI, server.nix)
- `modules/darwin/`: macOS-specific configurations with darwin system defaults
- `modules/home/`: Cross-platform Home Manager modules with conditional logic for Darwin/Linux
  - `modules/home/users/`: Home-manager-only user configuration (username, email, stateVersion)
- `modules/users/`: System-only user account definitions (groups, SSH keys, passwords)

### Host Configuration Pattern
System hosts only handle OS and user accounts:
- `hosts/xbook/`: ARM64 Darwin machine using plumps user, imports `../../modules/darwin/desktop.nix`
- `hosts/xmsi/`: x86_64 NixOS machine with MSI hardware profile using mi-skam user, imports `../../modules/nixos/{desktop,plasma}.nix`

### Separated User Management
- **System users** (`modules/users/`): Account creation, groups, SSH keys, passwords
- **Home users** (`modules/home/users/`): Personal settings, dotfiles configuration, user preferences

### Cross-Platform Home Manager
The `modules/home/common.nix` implements cross-platform logic using `pkgs.stdenv.isDarwin/isLinux` for platform-specific configuration (home directories, SSH agent, package selection). Home configurations include their own nixpkgs with allowUnfree enabled.

## Essential Commands

### System Rebuilds
```bash
# NixOS (requires sudo)
sudo nixos-rebuild switch --flake .#$(hostname)

# Darwin
darwin-rebuild switch --flake .#$(hostname)
```

### Build Testing (no activation)
```bash
# NixOS
nixos-rebuild build --flake .#xmsi

# Darwin
darwin-rebuild build --flake .#xbook
```

### Home Manager
```bash
home-manager switch --flake .#mi-skam@xmsi
home-manager switch --flake .#plumps@xbook
home-manager build --flake .#username@hostname
```

### Development Shell
The project provides a convenient development shell with all rebuild tools:

```bash
# Enter development shell manually
nix develop

# Or use direnv for automatic activation (recommended)
direnv allow  # First time only, then automatic when entering directory
```

**Development shell includes:**
- `nixos-rebuild` - Build NixOS configurations
- `darwin-rebuild` - Build Darwin configurations (macOS only)
- `home-manager` - Build Home Manager configurations
- `infra` - Simplified infrastructure management with auto-detection
- `git`, `direnv` and other development tools

**Simplified infrastructure management:**
```bash
# Update and upgrade commands
infra update           # Update flake inputs
infra upgrade          # Upgrade current host (auto-detected)
infra upgrade xbook    # Upgrade specific host

# Traditional tools still available
nixos-rebuild build --flake .#xmsi
home-manager switch --flake .#mi-skam@xmsi
```

### Other Development Commands
```bash
# Update flake inputs
nix flake update

# Check flake configuration
nix flake check
```

## Scripts
The `scripts/` directory contains VM management utilities, primarily `create-vm-darwin.sh` for creating QEMU VM launchers on macOS ARM64.

## Coding Standards
- 2-space indentation
- Sort imports alphabetically
- Use direct relative imports instead of flake outputs
- Use platform detection (`isDarwin`/`isLinux`) for cross-platform modules
- **Maintain strict separation**: System modules handle OS concerns, home modules handle user concerns
- System user modules (`modules/users/`) only define accounts, groups, SSH keys
- Home user modules (`modules/home/users/`) only define personal settings and userConfig

## Decoupled Deployment Benefits
- **Independent Updates**: Update system without affecting user configurations
- **Multi-User Support**: Each user can manage their own home configuration
- **Simplified Debugging**: System and home issues are isolated
- **Flexible CLI Usage**: Use appropriate CLI tool for each configuration type

## Technical Advise for Nix Flakes
- If Nix Flakes sees that it's dealing with files in a git repository, those files and hence the changes need to be on the git index to be picked up!