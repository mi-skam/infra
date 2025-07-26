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

## Hosts
- **xmsi**: x86_64 NixOS workstation with MSI hardware profile
- **xbook**: ARM64 Darwin machine (Apple Silicon)

## Development Tools
The development shell provides:
- All rebuild tools (`nixos-rebuild`, `darwin-rebuild`, `home-manager`)
- Infrastructure management (`infra` command)
- Secrets management (`sops`, `age`)
- Git, direnv, and other development utilities

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
├── ssh-keys.yaml       # SSH private/public keys
├── api-keys.yaml       # API tokens and keys
└── passwords.yaml      # Passwords and credentials
```

### Adding New Secrets
1. Edit or create encrypted file: `sops secrets/filename.yaml`
2. Add secret deployment to `modules/home/secrets.nix`
3. Deploy with `infra home`

### Security Model
- **Encrypted at rest**: Safe to commit encrypted files to git
- **Decrypted at deploy**: Only during `infra home` execution
- **Access control**: Age private key = access to secrets
- **Runtime storage**: Decrypted secrets in `/run/user/*/secrets/`