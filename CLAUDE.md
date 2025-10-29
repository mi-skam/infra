# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This project manages infrastructure as code using:
- **Nix** for NixOS, Home Manager, and Nix Darwin systems
- **OpenTofu** for Hetzner Cloud infrastructure provisioning
- **Ansible** for configuration management on Debian/Rocky/Ubuntu VPS
- Uses flake-parts for simple, modular organization across multiple hosts with shared modules

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

## Secrets Management

This project uses SOPS (Secrets OPerationS) with age encryption for managing sensitive data like user passwords, API tokens, and SSH keys.

### SOPS Setup Requirements

**CRITICAL:** Before deploying any NixOS system that uses encrypted secrets, you MUST manually deploy the age private key:

```bash
# On the target system, copy your age private key:
sudo mkdir -p /etc/sops/age
sudo cp /path/to/your/age-private-key.txt /etc/sops/age/keys.txt
sudo chmod 600 /etc/sops/age/keys.txt
sudo chown root:root /etc/sops/age/keys.txt
```

**The age private key is never stored in this repository for security reasons.**

### Working with Secrets

```bash
# Edit encrypted secrets
sops secrets/users.yaml
sops secrets/hetzner.yaml  # Hetzner API token

# View decrypted secrets (for debugging)
sops -d secrets/users.yaml
sops -d secrets/hetzner.yaml

# Add new secrets
sops secrets/new-secret.yaml

# Load secrets as environment variables
load-secrets  # Available in nix devshell
```

### Secret Files
- `secrets/users.yaml` - User passwords for NixOS systems
- `secrets/hetzner.yaml` - Hetzner Cloud API token for OpenTofu
- `secrets/ssh-keys.yaml` - SSH keys for various systems
- `secrets/pgp-keys.yaml` - PGP keys for encryption

**Note:** The secrets files in this repository contain test fixtures with placeholder data for CI/CD builds. These allow `nix flake check` and build tests to succeed without requiring production secrets. For production deployments, these files must be replaced with actual encrypted secrets containing real passwords, keys, and tokens.

## Essential Commands

### Development Shell
The project provides a development shell with all tools:

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
- `opentofu` - Infrastructure as Code
- `ansible` - Configuration management
- `just` - Task runner for common operations
- `sops`, `age` - Secrets management
- `git`, `direnv`, `jq` and other tools

### NixOS/Darwin System Management

```bash
# NixOS
sudo nixos-rebuild switch --flake .#xmsi
sudo nixos-rebuild build --flake .#xmsi  # Test without activating

# Darwin
darwin-rebuild switch --flake .#xbook
nix build .#darwinConfigurations.xbook.system  # Test without activating

# Home Manager
home-manager switch --flake .#mi-skam@xmsi
home-manager switch --flake .#plumps@xbook
home-manager build --flake .#user@host  # Test without activating

# Flake management
nix flake update  # Update all inputs
nix flake check   # Validate configuration
```

### Hetzner Infrastructure (OpenTofu)

```bash
# Using justfile (recommended - handles secrets automatically)
just tf-init     # Initialize OpenTofu
just tf-plan     # Preview infrastructure changes
just tf-apply    # Apply infrastructure changes
just tf-import   # Import existing Hetzner resources
just tf-output   # Show outputs (server IPs, etc.)

# Direct OpenTofu (from terraform/ directory)
cd terraform
export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep hcloud_token | cut -d: -f2 | xargs)"
tofu init
tofu plan
tofu apply
```

**First-time setup:**
1. Edit the Hetzner API token: `sops secrets/hetzner.yaml`
2. Initialize OpenTofu: `just tf-init`
3. Import existing resources: `just tf-import`
4. Verify with plan: `just tf-plan` (should show no changes)

### Ansible Configuration Management

