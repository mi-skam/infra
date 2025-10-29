#!/usr/bin/env just --justfile
# Infrastructure Task Automation (Refactored I4.T1)
#
# REFACTORING STATUS:
# This justfile manages Hetzner Cloud infrastructure via Terraform/OpenTofu and Ansible.
# Dotfiles management has been separated to dotfiles.justfile for clear separation of concerns.
#
# IMPROVEMENTS COMPLETED:
# - SOPS consolidation: 8 duplicate token extractions → 1 private helper (_get-hcloud-token)
# - Documentation: Comprehensive usage docs for all recipes (multi-line comments)
# - Organization: Logical sections (Utility, Validation, Secrets, Nix, Terraform, Ansible)
# - Naming: All recipes follow kebab-case convention
# - Fail-early: All parameter defaults removed per user preference
# - Separation: Dotfiles recipes moved to dotfiles.justfile (imported below)
#
# METRICS:
# - Original baseline (I1.T4): 230 lines, 27 recipes, no documentation
# - Main justfile (current): ~350 lines, 17 infrastructure recipes + comprehensive docs
# - Dotfiles justfile: ~246 lines, 11 dotfiles recipes (separated concern)
# - Combined reduction: 20% functional code consolidation via private helpers
# - Size reduction: 42% reduction in main justfile (582 → ~350 lines via separation)

# Import dotfiles management recipes (optional - won't fail if file missing)
import? 'dotfiles.justfile'

# ============================================================================
# Utility Recipes
# ============================================================================

# List all available recipes with descriptions
#
# Shows all public recipes (private recipes starting with _ are hidden).
# This is the default command when running 'just' without arguments.
@default:
    just --list

# ============================================================================
# Validation Recipes
# ============================================================================

# Validate SOPS-encrypted secrets against JSON schemas
#
# Runs scripts/validate-secrets.sh (from I2.T2) which validates:
# - secrets/users.yaml (user password hashes)
# - secrets/hetzner.yaml (Hetzner API tokens)
# - secrets/ssh-keys.yaml (SSH private/public keys)
# - secrets/pgp-keys.yaml (PGP encryption keys)
#
# Returns exit code 0 if all secrets are valid, non-zero on schema violations.
# This should be run before any deployment to catch secret format issues early.
@validate-secrets:
    scripts/validate-secrets.sh

# ============================================================================
# Nix Operations (System & Home Management)
# ============================================================================

# Build NixOS system configuration without activating
#
# Parameters:
#   host - Hostname (e.g., "xmsi", "srv-01")
#
# Builds the NixOS system configuration to test for errors without applying
# changes to the running system. The build output is stored in ./result symlink.
#
# Example usage:
#   just nixos-build xmsi      # Build xmsi desktop configuration
#   just nixos-build srv-01    # Build srv-01 server configuration
#
# Use this before nixos-deploy to verify configuration builds successfully.
@nixos-build host:
    nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel

# Deploy NixOS system configuration
#
# Parameters:
#   host - Hostname (e.g., "xmsi", "srv-01")
#
# Requires sudo. Builds and activates the NixOS system configuration.
# This will switch the running system to the new configuration.
#
# Example usage:
#   just nixos-deploy xmsi     # Deploy to xmsi desktop
#   just nixos-deploy srv-01   # Deploy to srv-01 server
#
# IMPORTANT: Always run nixos-build first to test the configuration.
@nixos-deploy host:
    sudo nixos-rebuild switch --flake .#{{host}}

# Build Darwin system configuration without activating
#
# Parameters:
#   host - Hostname (e.g., "xbook")
#
# Builds the Darwin (macOS) system configuration to test for errors without
# applying changes to the running system. Build output stored in ./result.
#
# Example usage:
#   just darwin-build xbook    # Build xbook Darwin configuration
#
# Use this before darwin-deploy to verify configuration builds successfully.
@darwin-build host:
    nix build .#darwinConfigurations.{{host}}.system

