# Infrastructure as Code

This repository manages infrastructure using:
- **Nix** for NixOS, Home Manager, and Nix Darwin systems (local workstations)
- **OpenTofu** for Hetzner Cloud infrastructure provisioning
- **Ansible** for Debian/Rocky/Ubuntu VPS configuration management

Uses flake-parts for clean, modular organization across multiple hosts with shared modules.

## Features

- **Hybrid Infrastructure**: Manage both NixOS systems and traditional VPS
- **Secrets Management**: SOPS with Age encryption for all sensitive data
- **Automated Backups**: Hetzner Storage Box integration with Mailcow backups
- **Dynamic Inventory**: Ansible inventory automatically generated from Terraform
- **Role-Based Grouping**: Servers grouped by role (mail, syncthing, etc.)

## Architecture

The project uses **completely decoupled** configurations:
- **System Configurations**: Handle OS-level setup, users, and system services
- **Home Configurations**: Handle user dotfiles, applications, and personal settings
- **Development Shells**: Handle development environments
- **Cloud Infrastructure**: OpenTofu for Hetzner Cloud resources
- **Configuration Management**: Ansible for VPS setup and maintenance

### Module Organization
- `modules/nixos/`: NixOS-specific system configurations
- `modules/darwin/`: macOS-specific configurations
- `modules/home/`: Cross-platform Home Manager modules
- `modules/users/`: System-only user account definitions
- `terraform/`: Hetzner Cloud infrastructure as code
- `ansible/`: VPS configuration management
- `secrets/`: Encrypted secrets (SOPS)

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

## Initial Setup

After cloning the repository, you'll need to set up secrets management:

### 1. Generate Age Encryption Key
```shell
# Create age key directory
mkdir -p ~/.config/sops/age

# Generate new age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Note your public key for adding to .sops.yaml
# Example: age13un6j66l3x70f3yc4lwjuvj6d95g7aaq2xj5pjugg0m9up7jcces6xtv4u
```

### 2. Update Secrets Configuration
Add your public age key to `.sops.yaml`:
```yaml
keys:
  - &your-name age13un6j66l3x70f3yc4lwjuvj6d95g7aaq2xj5pjugg0m9up7jcces6xtv4u

creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *your-name
```

### 3. Re-encrypt Existing Secrets
```shell
# Update encryption for your key
sops updatekeys secrets/ssh-keys.yaml
```

### 4. Backup Your Age Key ⚠️
```shell
# CRITICAL: Backup your private key securely!
cp ~/.config/sops/age/keys.txt ~/backup/age-key-backup.txt
# Store in a secure location - if lost, secrets become unrecoverable!
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

## Managed Infrastructure

### Local/Development Hosts
- **xmsi**: x86_64 NixOS workstation with MSI hardware profile (managed via Nix)
- **xbook**: ARM64 Darwin machine (Apple Silicon) (managed via Nix)
- **srv-01**: x86_64 NixOS local server (configuration only, not deployed)

### Hetzner Cloud VPS (OpenTofu + Ansible)
- **mail-1.prod.nbg**: Debian 12, CAX21 (ARM64, 4 cores, 8GB) - Mailcow mail server
  - Automated nightly backups to Hetzner Storage Box
  - Automatic updates with garbage collection
- **syncthing-1.prod.hel**: Rocky Linux 9, CAX11 (ARM64, 2 cores, 4GB) - Syncthing
- **test-1.dev.nbg**: Ubuntu 24.04, CAX11 (ARM64, 2 cores, 4GB) - Test environment

**Network:**
- Private network: `homelab` (10.0.0.0/16)
- Subnet: 10.0.0.0/24 (eu-central)
- All servers connected via private network

### Hetzner Cloud Management

```shell
# View infrastructure
just tf-output
hcloud server list
hcloud network list

# Make infrastructure changes
just tf-plan    # Preview changes
just tf-apply   # Apply changes

# Deploy configuration to VPS
just ansible-ping           # Test connectivity
just ansible-deploy deploy  # Deploy configurations
just ansible-deploy-env prod  # Deploy only to production

# Backup management
just ansible-deploy mailcow-backup  # Run backup and setup cron
```

## Development Tools
The development shell provides:
- **Nix tools**: `nixos-rebuild`, `darwin-rebuild`, `home-manager`
- **Infrastructure**: `opentofu` (Terraform), `ansible`, `hcloud` CLI
- **Automation**: `just` task runner with common operations
- **Secrets**: `sops`, `age` for encrypted secrets management
- **Utilities**: `git`, `direnv`, `jq`, and other development tools

## Secrets Management

This repository uses [sops-nix](https://github.com/Mic92/sops-nix) with [age](https://age-encryption.org/) for encrypted secrets management.

### Managing Secrets
```shell
# Edit encrypted secrets (opens in $EDITOR)
sops secrets/ssh-keys.yaml

# View decrypted content
sops -d secrets/ssh-keys.yaml

# Create new secrets file
sops secrets/new-file.yaml

# Generate new age key
age-keygen -o new-key.txt

# Re-encrypt for new recipients
sops updatekeys secrets/ssh-keys.yaml
```

### Secrets Structure
```
secrets/
├── hetzner.yaml        # Hetzner Cloud API token
├── storagebox.yaml     # Hetzner Storage Box credentials
└── .sops.yaml          # SOPS configuration (age keys)
```

**Note:** All secrets are encrypted with SOPS and safe to commit to git.

### Adding New Secrets
1. Edit or create encrypted file: `sops secrets/filename.yaml`
2. Add secret deployment to `modules/home/secrets.nix`
3. Deploy with `infra home`

### Security Model
- **Encrypted at rest**: Safe to commit encrypted files to git
- **Decrypted at deploy**: Only during `infra home` execution
- **Access control**: Age private key = access to secrets
- **Runtime storage**: Decrypted secrets in `/run/user/*/secrets/`