```bash
# Using justfile (recommended)
just ansible-ping            # Test connectivity to all servers
just ansible-bootstrap       # Bootstrap new servers (initial setup)
just ansible-deploy          # Deploy configurations to all servers
just ansible-deploy-env prod # Deploy only to prod
just ansible-deploy-env dev  # Deploy only to dev
just ansible-inventory       # List all managed servers

# Direct Ansible (from ansible/ directory)
cd ansible
ansible all -m ping
ansible-playbook playbooks/bootstrap.yaml
ansible-playbook playbooks/deploy.yaml
ansible-playbook playbooks/deploy.yaml --limit prod
ansible-playbook playbooks/deploy.yaml --check --diff  # Dry run
```

### Other Useful Commands

```bash
# List all available just recipes
just

# Update Ansible inventory from Terraform
just ansible-inventory-update

# Update flake inputs
nix flake update

# Check flake configuration
nix flake check

# View Hetzner infrastructure
hcloud server list
hcloud network list
hcloud ssh-key list
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

## Infrastructure Overview

### Managed Systems

**Local/Development:**
- `xbook` (macOS ARM64) - Darwin + Home Manager
- `xmsi` (x86_64 NixOS) - Desktop workstation
- `srv-01` (x86_64 NixOS) - Local server (configuration only, not deployed)

**Hetzner Cloud VPS (managed via OpenTofu + Ansible):**
- `mail-1.prod.nbg` - Debian 12, CAX21 (ARM64, 4 cores, 8GB), mail server
- `syncthing-1.prod.hel` - Rocky Linux 9, CAX11 (ARM64, 2 cores, 4GB), syncthing
- `test-1.dev.nbg` - Ubuntu 24.04, CAX11 (ARM64, 2 cores, 4GB), test environment

**Hetzner Network:**
- Private network: `homelab` (10.0.0.0/16)
- Subnet: 10.0.0.0/24 (eu-central)
- SSH key: `homelab-hetzner`

### Directory Structure

```
infra/
├── terraform/              # Hetzner infrastructure as code
│   ├── providers.tf
│   ├── variables.tf
│   ├── network.tf
│   ├── servers.tf
│   ├── outputs.tf
│   └── import.sh           # Import existing resources
├── ansible/                # Configuration management
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yaml      # Server inventory (from Terraform)
│   │   └── group_vars/     # Environment/group variables
│   ├── playbooks/
│   │   ├── bootstrap.yaml  # Initial server setup
│   │   └── deploy.yaml     # Main deployment
│   └── roles/
│       ├── common/         # Base configuration
│       └── monitoring/     # (Optional) Observability
├── hosts/                  # NixOS/Darwin configurations
│   ├── xbook/
│   ├── xmsi/
│   └── srv-01/
├── modules/                # Reusable Nix modules
│   ├── nixos/
│   ├── darwin/
│   └── home/
├── secrets/                # SOPS-encrypted secrets
│   ├── users.yaml
│   ├── hetzner.yaml
│   ├── ssh-keys.yaml
│   └── pgp-keys.yaml
├── flake.nix               # Main flake definition
├── devshell.nix            # Development environment
└── justfile                # Task automation
```

## Technical Advice

### Nix Flakes
- If Nix Flakes sees that it's dealing with files in a git repository, those files and hence the changes need to be on the git index to be picked up!
- Always stage your changes with `git add` before running Nix commands

### OpenTofu State Management
- Terraform state is stored locally in `terraform/terraform.tfstate`
- **Never commit state files** - they may contain sensitive data
- State files are already in `.gitignore`
- For production, consider remote state backend (S3, Terraform Cloud, etc.)

### Ansible Best Practices
- Always use the private network IPs (10.0.0.x) for connections
- Test with `--check` flag before applying changes
- Use `--limit` to target specific environments or hosts
- Ansible facts are cached in `/tmp/ansible_facts` for performance

### Hybrid Management Strategy
- **NixOS hosts** (xmsi, srv-01): Managed via Nix flakes
- **Debian/Rocky/Ubuntu VPS**: Managed via OpenTofu (infrastructure) + Ansible (configuration)
- Both can run side-by-side without conflicts
- Use appropriate tool for each system type