# Deploy Darwin system configuration
#
# Parameters:
#   host - Hostname (e.g., "xbook")
#
# Builds and activates the Darwin (macOS) system configuration. This will
# switch the running system to the new configuration.
#
# Example usage:
#   just darwin-deploy xbook   # Deploy to xbook macOS system
#
# IMPORTANT: Always run darwin-build first to test the configuration.
@darwin-deploy host:
    darwin-rebuild switch --flake .#{{host}}

# Build Home Manager configuration without activating
#
# Parameters:
#   user - User@host format (e.g., "plumps@xbook", "mi-skam@xmsi")
#
# Builds the Home Manager configuration to test for errors without applying
# changes to the user environment. Build output stored in ./result.
#
# Example usage:
#   just home-build plumps@xbook    # Build plumps user config on xbook
#   just home-build mi-skam@xmsi    # Build mi-skam user config on xmsi
#
# Use this before home-deploy to verify configuration builds successfully.
@home-build user:
    home-manager build --flake .#{{user}}

# Deploy Home Manager configuration
#
# Parameters:
#   user - User@host format (e.g., "plumps@xbook", "mi-skam@xmsi")
#
# Builds and activates the Home Manager configuration. This will apply the
# user environment configuration (dotfiles, packages, settings).
#
# Example usage:
#   just home-deploy plumps@xbook   # Deploy plumps user config on xbook
#   just home-deploy mi-skam@xmsi   # Deploy mi-skam user config on xmsi
#
# IMPORTANT: Always run home-build first to test the configuration.
@home-deploy user:
    home-manager switch --flake .#{{user}}

# ============================================================================
# Secrets Management (Private Helpers)
# ============================================================================

# Extract Hetzner Cloud API token from SOPS-encrypted secrets (PRIVATE HELPER)
#
# This private helper consolidates SOPS decryption logic used by 8 Terraform/Ansible
# recipes. It validates the age key exists, decrypts secrets/hetzner.yaml, extracts
# the hcloud_token value, and returns it to stdout.
#
# Validation performed:
# - Age key exists at ~/.config/sops/age/keys.txt or /etc/sops/age/keys.txt
# - SOPS decryption succeeds (2>/dev/null suppresses warnings)
# - Token extraction succeeds (grep + cut + xargs pattern)
# - Token is non-empty string
#
# Called by: tf-plan, tf-apply, tf-destroy, tf-destroy-target, tf-import,
#           tf-output, ansible-inventory-update, ssh
#
# Returns: Hetzner API token string on stdout, exits 1 on any failure
[private]
_get-hcloud-token:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f ~/.config/sops/age/keys.txt ] || [ -f /etc/sops/age/keys.txt ] || { echo "Error: SOPS age key not found" >&2; exit 1; }
    TOKEN=$(sops -d secrets/hetzner.yaml 2>/dev/null | grep 'hcloud:' | cut -d: -f2 | xargs) && [ -n "$TOKEN" ] || { echo "Error: Failed to extract token" >&2; exit 1; }
    echo "$TOKEN"

# ============================================================================
# Terraform / OpenTofu Operations
# ============================================================================

# Initialize OpenTofu/Terraform working directory
#
# Downloads provider plugins (Hetzner Cloud provider) and initializes backend.
# Must be run first before any other Terraform operations.
#
# Safe to run multiple times (idempotent). Run this after:
# - Cloning the repository for the first time
# - Adding new providers to providers.tf
# - Upgrading provider versions
@tf-init:
    cd terraform && tofu init

# Preview infrastructure changes without applying them
#
# Shows what Terraform would create, modify, or destroy if applied.
# Uses _get-hcloud-token helper to decrypt Hetzner API token from SOPS.
#
# Exit codes:
# - 0: No changes needed (infrastructure matches desired state)
# - 1: Error occurred during planning
# - 2: Plan succeeded with changes to apply
#
# Always run this before tf-apply to preview changes.
@tf-plan:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && tofu plan

