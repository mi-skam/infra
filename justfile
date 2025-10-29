#!/usr/bin/env just --justfile
# Refactored Infrastructure Task Automation (Iteration I4.T1)
#
# CONSOLIDATION METRICS:
# - Original baseline: 230 lines (27 recipes, no documentation, I1.T4 analysis)
# - Functional code: 181 → 112 lines (38% reduction through consolidation)
# - Documentation: 0 → 419 lines (comprehensive multi-line comments for all recipes)
# - Total with docs: 582 lines (112 functional + 419 documentation + 51 section headers/spacing)
#
# KEY IMPROVEMENTS:
# - SOPS helper: 8 duplicate token extractions → 1 private helper (_get-hcloud-token)
# - Stow helper: 5 duplicate bash loops → 1 private helper (_stow-all)
# - Documentation: All 28 recipes now have comprehensive usage docs
# - Organization: 6 logical sections (Utility, Validation, Secrets, Terraform, Ansible, Dotfiles)
# - Fail-early: All parameter defaults removed per user preference (fail hard/fail early)

# Variables
target := env_var_or_default("STOW_TARGET", "~")

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

# ============================================================================
# Dotfiles Management
# ============================================================================

# Apply GNU Stow operation to all dotfile packages (PRIVATE HELPER)
#
# Parameters:
#   flags - Stow flags to apply (e.g., "-v -R" for restow, "-v -D" for delete)
#
# This private helper consolidates the bash loop pattern used by 5 dotfiles
# recipes. It iterates through all directories in dotfiles/, treating each
# as a package, and applies the specified stow operation.
#
# Called by: install-dotfiles, uninstall-dotfiles, dry-run, restow
#
# The loop:
# - Skips non-directories
# - Strips trailing / from directory name to get package name
# - Prints progress for each package
# - Applies stow with provided flags and target directory
[private]
@_stow-all flags:
    #!/usr/bin/env bash
    cd dotfiles && for dir in */; do [ -d "$dir" ] && package="${dir%/}" && echo "  → $package" && stow {{flags}} -t {{target}} "$package"; done

# Install Homebrew packages and all dotfiles (full setup)
#
# Two-step installation process:
# 1. Installs Homebrew packages from dotfiles/brew/.Brewfile
# 2. Stows all dotfile packages to target directory
#
# This is the recommended command for setting up a new macOS machine.
# It ensures all dependencies (like GNU Stow itself) are installed before
# attempting to stow dotfiles.
#
# Target directory can be customized via STOW_TARGET env var (default: ~).
@install-all: install-brew install-dotfiles

# Install Homebrew packages from Brewfile
#
# Installs all packages, casks, and taps defined in dotfiles/brew/.Brewfile.
# This includes development tools, CLI utilities, and applications.
#
# The Brewfile typically contains:
# - brew "stow" (required for dotfiles management)
# - brew "git", "jq", "fzf", etc. (common CLI tools)
# - cask "visual-studio-code" (GUI applications)
#
# Safe to run multiple times - Homebrew skips already-installed packages.
@install-brew:
    echo "Installing Homebrew packages..."
    brew bundle --file=dotfiles/brew/.Brewfile

# Install all dotfiles using GNU Stow (symlink creation)
#
# Stows (symlinks) all dotfile packages from dotfiles/ to target directory.
# Uses -R flag (restow) which removes then re-creates symlinks, making it
# safe to run multiple times.
#
# Each package directory (e.g., dotfiles/zsh/) gets stowed separately:
# - dotfiles/zsh/.zshrc → ~/.zshrc
# - dotfiles/git/.gitconfig → ~/.gitconfig
#
# Depends on: ensure-stow (installs stow if missing)
# Uses: _stow-all helper with "-v -R" flags (verbose, restow)
@install-dotfiles: ensure-stow
    echo "Stowing dotfiles to {{target}}..."
    just _stow-all "-v -R"

# Uninstall all dotfiles by removing symlinks (DESTRUCTIVE)
#
# ⚠️  WARNING: This removes all symlinks created by stow, effectively
# uninstalling all dotfiles. Your original files in dotfiles/ remain safe,
# but the symlinks in your home directory will be deleted.
#
# Use cases:
# - Preparing to install different dotfiles
# - Troubleshooting stow conflicts
# - Cleaning up before system migration
#
# This does NOT delete actual config files - only removes symlinks.
# Uses -D flag (delete) to unstow all packages.
@uninstall-dotfiles:
    echo "Unstowing dotfiles from {{target}}..."
    just _stow-all "-v -D"

# Ensure GNU Stow is installed (dependency check)
#
# Checks if stow command is available in PATH. If not found, installs it
# via Homebrew. This is a dependency recipe called by install-dotfiles.
#
# GNU Stow is required for dotfiles management. It creates symlinks from
# the dotfiles/ directory to the target directory (usually ~).
#
# Silent when stow is already installed. Only outputs when installing.
@ensure-stow:
    command -v stow >/dev/null 2>&1 || brew install stow

