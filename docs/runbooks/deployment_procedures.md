# Deployment Procedures Runbook

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Pre-Deployment Checklist](#3-pre-deployment-checklist)
4. [NixOS System Deployment](#4-nixos-system-deployment)
5. [Darwin System Deployment](#5-darwin-system-deployment)
6. [Home Manager Deployment](#6-home-manager-deployment)
7. [Terraform Infrastructure Deployment](#7-terraform-infrastructure-deployment)
8. [Ansible VPS Configuration](#8-ansible-vps-configuration)
9. [Combined Deployment Scenarios](#9-combined-deployment-scenarios)
10. [Emergency Rollback Procedures](#10-emergency-rollback-procedures)
11. [Common Issues and Troubleshooting](#11-common-issues-and-troubleshooting)
12. [Related Documentation](#12-related-documentation)

---

## 1. Overview

### Purpose

This runbook provides comprehensive step-by-step procedures for deploying configurations to all systems managed by this infrastructure repository. It covers five deployment types with detailed validation gates, verification steps, and rollback procedures.

### When to Use This Runbook

- **NixOS system changes**: Deploying OS-level configuration to NixOS hosts (xmsi, srv-01)
- **Darwin system changes**: Deploying macOS configuration to Darwin hosts (xbook)
- **Home Manager updates**: Deploying user environment configuration for any user
- **Infrastructure provisioning**: Creating or modifying Hetzner Cloud resources
- **VPS configuration**: Deploying configuration to Debian/Rocky/Ubuntu servers

### Deployment Types Covered

1. **NixOS System Deployment**: System configuration, services, users, packages (managed via Nix flakes)
2. **Darwin System Deployment**: macOS system configuration (managed via nix-darwin)
3. **Home Manager Deployment**: User environment, dotfiles, applications (cross-platform)
4. **Terraform Infrastructure**: Hetzner Cloud servers, networks, SSH keys (managed via OpenTofu)
5. **Ansible VPS Configuration**: Configuration management for non-NixOS VPS (managed via Ansible)

### Validation Gates Pattern

All deployment types follow a comprehensive validation gate pattern to catch errors before deployment:

1. **Gate 1**: Secrets validation (encrypted, formatted correctly)
2. **Gate 2**: Git staging validation (Nix only - unstaged changes are silently ignored)
3. **Gate 3**: Syntax validation (nix flake check / tofu validate / ansible --syntax-check)
4. **Gate 4**: Dry-run build/plan (shows what would change without applying)
5. **Gate 5**: User confirmation (unless force mode enabled)

Each gate must pass before proceeding. Failure at any gate stops deployment with actionable error messages.

**Reference**: These validation gates are implemented in the justfile (refactored in I4.T1, enhanced in I4.T2).

### Safety Features

- **Dry-run before apply**: All deployment types show what would change before applying
- **Confirmation prompts**: Required for destructive operations (can be skipped with force flag)
- **Rollback support**: All deployment types support rollback to previous state
- **State validation**: Pre-deployment checks ensure system is in valid state
- **Clear error messages**: Validation failures provide actionable remediation steps

---

## 2. Prerequisites

### Required Access

- [x] Git repository write access
- [x] SSH access to target systems (with public key authentication)
- [x] Root/sudo access on NixOS/Darwin systems
- [x] SOPS age private key at `~/.config/sops/age/keys.txt`
- [x] Hetzner Cloud Console access (for infrastructure operations)

### Required Tools

All tools are available in the nix development shell:

```bash
# Enter development shell
nix develop

# Or use direnv (recommended - automatic activation)
direnv allow
```

Tools included:
- `nixos-rebuild` - NixOS system deployment
- `darwin-rebuild` - Darwin system deployment (macOS only)
- `home-manager` - Home Manager deployment
- `opentofu` / `tofu` - Infrastructure provisioning
- `ansible` / `ansible-playbook` - VPS configuration management
- `just` - Task automation (all deployment commands)
- `sops`, `age` - Secrets management
- `git`, `ssh`, `scp` - Version control and remote access

### Environment Setup

```bash
# Verify you're in the repository root
pwd
# Expected: /Users/plumps/Share/git/mi-skam/infra

# Verify direnv is active (look for nix shell indicator in prompt)
# Or verify tools are available
which just nixos-rebuild darwin-rebuild home-manager tofu ansible

# Verify SOPS can decrypt secrets
sops -d secrets/hetzner.yaml | head -3

# Expected: Decrypted YAML content
# If error: Check age key exists at ~/.config/sops/age/keys.txt
```

### System-Specific Requirements

**NixOS systems:**
- Age private key deployed to `/etc/sops/age/keys.txt` (see `docs/runbooks/age_key_bootstrap.md`)
- Root access via SSH or local sudo

**Darwin systems:**
- Age private key at `/opt/homebrew/etc/sops/age/keys.txt` (Apple Silicon) or `/usr/local/etc/sops/age/keys.txt` (Intel)
- Admin user with sudo access

**Hetzner Cloud:**
- Valid API token in `secrets/hetzner.yaml` (Read & Write permissions)
- Terraform state initialized (`just tf-init`)

**VPS systems:**
- SSH access configured in `ansible/inventory/hosts.yaml`
- Python installed on target systems (Ansible requirement)

---

## 3. Pre-Deployment Checklist

Use this universal checklist before any deployment. Check off items as you complete them.

### General Readiness

```markdown
## Pre-Deployment Checklist

**Date**: YYYY-MM-DD
**Deployment type**: <NixOS / Darwin / Home Manager / Terraform / Ansible>
**Target**: <hostname / environment>
**Operator**: <Your name>

### Environment
- [ ] Working in repository root directory
- [ ] Nix devshell active (or direnv loaded)
- [ ] All required tools available (just, nix, tofu, ansible)

### Secrets
- [ ] Age private key accessible (`~/.config/sops/age/keys.txt`)
- [ ] Secrets decrypt successfully (`just validate-secrets`)
- [ ] No unencrypted secrets in repository

### Git Status
- [ ] All changes committed OR staged with `git add` (critical for Nix deployments)
- [ ] No unexpected uncommitted changes
- [ ] Working tree clean or only intended changes present
- [ ] On correct branch (main or feature branch)

### Syntax Validation
- [ ] Nix syntax check passes (`nix flake check`) [NixOS/Darwin/Home Manager only]
- [ ] Terraform syntax valid (`just tf-validate`) [Terraform only]
- [ ] Ansible syntax check passes (`just ansible-syntax-check <playbook>`) [Ansible only]

### Dry-Run Testing
- [ ] Dry-run build succeeded (shows what would be built/changed)
- [ ] Reviewed dry-run output for unexpected changes
- [ ] Confirmed all intended changes present in dry-run

### Backup and Rollback Preparation
- [ ] Know how to rollback if deployment fails (see Section 10)
- [ ] Terraform state backed up (if making infrastructure changes)
- [ ] Current system generation noted (for NixOS/Darwin rollback)

### Change Window
- [ ] Deployment scheduled during appropriate change window
- [ ] Team notified of deployment (if production changes)
- [ ] No conflicting deployments in progress
```

---

## 4. NixOS System Deployment

**Estimated time**: 10-20 minutes (depending on changes)

**Target systems**: xmsi (workstation), srv-01 (local server)

### 4.1 Overview

NixOS deployment uses Nix flakes to build and activate system configuration. This includes OS-level settings, system services, user accounts, packages, and secrets.

**Critical requirement**: All changes must be staged with `git add` before deployment. Nix flakes only see files tracked by git, and unstaged changes are silently ignored.

**Validation gates** (justfile:197-286):
1. Secrets validation
2. Git staging validation
3. Nix syntax check
4. Dry-run build
5. User confirmation

### 4.2 Prerequisites

- [ ] NixOS system accessible (local or via SSH)
- [ ] Root/sudo access
- [ ] Age private key deployed to `/etc/sops/age/keys.txt` on target system
- [ ] Configuration changes in `hosts/<hostname>/` or `modules/nixos/`

### 4.3 Stage Changes (CRITICAL STEP)

```bash
# Step 1: Review changes
git status

# Expected output shows modified files:
# modified:   hosts/xmsi/configuration.nix
# modified:   modules/nixos/common.nix

# Step 2: Stage ALL changes for Nix flakes
git add .

# Or stage specific files
git add hosts/xmsi/configuration.nix modules/nixos/common.nix

# Step 3: Verify staging
git status

# Expected output:
# Changes to be committed:
#   modified:   hosts/xmsi/configuration.nix
#   modified:   modules/nixos/common.nix

# Step 4: Verify no unstaged changes remain
git diff

# Expected: No output (all changes staged)
# If output: Stage additional changes or stash them
```

**Why this is critical**: Nix flakes create a read-only copy of all tracked files. Unstaged changes are not included, causing confusing deployment failures where your changes don't take effect.

### 4.4 Test Build Without Activation

```bash
# Step 5: Test build without activating
just nixos-build xmsi

# Expected output:
# building the system configuration...
# /nix/store/...-nixos-system-xmsi-24.11.xxx
# result symlink created

# Build succeeds → configuration is valid
# Build fails → fix errors before proceeding
```

**What this does**:
- Builds complete system configuration
- Checks for Nix syntax errors
- Verifies all dependencies available
- Creates `./result` symlink to built system
- Does NOT activate the configuration (safe to run)

### 4.5 Run Validation Gates

```bash
# Step 6: Run deployment with validation gates
just nixos-deploy xmsi

# Expected output sequence:
```

```
═══════════════════════════════════════
NixOS Deployment Validation
═══════════════════════════════════════

→ Validating secrets...
✓ Secrets validated

→ Checking git status...
✓ Git changes staged

→ Validating Nix syntax...
✓ Syntax validated

→ Performing dry-run build...
✓ Dry-run succeeded

═══════════════════════════════════════
Proceed with deployment to xmsi? [y/N]:
```

**Step 7**: Review validation output

**Gate 1 (Secrets validation)** - Checks:
- All secrets properly encrypted with SOPS
- Age key accessible for decryption
- Secret file format valid (YAML structure)

If fails: Run `just validate-secrets` for detailed error

**Gate 2 (Git staging)** - Checks:
- Working tree clean OR all changes staged
- No unstaged modifications that would be ignored

If fails: Run `git add .` to stage changes

**Gate 3 (Nix syntax)** - Checks:
- All Nix files parse correctly
- Flake inputs accessible
- No evaluation errors

If fails: Fix Nix syntax errors, common issues:
- Missing semicolons
- Undefined variables
- Import path errors

**Gate 4 (Dry-run build)** - Shows:
- What packages will be built
- What configuration files will change
- Estimated build time

If fails: Check build logs for missing dependencies or build errors

### 4.6 Confirm and Deploy

```bash
# Step 8: Confirm deployment at prompt
Proceed with deployment to xmsi? [y/N]: y

→ Deploying NixOS configuration to xmsi...
building the system configuration...
activating the configuration...
setting up /etc...
reloading user units for mi-skam...
setting up /run/secrets...
installing secrets...
restarting sysinit-reactivation.target
```

**Step 9**: Monitor activation output

Watch for these success indicators:
- "activating the configuration..." - System profile switching
- "setting up /etc..." - Configuration files updated
- "installing secrets..." - Secrets decrypted and mounted
- No errors about failed services

Watch for these failure indicators:
- "activation script ... failed" - Service startup failure
- "no key could decrypt" - Age key missing or wrong
- "failed to start ..." - Service configuration error

### 4.7 Verify Deployment

**Step 10**: Verify system booted successfully

```bash
# Check current system generation
nixos-rebuild list-generations

# Expected output:
#   1   2025-10-28 10:00:00
#   2   2025-10-29 15:30:00 (current)
# Current generation should match deployment time

# Verify services running
systemctl status

# Expected: "State: running"
# Check for any failed services (red text)

# Test specific service if changed
systemctl status sshd
systemctl status nginx

# Expected: "active (running)" with green indicator
```

**Step 11**: Verify secrets deployed correctly

```bash
# On target system (if remote)
ssh root@xmsi "ls -la /run/secrets-for-users/"

# Expected output:
# lrwxrwxrwx 1 root root 39 Oct 29 15:30 mi-skam -> /run/agenix.d/1/mi-skam
# (Symbolic links to decrypted secrets)

# Verify secret content (first 10 chars only for security)
ssh root@xmsi "cat /run/secrets-for-users/mi-skam | head -c 10"

# Expected: Password hash prefix like "$6$" or "$2b$"
# If empty or error: Secrets did not decrypt, check age key
```

**Step 12**: Test system functionality

```bash
# Test SSH login with user account
ssh mi-skam@xmsi whoami

# Expected output: mi-skam
# If fails: Password or SSH key issue

# Test sudo access
ssh mi-skam@xmsi "sudo whoami"

# Expected output: root
# If fails: Sudo configuration issue

# Test network connectivity
ssh root@xmsi "ping -c 3 1.1.1.1"

# Expected: 3 packets transmitted, 3 received, 0% packet loss
```

**Step 13**: Commit deployment

```bash
# Commit changes after successful deployment
git commit -m "feat(nixos): <description of changes>"

# Example commit messages:
# git commit -m "feat(nixos): add nginx web server to xmsi"
# git commit -m "fix(nixos): update firewall rules for srv-01"
# git commit -m "chore(nixos): update system packages"
```

### 4.8 Success Summary

```bash
# Expected final output from just nixos-deploy:

═══════════════════════════════════════
Deployment Summary
═══════════════════════════════════════
✓ Secrets validated
✓ Git changes staged
✓ Syntax validated
✓ Dry-run succeeded
✓ Deployed successfully to xmsi
```

### 4.9 Force Mode (Skip Confirmation)

For automation or when confirmation already obtained:

```bash
# Deploy without confirmation prompt
just nixos-deploy xmsi true

# Validation gates still run, only confirmation skipped
```

### 4.10 Rollback Procedure

See [Section 10.1](#101-nixos-rollback) for detailed rollback steps.

**Quick rollback**:
```bash
# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or boot into previous generation from GRUB boot menu
# Previous generations listed as "NixOS - Configuration X (YYYY-MM-DD)"
```

---

## 5. Darwin System Deployment

**Estimated time**: 10-20 minutes

**Target systems**: xbook (macOS ARM64)

### 5.1 Overview

Darwin deployment uses nix-darwin to build and activate macOS system configuration. This includes system settings, Homebrew packages, services, and user environment.

**Critical requirement**: Same as NixOS - all changes must be staged with `git add`.

**Validation gates** (justfile:324-390):
1. Secrets validation
2. Git staging validation
3. Nix syntax check
4. Dry-run build
5. User confirmation

### 5.2 Prerequisites

- [ ] Darwin system accessible (typically local)
- [ ] Admin user with sudo access
- [ ] Age private key at `/opt/homebrew/etc/sops/age/keys.txt` (Apple Silicon) or `/usr/local/etc/sops/age/keys.txt` (Intel)
- [ ] Configuration changes in `hosts/xbook/` or `modules/darwin/`

### 5.3 Stage Changes

```bash
# Step 1: Review and stage changes
git status
git add .

# Step 2: Verify staging
git status

# Expected: All changes under "Changes to be committed"
```

### 5.4 Test Build Without Activation

```bash
# Step 3: Test build without activating
just darwin-build xbook

# Expected output:
# building the system configuration...
# /nix/store/...-darwin-system-24.11.xxx
# result symlink created
```

### 5.5 Run Validation Gates

```bash
# Step 4: Run deployment with validation gates
just darwin-deploy xbook

# Expected output sequence:
```

```
═══════════════════════════════════════
Darwin Deployment Validation
═══════════════════════════════════════

→ Validating secrets...
✓ Secrets validated

→ Checking git status...
✓ Git changes staged

→ Validating Nix syntax...
✓ Syntax validated

→ Performing dry-run build...
✓ Dry-run succeeded

═══════════════════════════════════════
Proceed with deployment to xbook? [y/N]:
```

**Step 5**: Review validation gates (same as NixOS Section 4.5)

### 5.6 Confirm and Deploy

```bash
# Step 6: Confirm deployment
Proceed with deployment to xbook? [y/N]: y

→ Deploying Darwin configuration to xbook...
building the system configuration...
activating the configuration...
setting up /etc...
setting up launchd services...
```

**Step 7**: Monitor activation output

Darwin-specific indicators:
- "setting up launchd services..." - macOS services being configured
- "setting up /etc..." - System configuration files updated
- No errors about permission denied (requires sudo for some operations)

### 5.7 Verify Deployment

**Step 8**: Verify system configuration active

```bash
# Check current Darwin generation
darwin-rebuild --list-generations

# Expected output:
#   1   2025-10-28 10:00:00
#   2   2025-10-29 15:30:00 (current)

# Verify system settings applied
defaults read com.apple.dock autohide

# Expected: 1 (if dock autohide enabled in config)

# Test launchd services if changed
launchctl list | grep nix

# Expected: Shows nix-daemon if configured
```

**Step 9**: Verify Homebrew packages (if configured)

```bash
# Check Homebrew bundle installed correctly
brew list | grep <package-name>

# Expected: Package listed if configured in darwin configuration

# Verify Homebrew services
brew services list

# Expected: Shows services managed by Homebrew
```

**Step 10**: Test user environment

```bash
# Verify shell configuration loaded
echo $PATH

# Expected: Nix paths present (/nix/var/nix/profiles/...)

# Test command-line tools
which git jq fzf

# Expected: Tools configured in Home Manager available
```

**Step 11**: Commit deployment

```bash
git commit -m "feat(darwin): <description>"
```

### 5.8 Success Summary

```bash
═══════════════════════════════════════
Deployment Summary
═══════════════════════════════════════
✓ Secrets validated
✓ Git changes staged
✓ Syntax validated
✓ Dry-run succeeded
✓ Deployed successfully to xbook
```

### 5.9 Rollback Procedure

See [Section 10.2](#102-darwin-rollback) for detailed rollback steps.

**Quick rollback**:
```bash
# Rollback to previous generation
darwin-rebuild rollback
```

---

## 6. Home Manager Deployment

**Estimated time**: 5-15 minutes

**Target systems**: All hosts (xbook, xmsi, srv-01) with user configurations

### 6.1 Overview

Home Manager deploys user environment configuration including dotfiles, applications, shell configuration, and personal settings. Home Manager is **decoupled from system configuration** - you can update your user environment without rebuilding the system.

**Critical requirement**: Changes must be staged with `git add` (Nix flakes requirement).

**Validation gates**: Home Manager uses similar validation but deployment is user-level (no sudo required).

### 6.2 Prerequisites

- [ ] User account exists on target system
- [ ] Home Manager configuration in `modules/home/users/<username>.nix`
- [ ] Configuration changes committed or staged

### 6.3 Stage Changes

```bash
# Step 1: Review and stage changes
git status
git add modules/home/users/plumps.nix modules/home/common.nix

# Step 2: Verify staging
git status
```

### 6.4 Test Build Without Activation

```bash
# Step 3: Test build for specific user@host
just home-build plumps@xbook

# Or for NixOS host
just home-build mi-skam@xmsi

# Expected output:
# building the user environment...
# /nix/store/...-home-manager-generation
# result symlink created
```

### 6.5 Deploy Home Configuration

```bash
# Step 4: Deploy home configuration
just home-deploy plumps@xbook

# Expected output:
# building the user environment...
# activating the configuration...
# setting up home files...
# linking dotfiles...
```

**What happens**:
- User environment packages installed
- Dotfiles symlinked to `~/.config/`, `~/`, etc.
- Shell configuration updated (bashrc, zshrc)
- Application configurations written
- User services started (if configured)

### 6.6 Verify Deployment

**Step 5**: Verify home generation updated

```bash
# List home-manager generations
home-manager generations

# Expected output:
# 2025-10-29 15:30:00 : id 2 -> /nix/store/...-home-manager-generation
# 2025-10-28 10:00:00 : id 1 -> /nix/store/...-home-manager-generation
```

**Step 6**: Verify dotfiles linked correctly

```bash
# Check dotfile symlinks
ls -la ~/.config/nvim/init.lua
ls -la ~/.zshrc

# Expected: Symlinks pointing to /nix/store/...
# lrwxrwxrwx ... /home/plumps/.zshrc -> /nix/store/...-home-manager-files/.zshrc
```

**Step 7**: Test user environment

```bash
# Reload shell configuration
exec $SHELL

# Or source configuration
source ~/.zshrc  # or ~/.bashrc

# Verify PATH updated
echo $PATH | grep nix

# Expected: Nix paths present

# Test user packages available
which vim git tmux

# Expected: Commands found from Home Manager packages
```

**Step 8**: Commit deployment

```bash
git commit -m "feat(home): <description>"

# Example:
# git commit -m "feat(home): add neovim configuration for plumps"
```

### 6.7 Rollback Procedure

See [Section 10.3](#103-home-manager-rollback).

**Quick rollback**:
```bash
# Rollback to previous generation
home-manager generations | head -2 | tail -1 | awk '{print $NF}' | xargs -I {} {}/activate
```

---

## 7. Terraform Infrastructure Deployment

**Estimated time**: 15-30 minutes (depending on changes)

**Target**: Hetzner Cloud infrastructure (servers, networks, SSH keys)

### 7.1 Overview

Terraform (OpenTofu) manages Hetzner Cloud infrastructure as code. This includes provisioning servers, configuring networks, managing SSH keys, and setting up firewalls.

**Critical**: Terraform modifies real infrastructure. Always review plan carefully before applying.

**Validation gates** (justfile:510-587):
1. Age key validation
2. Secrets validation
3. Terraform state validation
4. Syntax validation
5. Plan generation (shows changes)
6. User confirmation

### 7.2 Prerequisites

- [ ] Hetzner Cloud API token in `secrets/hetzner.yaml` (Read & Write permissions)
- [ ] Terraform state initialized (`just tf-init`)
- [ ] Configuration changes in `terraform/` directory
- [ ] Terraform state backed up (see Section 7.8)

### 7.3 Review Changes

```bash
# Step 1: Review Terraform configuration changes
git diff terraform/

# Expected: Shows infrastructure changes you made
# Common files: servers.tf, network.tf, ssh_keys.tf
```

### 7.4 Validate Syntax

```bash
# Step 2: Validate Terraform syntax
just tf-validate

# Expected output:
# Success! The configuration is valid.

# If fails: Fix syntax errors in .tf files
```

### 7.5 Generate Plan

```bash
# Step 3: Generate Terraform plan (dry-run)
just tf-plan

# Expected output sequence:
```

```
═══════════════════════════════════════
Terraform Planning
═══════════════════════════════════════

→ Validating SOPS age key...
✓ Age key validated

→ Validating secrets...
✓ Secrets validated

→ Validating Terraform state...
✓ State validated

→ Generating Terraform plan...
═══════════════════════════════════════
Terraform will perform the following actions:

  # hcloud_server.test-1 will be created
  + resource "hcloud_server" "test-1" {
      + name        = "test-1.dev.nbg"
      + server_type = "cax11"
      + image       = "ubuntu-24.04"
      + location    = "nbg1"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
═══════════════════════════════════════
```

**Step 4**: Review plan output carefully

**Plan symbols**:
- `+` - Resource will be **created**
- `~` - Resource will be **modified** in place
- `-/+` - Resource will be **destroyed and recreated** (data loss possible)
- `-` - Resource will be **destroyed**

**What to check**:
- Are the changes what you expected?
- Will any resources be destroyed (check for `-` or `-/+`)?
- Will servers be recreated (data loss)?
- Are protected resources safe (lifecycle.prevent_destroy)?

**Common plan outputs**:
- "No changes. Your infrastructure matches the configuration." - Safe, no changes needed
- "Plan: X to add, Y to change, Z to destroy" - Review carefully before applying
- "Error: ..." - Fix configuration errors before proceeding

### 7.6 Apply Changes with Validation Gates

```bash
# Step 5: Apply Terraform changes with validation gates
just tf-apply

# Expected output sequence:
```

```
═══════════════════════════════════════
Terraform Deployment Validation
═══════════════════════════════════════

→ Validating SOPS age key...
✓ Age key validated

→ Validating secrets...
✓ Secrets validated

→ Validating Terraform state...
✓ State validated

→ Validating Terraform syntax...
✓ Syntax validated

→ Generating Terraform plan...
═══════════════════════════════════════
[Plan output showing changes]
═══════════════════════════════════════

Proceed with infrastructure deployment? [y/N]:
```

**Step 6**: Review plan one final time at confirmation prompt

**Critical checks before typing "y"**:
- Destructive changes expected? (server recreation, data loss)
- Production environment affected?
- Change window appropriate?
- Rollback plan ready?

```bash
# Step 7: Confirm deployment
Proceed with infrastructure deployment? [y/N]: y

→ Applying Terraform changes...
hcloud_server.test-1: Creating...
hcloud_server.test-1: Creation complete after 45s [id=12345678]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
server_ips = {
  "mail-1.prod.nbg" = "xxx.xxx.xxx.xxx"
  "test-1.dev.nbg" = "yyy.yyy.yyy.yyy"
}
```

### 7.7 Verify in Hetzner Console

**Step 8**: Verify changes in Hetzner Cloud Console

```bash
# Open Hetzner Cloud Console
open https://console.hetzner.cloud/

# Navigate to: Project → Servers
```

**Verify**:
- New servers created with correct specifications (type, location, image)
- Networks configured correctly (IP ranges, subnets)
- SSH keys associated with servers
- Firewalls applied if configured

**Alternative: Verify via CLI**

```bash
# List servers
hcloud server list

# Expected output:
# NAME                TYPE    STATUS    IPV4             IPV6
# mail-1.prod.nbg     cax21   running   xxx.xxx.xxx.xxx  ...
# test-1.dev.nbg      cax11   running   yyy.yyy.yyy.yyy  ...

# Describe specific server
hcloud server describe test-1.dev.nbg

# Expected: Shows full server details (type, location, image, networks)

# List networks
hcloud network list

# Expected output:
# NAME      IP RANGE        SERVERS
# homelab   10.0.0.0/16     3
```

**Step 9**: Test connectivity to new servers

```bash
# Test SSH connection
ssh root@yyy.yyy.yyy.yyy

# Expected: SSH connection succeeds
# If fails: Check SSH key deployment, firewall rules

# Test private network connectivity
ssh root@mail-1.prod.nbg "ping -c 3 10.0.0.x"

# Expected: Pings succeed if on same private network
```

**Step 10**: Update Ansible inventory

```bash
# Update Ansible inventory from Terraform outputs
just ansible-inventory-update

# Expected output:
# Updating Ansible inventory from Terraform outputs...
# Inventory updated: ansible/inventory/hosts.yaml

# Verify inventory updated
cat ansible/inventory/hosts.yaml

# Expected: New servers listed with correct IPs
```

**Step 11**: Commit changes

```bash
git add terraform/
git commit -m "feat(terraform): <description>"

# Example:
# git commit -m "feat(terraform): add test-1.dev.nbg server"
```

### 7.8 Terraform State Backup

**Critical**: Terraform state contains infrastructure metadata. State loss = cannot manage infrastructure.

**State location**: `terraform/terraform.tfstate`

**Backup before major changes**:
```bash
# Manual backup before destructive apply
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)

# List backups
ls -lt terraform/*.backup-*

# Expected: Timestamped backup files
```

**Note**: Terraform state files are in `.gitignore` (never commit state to git - contains sensitive data).

### 7.9 Force Mode

```bash
# Apply without confirmation prompt (automation)
just tf-apply true

# Validation gates still run, only confirmation skipped
```

### 7.10 Rollback Procedure

See [Section 10.4](#104-terraform-rollback) for detailed rollback steps.

**Quick rollback approach**:
1. Revert Terraform configuration changes in git
2. Run `just tf-apply` to restore previous state
3. Or restore from state backup if state corrupted

---

## 8. Ansible VPS Configuration

**Estimated time**: 10-30 minutes (depending on playbook)

**Target systems**: Hetzner Cloud VPS (mail-1, syncthing-1, test-1) running Debian/Rocky/Ubuntu

### 8.1 Overview

Ansible manages configuration for VPS systems that are not managed by NixOS. This includes installing packages, configuring services, managing users, and deploying application configurations.

**Critical**: Ansible makes real changes to production servers. Always run check-mode (dry-run) first.

**Validation gates** (justfile:759-826):
1. Secrets validation
2. Ansible inventory validation
3. Playbook syntax check
4. Dry-run with change preview (--check --diff)
5. User confirmation

### 8.2 Prerequisites

- [ ] Ansible inventory updated (`just ansible-inventory-update`)
- [ ] SSH access to target servers
- [ ] Playbook in `ansible/playbooks/` directory
- [ ] Target servers responsive (`just ansible-ping`)

### 8.3 Verify Connectivity

```bash
# Step 1: Test connectivity to all managed servers
just ansible-ping

# Expected output:
# mail-1.prod.nbg | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
# syncthing-1.prod.hel | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
# test-1.dev.nbg | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }

# If any host UNREACHABLE: Check SSH access, network connectivity
```

### 8.4 Validate Playbook Syntax

```bash
# Step 2: Check playbook syntax
just ansible-syntax-check deploy

# Expected output:
# playbook: playbooks/deploy.yaml

# If error: Fix YAML syntax errors in playbook
```

### 8.5 Run Check Mode (Dry-Run)

```bash
# Step 3: Run playbook in check mode (shows changes without applying)
cd ansible
ansible-playbook playbooks/deploy.yaml --check --diff

# Expected output:
```

```
PLAY [Configure VPS servers] *******************************************

TASK [common : Update apt cache] ***************************************
ok: [mail-1.prod.nbg]
ok: [test-1.dev.nbg]

TASK [common : Install base packages] **********************************
changed: [test-1.dev.nbg] => (item=vim)
changed: [test-1.dev.nbg] => (item=htop)
ok: [mail-1.prod.nbg]

PLAY RECAP *************************************************************
mail-1.prod.nbg           : ok=5    changed=0    unreachable=0    failed=0
test-1.dev.nbg            : ok=5    changed=2    unreachable=0    failed=0
```

**Step 4**: Review check mode output

**What to look for**:
- `ok` - Task ran, no changes needed (current state matches desired)
- `changed` - Task would make changes (shows diff if --diff used)
- `failed` - Task failed, fix errors before applying
- `unreachable` - Host not accessible, check SSH/network

**Diff output** (with --diff flag):
```
--- before: /etc/nginx/nginx.conf
+++ after: /etc/nginx/nginx.conf
@@ -10,3 +10,4 @@
     worker_connections 768;
 }
+include /etc/nginx/conf.d/*.conf;
```

**Interpret changes**:
- Are changes expected?
- Any unexpected file modifications?
- Services being restarted?
- User accounts being modified?

### 8.6 Deploy with Validation Gates

```bash
# Step 5: Deploy with validation gates
just ansible-deploy deploy

# Expected output sequence:
```

```
═══════════════════════════════════════
Ansible Deployment Validation
═══════════════════════════════════════

→ Validating secrets...
✓ Secrets validated

→ Validating Ansible inventory...
✓ Inventory validated (3 hosts)

→ Validating playbook syntax...
✓ Syntax validated

→ Performing dry-run (showing changes)...
═══════════════════════════════════════
[Check mode output showing changes]
═══════════════════════════════════════

Proceed with deployment to all hosts? [y/N]:
```

**Step 6**: Confirm deployment after reviewing dry-run

```bash
Proceed with deployment to all hosts? [y/N]: y

→ Deploying playbook deploy to all hosts...

PLAY [Configure VPS servers] *******************************************

TASK [common : Install base packages] **********************************
changed: [test-1.dev.nbg] => (item=vim)
changed: [test-1.dev.nbg] => (item=htop)

PLAY RECAP *************************************************************
mail-1.prod.nbg           : ok=5    changed=0    unreachable=0    failed=0
test-1.dev.nbg            : ok=5    changed=2    unreachable=0    failed=0
```

### 8.7 Verify Idempotency

**Step 7**: Run playbook again to verify idempotency (second run should show changed=0)

```bash
# Run deployment again
ansible-playbook playbooks/deploy.yaml

# Expected PLAY RECAP:
# mail-1.prod.nbg           : ok=5    changed=0    unreachable=0    failed=0
# test-1.dev.nbg            : ok=5    changed=0    unreachable=0    failed=0

# All hosts show changed=0 → Configuration idempotent (correct state)
# If changed > 0: Playbook not idempotent, investigate task logic
```

**Why verify idempotency?**
- Idempotent playbooks safe to run repeatedly
- Second run confirms configuration converged to desired state
- Non-idempotent tasks indicate logic errors (e.g., `shell` commands without changed_when)

### 8.8 Deploy to Specific Environment

```bash
# Deploy only to dev environment
just ansible-deploy-env dev deploy

# Or deploy only to prod environment
just ansible-deploy-env prod deploy

# Expected output: Same validation gates, limited to specified environment
```

**Validation gates** (justfile:853-920 - ansible-deploy-env recipe):
1. Secrets validation
2. Inventory validation (filtered by environment)
3. Syntax check
4. Dry-run (limited to environment hosts)
5. User confirmation

### 8.9 Verify Services

**Step 8**: Verify services running on target systems

```bash
# Check service status on all hosts
ansible all -m shell -a "systemctl status nginx"

# Expected output (if nginx configured):
# mail-1.prod.nbg | CHANGED | rc=0 >>
# ● nginx.service - The nginx HTTP and reverse proxy server
#    Active: active (running) since...

# Or check specific service on specific host
ssh root@mail-1.prod.nbg "systemctl status postfix"
```

**Step 9**: Test application functionality

```bash
# Test web server responding (if configured)
curl -I http://mail-1.prod.nbg

# Expected: HTTP 200 OK response

# Test SSH still accessible
ssh root@test-1.dev.nbg "echo 'SSH working'"

# Expected: "SSH working" output
```

**Step 10**: Commit changes

```bash
git add ansible/
git commit -m "feat(ansible): <description>"

# Example:
# git commit -m "feat(ansible): configure nginx on mail-1"
```

### 8.10 Rollback Procedure

See [Section 10.5](#105-ansible-rollback) for detailed rollback steps.

**Quick rollback approach**:
1. Revert Ansible playbook changes in git
2. Run playbook again to restore previous configuration
3. Ansible applies changes to restore previous state

---

## 9. Combined Deployment Scenarios

Common scenarios involving multiple deployment types in sequence.

### 9.1 Scenario: Provision Hetzner Server → Configure with Ansible

**Use case**: Adding a new VPS server to the infrastructure

**Estimated time**: 30-45 minutes

**Steps**:

#### Phase 1: Provision Infrastructure (Terraform)

**Step 1**: Define server in Terraform

```bash
# Edit terraform/servers.tf
vim terraform/servers.tf

# Add new server definition:
resource "hcloud_server" "new-server" {
  name        = "new-server.prod.nbg"
  server_type = "cax11"
  image       = "ubuntu-24.04"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.homelab.id]

  network {
    network_id = hcloud_network.homelab.id
    ip         = "10.0.0.10"
  }
}
```

**Step 2**: Stage and plan changes

```bash
git add terraform/servers.tf
just tf-plan

# Review plan output
# Expected: "Plan: 1 to add, 0 to change, 0 to destroy"
```

**Step 3**: Apply infrastructure changes

```bash
just tf-apply

# Confirm at prompt after reviewing plan
# Wait for server provisioning (30-60 seconds)

# Note the server IP from output:
# server_ips = {
#   "new-server.prod.nbg" = "xxx.xxx.xxx.xxx"
# }
```

#### Phase 2: Update Inventory

**Step 4**: Sync Ansible inventory from Terraform

```bash
just ansible-inventory-update

# Expected output:
# Inventory updated: ansible/inventory/hosts.yaml

# Verify new server in inventory
cat ansible/inventory/hosts.yaml | grep new-server

# Expected: new-server listed with correct IP
```

#### Phase 3: Bootstrap Server

**Step 5**: Run Ansible bootstrap playbook

```bash
just ansible-deploy-env prod bootstrap

# Bootstrap playbook performs:
# - Initial user creation
# - SSH key deployment
# - Firewall configuration
# - Base package installation

# Expected PLAY RECAP:
# new-server.prod.nbg       : ok=10   changed=8    unreachable=0    failed=0
```

**Step 6**: Verify bootstrap

```bash
# Test SSH connectivity
just ansible-ping

# Expected: new-server responds with "pong"
```

#### Phase 4: Deploy Configuration

**Step 7**: Run main deployment playbook

```bash
just ansible-deploy-env prod deploy

# Deploy playbook performs:
# - Install application packages
# - Configure services
# - Deploy application configs
# - Start services

# Expected PLAY RECAP:
# new-server.prod.nbg       : ok=15   changed=10   unreachable=0    failed=0
```

**Step 8**: Verify configuration

```bash
# Verify services running
ssh root@new-server.prod.nbg "systemctl status nginx"

# Expected: active (running)

# Verify network connectivity
ssh root@mail-1.prod.nbg "ping -c 3 10.0.0.10"

# Expected: Pings succeed (private network)
```

#### Phase 5: Verify Idempotency

**Step 9**: Run deployment again to verify idempotency

```bash
just ansible-deploy-env prod deploy

# Expected PLAY RECAP:
# new-server.prod.nbg       : ok=15   changed=0    unreachable=0    failed=0

# changed=0 confirms configuration converged
```

#### Phase 6: Commit Changes

**Step 10**: Commit all changes

```bash
git add terraform/ ansible/inventory/
git commit -m "feat: provision and configure new-server.prod.nbg"
```

### 9.2 Scenario: Deploy NixOS System + Home Manager

**Use case**: Updating both system and user configuration together

**Estimated time**: 15-25 minutes

**Steps**:

#### Phase 1: Stage All Changes

**Step 1**: Review and stage changes

```bash
# Review changes to both system and home configs
git status

# Expected output:
# modified:   hosts/xmsi/configuration.nix
# modified:   modules/home/users/mi-skam.nix

git add hosts/xmsi/configuration.nix modules/home/users/mi-skam.nix
```

#### Phase 2: Deploy System Configuration

**Step 2**: Deploy NixOS system configuration first

```bash
just nixos-deploy xmsi

# System deployment includes:
# - OS-level packages and services
# - User account configuration
# - System-wide settings

# Expected: Deployment succeeds
```

**Step 3**: Verify system boots successfully

```bash
# Check system status
systemctl status

# Expected: "State: running" with no failed services
```

#### Phase 3: Deploy Home Configuration

**Step 4**: Deploy Home Manager configuration

```bash
just home-deploy mi-skam@xmsi

# Home deployment includes:
# - User packages
# - Dotfiles and shell configuration
# - User services

# Expected: Deployment succeeds
```

**Step 5**: Verify user environment

```bash
# Test user environment
ssh mi-skam@xmsi "which vim git"

# Expected: Commands available from Home Manager

# Verify dotfiles updated
ssh mi-skam@xmsi "cat ~/.zshrc | head -5"

# Expected: Shows updated shell configuration
```

#### Phase 4: Commit Changes

**Step 6**: Commit after successful deployment

```bash
git commit -m "feat: update system and home config for xmsi"
```

**Why deploy separately?**
- System and home configurations are decoupled
- Home Manager doesn't require sudo
- Smaller blast radius - system deployment failure doesn't affect home environment
- User can update home config without system rebuild

### 9.3 Scenario: Infrastructure Change + Configuration Update

**Use case**: Modifying Hetzner server (e.g., resize) and updating configuration

**Estimated time**: 20-40 minutes

**Steps**:

#### Phase 1: Update Infrastructure

**Step 1**: Modify server configuration in Terraform

```bash
vim terraform/servers.tf

# Change server_type:
resource "hcloud_server" "test-1" {
  server_type = "cax21"  # Upgrade from cax11
  ...
}
```

**Step 2**: Apply Terraform changes

```bash
git add terraform/servers.tf
just tf-plan

# Expected plan:
# ~ hcloud_server.test-1 (modify in-place)
#   ~ server_type = "cax11" -> "cax21"

just tf-apply

# Confirm deployment
# Note: Server may reboot during resize
```

#### Phase 2: Wait for Server Availability

**Step 3**: Wait for server to come back online

```bash
# Test connectivity
just ansible-ping

# If test-1.dev.nbg UNREACHABLE: Wait and retry (server rebooting)

# Or watch for SSH availability
while ! ssh root@test-1.dev.nbg "echo ready"; do
  echo "Waiting for server..."
  sleep 10
done

# Expected: "ready" output when server accessible
```

#### Phase 3: Update Configuration

**Step 4**: Update Ansible configuration for new server specs (if needed)

```bash
# Edit playbook to take advantage of new resources
vim ansible/playbooks/deploy.yaml

# Example: Increase worker processes now that server has more CPU
```

**Step 5**: Deploy updated configuration

```bash
git add ansible/
just ansible-deploy-env dev deploy

# Expected: Configuration deployed to resized server
```

#### Phase 4: Verify

**Step 6**: Verify server and services

```bash
# Check server specs
ssh root@test-1.dev.nbg "nproc"  # CPU count
ssh root@test-1.dev.nbg "free -h"  # Memory

# Expected: New specs (e.g., 4 CPUs, 8GB RAM for cax21)

# Verify services running
ssh root@test-1.dev.nbg "systemctl status"

# Expected: All services active
```

**Step 7**: Commit changes

```bash
git commit -m "feat: resize test-1.dev.nbg to cax21 and update config"
```

---

## 10. Emergency Rollback Procedures

When deployments fail or cause issues, rollback quickly to restore service.

### 10.1 NixOS Rollback

**Scenario**: NixOS deployment caused boot failure or service issues

#### Option 1: Rollback to Previous Generation (Fastest)

```bash
# Step 1: Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Expected output:
# building the system configuration...
# activating the configuration...
# setting up /etc...

# System reverts to previous generation
```

**Step 2**: Verify system functional

```bash
# Check current generation
nixos-rebuild list-generations

# Expected: Previous generation now marked (current)

# Verify services
systemctl status
```

**Step 3**: Identify and fix issue

```bash
# Review failed deployment logs
journalctl -xe | grep nixos-rebuild

# Common issues:
# - Syntax errors in configuration
# - Missing dependencies
# - Service configuration errors
```

#### Option 2: Boot Previous Generation from GRUB (If System Won't Boot)

**Step 1**: Reboot system and access GRUB menu

```
# At GRUB boot menu, select:
# "NixOS - Configuration X (YYYY-MM-DD)"
# Where X is previous generation number
```

**Step 2**: Once booted, make previous generation default

```bash
sudo nixos-rebuild switch --rollback
```

#### Option 3: Revert Git Changes and Redeploy

**Step 1**: Revert configuration changes

```bash
# Find last working commit
git log --oneline hosts/xmsi/

# Revert to previous commit
git revert HEAD

# Or reset to previous commit (caution: loses commits)
git reset --hard HEAD~1
```

**Step 2**: Redeploy previous configuration

```bash
git add .
just nixos-deploy xmsi
```

**Step 3**: Document rollback

```bash
git commit -m "rollback(nixos): revert to working configuration due to <issue>"
```

### 10.2 Darwin Rollback

**Scenario**: Darwin deployment caused system issues

#### Option 1: Rollback Command

```bash
# Step 1: List generations
darwin-rebuild --list-generations

# Expected output:
#   1   2025-10-28 10:00:00
#   2   2025-10-29 15:30:00 (current)

# Step 2: Rollback to previous generation
darwin-rebuild rollback

# Or rollback to specific generation
darwin-rebuild switch --rollback
```

**Step 3**: Verify system functional

```bash
# Check current generation
darwin-rebuild --list-generations

# Test system settings
defaults read com.apple.dock

# Reload shell
exec $SHELL
```

#### Option 2: Revert Git and Redeploy

```bash
# Revert changes
git revert HEAD

# Redeploy
git add .
just darwin-deploy xbook
```

### 10.3 Home Manager Rollback

**Scenario**: Home Manager deployment broke user environment

#### Option 1: Activate Previous Generation

```bash
# Step 1: List generations
home-manager generations

# Expected output:
# 2025-10-29 15:30:00 : id 2 -> /nix/store/...-home-manager-generation (current)
# 2025-10-28 10:00:00 : id 1 -> /nix/store/...-home-manager-generation

# Step 2: Activate previous generation (id 1)
/nix/store/<hash>-home-manager-generation/activate

# Copy full path from "id 1" output above
```

**Step 3**: Verify user environment

```bash
# Reload shell
exec $SHELL

# Check dotfiles
ls -la ~/.zshrc

# Expected: Symlinks reverted to previous generation
```

#### Option 2: Revert Git and Redeploy

```bash
git revert HEAD
git add .
just home-deploy plumps@xbook
```

### 10.4 Terraform Rollback

**Scenario**: Terraform apply caused infrastructure issues

**Warning**: Terraform rollback is **not automatic**. Must manually restore previous state.

#### Option 1: Revert Git and Reapply

```bash
# Step 1: Identify last working state
git log --oneline terraform/

# Step 2: Revert Terraform configuration
git revert HEAD

# Or reset to previous commit
git reset --hard HEAD~1

# Step 3: Review rollback plan
git add .
just tf-plan

# Expected plan: Shows reverting infrastructure to previous state
```

**Step 4**: Apply rollback

```bash
just tf-apply

# Confirm at prompt after reviewing plan
# Terraform will modify/destroy resources to match previous configuration
```

#### Option 2: Restore from State Backup

**Scenario**: Terraform state corrupted or lost

```bash
# Step 1: Find most recent state backup
ls -lt terraform/*.backup-*

# Expected output:
# terraform/terraform.tfstate.backup-20251029-153000

# Step 2: Restore state backup
cp terraform/terraform.tfstate.backup-20251029-153000 terraform/terraform.tfstate

# Step 3: Verify state restored
just tf-plan

# Expected: "No changes" or only expected changes
```

#### Option 3: Import Resources (If State Lost)

**Scenario**: State file lost, must reconstruct from actual infrastructure

```bash
# Step 1: Reinitialize Terraform
just tf-init

# Step 2: Import existing resources
just tf-import

# Imports: servers, networks, SSH keys from Hetzner Cloud

# Step 3: Verify import succeeded
just tf-plan

# Expected: "No changes" (state matches reality)
```

### 10.5 Ansible Rollback

**Scenario**: Ansible playbook caused service failures or misconfigurations

#### Option 1: Revert and Redeploy

```bash
# Step 1: Revert Ansible playbook changes
git revert HEAD

# Step 2: Review rollback changes
git diff HEAD~1 ansible/

# Step 3: Run check mode to preview rollback
cd ansible
ansible-playbook playbooks/deploy.yaml --check --diff

# Expected diff: Shows reverting to previous configuration
```

**Step 4**: Deploy rollback configuration

```bash
just ansible-deploy deploy

# Ansible applies changes to restore previous state

# Expected: Services restored, configuration reverted
```

**Step 5**: Verify idempotency

```bash
# Run again to confirm convergence
ansible-playbook playbooks/deploy.yaml

# Expected PLAY RECAP: changed=0 for all hosts
```

#### Option 2: Manual Service Restoration

**Scenario**: Single service broken, quick fix needed

```bash
# Step 1: Identify broken service
ssh root@mail-1.prod.nbg "systemctl status nginx"

# Expected: "failed" status with error details

# Step 2: Restore service configuration manually
ssh root@mail-1.prod.nbg "cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf"

# Step 3: Restart service
ssh root@mail-1.prod.nbg "systemctl restart nginx"

# Step 4: Verify service running
ssh root@mail-1.prod.nbg "systemctl status nginx"

# Expected: "active (running)"
```

**Step 5**: Fix Ansible playbook and redeploy

```bash
# Fix playbook configuration issue
vim ansible/playbooks/deploy.yaml

# Deploy corrected configuration
git add ansible/
just ansible-deploy deploy
```

#### Option 3: Re-run Bootstrap (Nuclear Option)

**Scenario**: Server configuration severely broken

**Warning**: This reinstalls all packages and reconfigures all services. Data loss possible.

```bash
# Step 1: Run bootstrap playbook to reset configuration
just ansible-deploy-env <env> bootstrap

# Bootstrap playbook reinstalls base configuration

# Step 2: Run main deployment
just ansible-deploy-env <env> deploy

# Server restored to known-good state
```

---

## 11. Common Issues and Troubleshooting

### 11.1 Age Key Missing Errors

**Symptom**: `nixos-rebuild` or `sops` fails with "no key could decrypt the data"

**Cause**: Age private key not deployed or wrong location

**Solution for NixOS**:
```bash
# Deploy age key to target system
scp ~/.config/sops/age/keys.txt root@xmsi:/etc/sops/age/keys.txt
ssh root@xmsi "chmod 600 /etc/sops/age/keys.txt && chown root:root /etc/sops/age/keys.txt"

# Verify deployment
ssh root@xmsi "ls -la /etc/sops/age/keys.txt"

# Expected: -rw------- 1 root root 184 ...
```

**Solution for Darwin**:
```bash
# Deploy age key (Apple Silicon)
sudo cp ~/.config/sops/age/keys.txt /opt/homebrew/etc/sops/age/keys.txt
sudo chmod 600 /opt/homebrew/etc/sops/age/keys.txt
sudo chown root:wheel /opt/homebrew/etc/sops/age/keys.txt

# Verify
ls -la /opt/homebrew/etc/sops/age/keys.txt
```

**Solution for Operator Workstation**:
```bash
# Verify key exists
ls -la ~/.config/sops/age/keys.txt

# If missing: Restore from backup (password manager, encrypted USB, paper)
# See docs/runbooks/age_key_bootstrap.md Section 8
```

**Reference**: See `docs/runbooks/age_key_bootstrap.md` for complete age key deployment procedures.

### 11.2 Git Staging Validation Failed

**Symptom**: `just nixos-deploy` fails with "❌ Git staging validation failed"

**Output**:
```
→ Checking git status...
Found unstaged changes that won't be included in deployment:
  modified:   hosts/xmsi/configuration.nix

CRITICAL: Nix flakes require changes to be staged with 'git add'.
Unstaged changes will be silently IGNORED during deployment.

Fix: Run 'git add .' to stage all changes, or stage specific files.
❌ Git staging validation failed
```

**Cause**: Changes not staged with `git add` (Nix flakes requirement)

**Solution**:
```bash
# Stage all changes
git add .

# Or stage specific files
git add hosts/xmsi/configuration.nix

# Verify staging
git status

# Expected: Changes under "Changes to be committed" section

# Retry deployment
just nixos-deploy xmsi
```

**Why this matters**: Nix flakes create a read-only copy of tracked files. Unstaged changes are not included, causing confusing failures where your changes don't take effect.

### 11.3 Syntax Validation Failed

**Symptom**: `nix flake check` fails with syntax errors

**Common Nix syntax errors**:

**Error 1**: Missing semicolon
```
error: syntax error, unexpected '}', expecting ';'
  at /path/to/file.nix:15:3
```
**Solution**: Add semicolon to end of attribute definition

**Error 2**: Undefined variable
```
error: undefined variable 'pkgs'
  at /path/to/file.nix:20:5
```
**Solution**: Import nixpkgs or pass pkgs as function parameter

**Error 3**: Import path error
```
error: file 'modules/nonexistent.nix' was not found
```
**Solution**: Fix import path or create missing file

**Debugging**:
```bash
# Check specific file syntax
nix-instantiate --parse file.nix

# Expected: Parsed expression output
# If error: Shows syntax error location

# Evaluate flake for specific host
nix eval .#nixosConfigurations.xmsi.config.system.build.toplevel

# Expected: Derivation path
# If error: Shows evaluation error with traceback
```

### 11.4 Terraform Authentication Failed

**Symptom**: `just tf-plan` fails with "401 Unauthorized"

**Output**:
```
Error: API authentication failed
API token invalid or missing required permissions.
```

**Cause 1**: Hetzner API token invalid or revoked

**Solution**:
```bash
# Verify token in secrets file
sops -d secrets/hetzner.yaml | grep hcloud

# Expected: hcloud: "64-character-token"

# Verify token length (should be 64 characters)
sops -d secrets/hetzner.yaml | grep hcloud | cut -d: -f2 | xargs | wc -c

# Expected output: 65 (64 + newline)

# If token wrong: Generate new token in Hetzner Console
# Navigate to: Project → Security → API Tokens → Generate API Token
# Update secrets/hetzner.yaml with new token
sops secrets/hetzner.yaml
```

**Cause 2**: Token permissions insufficient (Read-only instead of Read & Write)

**Solution**:
```bash
# Check token permissions in Hetzner Console
# Navigate to: Project → Security → API Tokens
# Verify token has "Read & Write" permissions

# If Read-only: Generate new token with Read & Write permissions
# Update secrets/hetzner.yaml
```

**Cause 3**: Age key missing (token cannot be decrypted)

**Solution**:
```bash
# Verify age key exists
ls -la ~/.config/sops/age/keys.txt

# Test decryption manually
sops -d secrets/hetzner.yaml

# Expected: Decrypted YAML content
# If error: Restore age key from backup
```

### 11.5 Terraform State Conflicts

**Symptom**: `just tf-apply` fails with state lock error

**Output**:
```
Error: Error acquiring the state lock

Terraform state is currently locked.
Lock ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Path: terraform/terraform.tfstate
```

**Cause**: Another `tofu` process is running or previous process crashed without releasing lock

**Solution**:
```bash
# Check for running Terraform processes
ps aux | grep tofu

# Expected: No tofu processes (or only your grep command)
# If tofu running: Wait for it to complete or kill it

# If no processes running but lock persists: Force unlock
cd terraform
tofu force-unlock <Lock-ID-from-error>

# Confirm unlock at prompt
# WARNING: Only force unlock if you're sure no other process is running

# Retry apply
just tf-apply
```

**Prevention**: Don't run multiple `tofu` operations concurrently.

### 11.6 Ansible Unreachable Hosts

**Symptom**: `ansible-playbook` fails with "UNREACHABLE!"

**Output**:
```
fatal: [mail-1.prod.nbg]: UNREACHABLE! => {
    "msg": "Failed to connect to the host via ssh",
    "unreachable": true
}
```

**Cause 1**: SSH connection failure (network, firewall, SSH daemon down)

**Solution**:
```bash
# Test SSH connection manually
ssh root@mail-1.prod.nbg

# If connection timeout: Check network connectivity
ping mail-1.prod.nbg

# If connection refused: Check SSH daemon
# May need to access via Hetzner Console (VNC) to restart SSH
```

**Cause 2**: SSH key authentication failure

**Solution**:
```bash
# Test SSH with specific key
ssh -i ~/.ssh/id_homelab root@mail-1.prod.nbg

# If fails: Check SSH key deployed to server
# Deploy public key:
ssh-copy-id -i ~/.ssh/id_homelab.pub root@mail-1.prod.nbg
```

**Cause 3**: Ansible inventory has wrong IP address

**Solution**:
```bash
# Update inventory from Terraform
just ansible-inventory-update

# Verify inventory has correct IPs
cat ansible/inventory/hosts.yaml | grep mail-1

# Expected: Correct IP address for host

# Retry Ansible
just ansible-ping
```

### 11.7 Services Failed to Start After Deployment

**Symptom**: NixOS deployment succeeds but services show "failed" status

**Debugging**:

```bash
# Step 1: Check which services failed
systemctl --failed

# Expected output: List of failed services

# Step 2: Check specific service status
systemctl status nginx

# Expected output:
# ● nginx.service - Nginx Web Server
#    Active: failed (Result: exit-code)
#    [Error details]

# Step 3: Check service logs
journalctl -u nginx -n 50

# Expected: Shows recent service logs with error details

# Step 4: Check configuration file syntax (if applicable)
nginx -t  # For nginx
sshd -t   # For SSH daemon

# Expected: Configuration test output
# If error: Fix configuration syntax
```

**Common causes**:
- **Port already in use**: Another service using the same port
- **Permission denied**: Service user lacks permissions to read config/data
- **Missing dependencies**: Required packages not installed
- **Configuration syntax error**: Invalid configuration file

**Solution**:
```bash
# Fix configuration issue
vim hosts/xmsi/configuration.nix

# Stage changes
git add .

# Redeploy
just nixos-deploy xmsi

# Verify service started
systemctl status nginx

# Expected: "active (running)"
```

### 11.8 Home Manager Activation Failed

**Symptom**: `home-manager switch` fails during activation

**Common errors**:

**Error 1**: File conflicts (existing dotfiles)
```
error: Existing file '/home/plumps/.zshrc' is not a symlink
```
**Solution**:
```bash
# Backup existing file
mv ~/.zshrc ~/.zshrc.backup

# Retry Home Manager activation
just home-deploy plumps@xbook

# Review backup file and merge changes if needed
```

**Error 2**: Package not available for platform
```
error: Package 'foo' is not available for 'aarch64-darwin'
```
**Solution**:
```bash
# Use platform conditional in Home Manager config
# modules/home/common.nix:

programs.foo.enable = pkgs.stdenv.isLinux;  # Linux only

# Or exclude package for specific platform
home.packages = with pkgs; [
  vim
  git
] ++ lib.optionals pkgs.stdenv.isLinux [
  linux-only-package
];
```

**Error 3**: Circular dependency
```
error: infinite recursion encountered
```
**Solution**:
```bash
# Check for circular imports in Home Manager config
# Common cause: Config A imports B, B imports A

# Break circular dependency by restructuring imports
# Or use lib.mkIf to conditionally enable features
```

### 11.9 Validation Script Failures

**Symptom**: `just validate-secrets` fails with validation errors

**Common validation errors**:

**Error 1**: Secret file not encrypted
```
❌ secrets/hetzner.yaml is not encrypted
```
**Solution**:
```bash
# Verify file is encrypted
file secrets/hetzner.yaml

# Expected: "data" or "binary" (encrypted)
# If "ASCII text": File not encrypted

# DO NOT COMMIT unencrypted secrets!
# Encrypt file with SOPS:
sops -e secrets/hetzner.yaml.plaintext > secrets/hetzner.yaml
rm secrets/hetzner.yaml.plaintext

# Verify encryption
sops -d secrets/hetzner.yaml

# Expected: Decrypted content
```

**Error 2**: Age key not accessible
```
❌ SOPS age key not found or not accessible
```
**Solution**:
```bash
# Check age key location
ls -la ~/.config/sops/age/keys.txt

# If missing: Restore from backup
# See docs/runbooks/age_key_bootstrap.md Section 8

# Verify permissions
chmod 600 ~/.config/sops/age/keys.txt
```

### 11.10 Network Connectivity Issues

**Symptom**: Servers cannot communicate over private network (10.0.0.x)

**Debugging**:

```bash
# Step 1: Verify server connected to network
hcloud server describe mail-1.prod.nbg | grep network

# Expected: Shows homelab network with IP 10.0.0.x

# Step 2: Test private network connectivity
ssh root@mail-1.prod.nbg "ping -c 3 10.0.0.y"

# Expected: 3 packets transmitted, 3 received
# If 100% packet loss: Network configuration issue

# Step 3: Check network interface on server
ssh root@mail-1.prod.nbg "ip addr show"

# Expected: Shows private network interface (eth1 or ens10) with 10.0.0.x IP
# If missing: Network interface not configured

# Step 4: Check firewall rules
ssh root@mail-1.prod.nbg "iptables -L -n"

# Expected: Rules allowing traffic from 10.0.0.0/16
# If blocked: Firewall rules too restrictive
```

**Solution**:
```bash
# Update Terraform network configuration
vim terraform/network.tf

# Ensure servers attached to network with correct IPs

# Update Ansible firewall configuration
vim ansible/roles/common/tasks/firewall.yaml

# Allow traffic from private network
# Example rule:
# - name: Allow traffic from private network
#   ansible.builtin.iptables:
#     chain: INPUT
#     source: 10.0.0.0/16
#     jump: ACCEPT

# Deploy configuration
git add terraform/ ansible/
just tf-apply
just ansible-deploy deploy
```

---

## 12. Related Documentation

### Core Infrastructure Documentation

- **[CLAUDE.md](../../CLAUDE.md)** - Project overview, architecture, essential commands
- **[Getting Started Guide](../../GETTING_STARTED.md)** - Initial setup for new operators

### Runbooks

- **[secrets_rotation.md](./secrets_rotation.md)** - Rotate age keys, API tokens, passwords, SSH keys
- **[age_key_bootstrap.md](./age_key_bootstrap.md)** - Deploy age keys to new systems and operators

### Configuration Files

- **[justfile](../../justfile)** - Task automation with validation gates (refactored I4.T1, enhanced I4.T2)
- **[.sops.yaml](../../.sops.yaml)** - SOPS configuration with age public keys
- **[terraform/](../../terraform/)** - Infrastructure as code for Hetzner Cloud
- **[ansible/](../../ansible/)** - Configuration management for VPS systems

### Validation and Scripts

- **[scripts/validate-secrets.sh](../../scripts/validate-secrets.sh)** - Secrets validation script
- **[docs/schemas/secrets_schema.yaml](../schemas/secrets_schema.yaml)** - JSON schema for secrets

### Sequence Diagrams

- **[nixos_deployment_with_secrets.puml](../diagrams/sequences/nixos_deployment_with_secrets.puml)** - NixOS deployment workflow
- **[terraform_provisioning_with_secrets.puml](../diagrams/sequences/terraform_provisioning_with_secrets.puml)** - Terraform provisioning workflow

### External Resources

- **Nix Flakes Manual**: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html
- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **nix-darwin Manual**: https://daiderd.com/nix-darwin/manual/index.html
- **Home Manager Manual**: https://nix-community.github.io/home-manager/
- **OpenTofu Documentation**: https://opentofu.org/docs/
- **Ansible Documentation**: https://docs.ansible.com/
- **Hetzner Cloud API**: https://docs.hetzner.cloud/
- **SOPS Documentation**: https://github.com/mozilla/sops

### When to Use Which Runbook

**Use this runbook (deployment_procedures.md) when**:
- Deploying NixOS, Darwin, or Home Manager configurations
- Provisioning Hetzner infrastructure with Terraform
- Deploying VPS configuration with Ansible
- Rolling back failed deployments

**Use secrets_rotation.md when**:
- Rotating age encryption keys (annually or after compromise)
- Rotating Hetzner API tokens (every 90 days)
- Rotating user passwords (every 90 days)
- Rotating SSH keys (annually)

**Use age_key_bootstrap.md when**:
- Setting up age keys for new operators
- Deploying age keys to new NixOS systems
- Deploying age keys to new Darwin systems
- Troubleshooting age key decryption issues

---

**Document Version**: 1.0
**Last Updated**: 2025-10-29
**Maintained By**: Infrastructure Team
**Review Cycle**: Quarterly or after deployment procedure changes