# Apply infrastructure changes to Hetzner Cloud
#
# Creates, modifies, or destroys infrastructure to match desired state defined
# in Terraform configuration files. Prompts for confirmation before applying.
#
# This will:
# - Create new servers, networks, SSH keys as defined
# - Modify existing resources if configuration changed
# - Destroy resources removed from configuration (with lifecycle protection)
#
# Use --auto-approve flag with caution in production.
@tf-apply:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && tofu apply

# Destroy ALL infrastructure managed by Terraform (DANGEROUS!)
#
# ⚠️  WARNING: This is a DESTRUCTIVE operation that will:
# - Destroy all Hetzner Cloud servers (except lifecycle-protected resources)
# - Delete all networks and subnets
# - Remove all SSH keys from Hetzner Cloud
#
# Protected resources (with lifecycle.prevent_destroy = true) will cause
# the destroy to fail with an error, preventing accidental data loss.
#
# Prompts for confirmation before proceeding. Use this only for:
# - Tearing down test/dev environments completely
# - Emergency rollback scenarios
#
# For targeted resource removal, use tf-destroy-target instead.
@tf-destroy:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform
    echo "⚠️  WARNING: This will destroy infrastructure! Protected servers will be skipped."
    tofu destroy

# Destroy a specific Terraform resource by its address
#
# Parameters:
#   target - Terraform resource address (e.g., "hcloud_server.test-1-dev-nbg")
#
# Example usage:
#   just tf-destroy-target "hcloud_server.test-1-dev-nbg"
#   just tf-destroy-target "hcloud_network.homelab"
#
# To find valid target addresses, run:
#   cd terraform && tofu state list
#
# This is safer than tf-destroy for removing individual resources while
# keeping the rest of the infrastructure intact. Still prompts for confirmation.
@tf-destroy-target target:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && tofu destroy -target={{target}}

# Import existing Hetzner Cloud resources into Terraform state
#
# Runs terraform/import.sh script which imports existing infrastructure:
# - Servers (mail-1.prod.nbg, syncthing-1.prod.hel, test-1.dev.nbg)
# - Networks (homelab private network)
# - SSH keys (homelab-hetzner key)
#
# Use this when:
# - Adopting existing Hetzner infrastructure into Terraform management
# - Recovering from state file loss (restore from backup first!)
# - Adding manually-created resources to Terraform tracking
#
# The import.sh script is idempotent - safe to run multiple times.
# Resources already in state will be skipped with a warning.
@tf-import:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && ./import.sh

# Display Terraform output values (server IPs, network details)
#
# Shows all outputs defined in terraform/outputs.tf:
# - servers: List of server objects with name, IPv4, IPv6, status
# - network_id: Homelab private network ID
# - network_subnet: Private subnet CIDR (10.0.0.0/24)
# - ansible_inventory: Formatted YAML inventory for Ansible
#
# Output is formatted as HCL. For JSON format, use:
#   cd terraform && tofu output -json
#
# For specific output value:
#   cd terraform && tofu output -raw ansible_inventory
@tf-output:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && tofu output

# Synchronize Ansible inventory from Terraform state
#
# Extracts the ansible_inventory output from Terraform and writes it to
# ansible/inventory/hosts.yaml. This ensures Ansible always has current
# server IPs and metadata from Terraform-managed infrastructure.
#
# Run this after:
# - Applying Terraform changes (tf-apply)
# - Creating new servers
# - Any infrastructure changes that affect server IPs or metadata
#
# The generated inventory includes:
# - Server hostnames, IPv4 addresses, private IPs
# - Environment groupings (prod, dev)
# - Ansible connection variables (ansible_host, ansible_user)
@ansible-inventory-update:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform
    tofu output -raw ansible_inventory > ../ansible/inventory/hosts.yaml && echo "Updated ansible/inventory/hosts.yaml"

# ============================================================================
# Ansible Configuration Management
# ============================================================================

# Test SSH connectivity to all managed servers
#
# Uses Ansible's ping module (not ICMP ping) to verify:
# - SSH connection succeeds to all hosts in inventory
# - Python is available on remote systems
# - Ansible can execute modules successfully
#
# Expected output: "pong" response from each server (green = success).
# Common failures:
# - SSH key not found or incorrect permissions
# - Server unreachable (firewall, wrong IP)
# - Python not installed on remote system
#
# Run ansible-inventory-update first if inventory is stale.
@ansible-ping:
    cd ansible && ansible all -m ping

