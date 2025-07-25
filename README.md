# Infrastructure as Code

This repository manages infrastructure using Nix for NixOS, Home Manager, and Nix Darwin systems. It uses flake-parts for clean, modular organization across multiple hosts with shared modules.

## Architecture

The project uses **completely decoupled** configurations:
- **System Configurations**: Handle OS-level setup, users, and system services
- **Home Configurations**: Handle user dotfiles, applications, and personal settings  
- **Development Shells**: Handle development environments

### Module Organization
- `modules/nixos/`: NixOS-specific system configurations
- `modules/darwin/`: macOS-specific configurations  
- `modules/home/`: Cross-platform Home Manager modules
- `modules/users/`: System-only user account definitions
- `secrets/`: SSH keys and other sensitive configuration

## Quick Start

```shell
# Clone the repository
git clone ssh://git@git.adminforge.de:222/maksim/infrastructure.git
cd infrastructure

# Enter development shell (includes all tools)
nix develop
# or use direnv for automatic activation
direnv allow
```

## Usage

### System Rebuilds
```shell
# NixOS (requires sudo)
sudo nixos-rebuild switch --flake .#$(hostname)

# Darwin
darwin-rebuild switch --flake .#$(hostname)
```

### Home Manager
```shell
# Switch to home configuration
home-manager switch --flake .#mi-skam@xmsi      # Linux
home-manager switch --flake .#plumps@xbook      # Darwin

# Build without activation
home-manager build --flake .#username@hostname
```

### Simplified Management
The development shell includes an `infra` command for easier management:

```shell
infra update           # Update flake inputs
infra upgrade          # Upgrade current host (auto-detected)
infra upgrade xbook    # Upgrade specific host
infra home            # Update home configuration
```

### Build Testing
```shell
# Test builds without activation
nixos-rebuild build --flake .#xmsi
darwin-rebuild build --flake .#xbook
```

## Hosts
- **xmsi**: x86_64 NixOS workstation with MSI hardware profile
- **xbook**: ARM64 Darwin machine (Apple Silicon)

## Development Tools
The development shell provides:
- All rebuild tools (`nixos-rebuild`, `darwin-rebuild`, `home-manager`)
- Infrastructure management (`infra` command)
- Git, direnv, and other development utilities