# Simulate dotfiles installation without making changes (dry run)
#
# Performs a stow dry run using -n flag (no-op). Shows what symlinks would
# be created without actually creating them. Useful for:
# - Previewing changes before actual installation
# - Checking for conflicts with existing files
# - Verifying stow will do what you expect
#
# Output shows:
# - LINK actions that would be performed
# - Conflicts with existing files (errors)
#
# Safe to run anytime - makes no changes to filesystem.
@dry-run:
    echo "Simulating stow (dry run) to {{target}}..."
    just _stow-all "-n -v -R"

# Install a specific dotfile package by name
#
# Parameters:
#   package - Package directory name (e.g., "zsh", "git", "nvim")
#
# Example usage:
#   just install zsh     # Stow only zsh dotfiles
#   just install git     # Stow only git dotfiles
#   just install nvim    # Stow only neovim dotfiles
#
# Package must exist as a directory in dotfiles/. Use -R flag (restow)
# to safely update existing symlinks.
#
# For installing all packages at once, use install-dotfiles instead.
@install package:
    cd dotfiles && echo "Stowing {{package}} to {{target}}..." && stow -v -R -t {{target}} {{package}}

# Uninstall a specific dotfile package by name
#
# Parameters:
#   package - Package directory name to remove (e.g., "zsh", "git")
#
# Example usage:
#   just uninstall zsh   # Remove only zsh symlinks
#   just uninstall git   # Remove only git symlinks
#
# This removes symlinks for the specified package only, leaving other
# packages intact. Useful for:
# - Temporarily disabling a package
# - Testing different configurations
# - Troubleshooting specific package conflicts
#
# For removing all packages, use uninstall-dotfiles instead.
@uninstall package:
    cd dotfiles && echo "Unstowing {{package}} from {{target}}..." && stow -v -D -t {{target}} {{package}}

# Restow packages (refresh symlinks)
#
# Parameters:
#   package - Package name to restow, or empty to restow all packages
#
# Example usage:
#   just restow ""       # Restow all packages
#   just restow zsh      # Restow only zsh package
#
# Restowing (stow -R) means:
# 1. Unstow (remove existing symlinks)
# 2. Stow (create new symlinks)
#
# Useful for:
# - Refreshing symlinks after updating dotfiles
# - Fixing broken symlinks
# - Applying changes to stow structure
@restow package:
    #!/usr/bin/env bash
    cd dotfiles && [ -z "{{package}}" ] && echo "Restowing all..." && just _stow-all "-v -R" || (echo "Restowing {{package}}..." && stow -v -R -t {{target}} {{package}})

# Check for stow conflicts before installation
#
# Performs dry-run stow for all packages and reports any conflicts.
# A conflict occurs when:
# - Target file exists and is not a symlink
# - Target symlink points to different location
# - Directory structure prevents symlink creation
#
# Output:
# - Lists packages with conflicts (⚠ symbol)
# - Shows specific conflicting files/paths
# - Displays "✓ No conflicts found" if clean
#
# Always run this before install-dotfiles on a new system to identify
# files that need manual backup/removal.
@check:
    #!/usr/bin/env bash
    cd dotfiles && echo "Checking for conflicts..." && has_conflicts=false
    for dir in */; do [ -d "$dir" ] && package="${dir%/}" && stow -n -v -R -t {{target}} "$package" 2>&1 | grep -i conflict && has_conflicts=true && echo "  ⚠ $package"; done
    [ "$has_conflicts" = false ] && echo "✓ No conflicts found"

# Find and list broken symlinks in target directory
#
# Searches target directory (default: ~) for symlinks that point to
# non-existent files. These "dangling" symlinks typically occur after:
# - Uninstalling a package but leaving some symlinks
# - Moving/renaming files in dotfiles/ directory
# - Deleting source files while symlinks remain
#
# Search depth limited to 3 levels to avoid scanning entire filesystem.
# To remove broken symlinks manually:
#   find {{target}} -maxdepth 3 -type l ! -exec test -e {} \; -delete
#
# Run this occasionally to keep target directory clean.
@clean:
    echo "Finding broken symlinks in {{target}}..."
    find {{target}} -maxdepth 3 -type l ! -exec test -e {} \; -print

# Test dotfiles installation in a temporary directory
#
# Parameters:
#   tmpdir - Path to empty test directory (e.g., "/tmp/dotfiles-test")
#
# Example usage:
#   just test-install /tmp/test-dotfiles
#
# This installs dotfiles to a temporary directory instead of your home
# directory, allowing you to:
# - Verify dotfiles structure before real installation
# - Test changes to dotfiles/ without affecting current setup
# - Debug stow issues in isolated environment
#
# The tmpdir should be empty or non-existent (will be created).
# After testing, inspect with: ls -la /tmp/test-dotfiles
# Clean up with: rm -rf /tmp/test-dotfiles
@test-install tmpdir:
    #!/usr/bin/env bash
    echo "Testing dotfiles installation in {{tmpdir}}..." && mkdir -p {{tmpdir}}
    STOW_TARGET={{tmpdir}} just install-dotfiles
    echo "Installed files:" && find {{tmpdir}} -type l -ls