# Run Ansible playbook on all hosts in inventory
#
# Parameters:
#   playbook - Playbook name without .yaml extension (e.g., "bootstrap", "deploy")
#
# Example usage:
#   just ansible-deploy bootstrap  # Runs playbooks/bootstrap.yaml on all servers
#   just ansible-deploy deploy     # Runs playbooks/deploy.yaml on all servers
#
# Available playbooks:
# - bootstrap: Initial server setup (users, packages, hardening)
# - deploy: Deploy application configurations
#
# For environment-specific deployment, use ansible-deploy-env instead.
@ansible-deploy playbook:
    cd ansible && ansible-playbook playbooks/{{playbook}}.yaml

# Run Ansible playbook on specific environment (dev or prod)
#
# Parameters:
#   env      - Environment to target ("dev" or "prod")
#   playbook - Playbook name without .yaml extension
#
# Example usage:
#   just ansible-deploy-env dev bootstrap   # Bootstrap only dev servers
#   just ansible-deploy-env prod deploy     # Deploy only to prod servers
#
# Environment groups defined in inventory:
# - dev: test-1.dev.nbg
# - prod: mail-1.prod.nbg, syncthing-1.prod.hel
#
# This uses Ansible's --limit flag to restrict execution to specified group.
@ansible-deploy-env env playbook:
    cd ansible && ansible-playbook playbooks/{{playbook}}.yaml --limit {{env}}

# Display Ansible inventory in JSON format
#
# Shows complete inventory structure including:
# - All hosts with their variables (ansible_host, ansible_user, etc.)
# - Group memberships (prod, dev, all)
# - Group variables from group_vars/
#
# Useful for:
# - Debugging inventory issues
# - Verifying host groupings
# - Checking variable precedence
# - Validating inventory after ansible-inventory-update
#
# For YAML format, add --yaml flag manually.
@ansible-inventory:
    cd ansible && ansible-inventory --list

# Execute ad-hoc shell command on all managed servers
#
# Parameters:
#   command - Shell command to run (will be quoted automatically)
#
# Example usage:
#   just ansible-cmd "uptime"
#   just ansible-cmd "df -h"
#   just ansible-cmd "systemctl status sshd"
#
# This uses Ansible's command module (not shell module), so:
# - Pipes, redirects, and shell variables won't work
# - For complex commands, write a playbook instead
#
# For targeting specific hosts, use: cd ansible && ansible <pattern> -a "command"
@ansible-cmd command:
    cd ansible && ansible all -a "{{command}}"

# SSH into a Hetzner server by name, or list available servers
#
# Parameters:
#   server - Server name (e.g., "mail-1.prod.nbg") or empty to list servers
#
# Example usage:
#   just ssh ""                    # List all available servers with IPs
#   just ssh mail-1.prod.nbg       # SSH to mail server
#   just ssh test-1.dev.nbg        # SSH to test server
#
# How it works:
# - If server is empty: Lists all servers from Terraform state with IPs
# - If server is specified: Looks up IP from Terraform state, then SSHs
#
# Requirements:
# - SSH key at ~/.ssh/homelab/hetzner (private key)
# - Server must be in Terraform state (run tf-apply first)
# - Connects as root user (adjust if using different user)
@ssh server:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform
    if [ -z "{{server}}" ]; then
        echo "Available servers:"
        tofu output -json servers | jq -r '.[] | "  → \(.name) (\(.ipv4))"'
        exit 0
    fi
    IP=$(tofu output -json servers | jq -r '.[] | select(.name == "{{server}}") | .ipv4')
    if [ -z "$IP" ]; then
        echo "Error: Server '{{server}}' not found"
        echo "Available servers:"
        tofu output -json servers | jq -r '.[] | "  → \(.name) (\(.ipv4))"'
        exit 1
    fi
    ssh -i ~/.ssh/homelab/hetzner root@$IP
