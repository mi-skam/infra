#!/usr/bin/env just --justfile

# ============================================================================
# Variables
# ============================================================================

# Target directory for stow (defaults to home)
target := env_var_or_default("STOW_TARGET", "~")

# ============================================================================
# Utility Recipes
# ============================================================================

# List available recipes
@default:
    just --list

# ============================================================================
# Validation Recipes
# ============================================================================

# Validate SOPS secrets against schema
@validate-secrets:
    scripts/validate-secrets.sh

# ============================================================================
# Secrets Management (Private Helpers)
# ============================================================================

# Extract and validate Hetzner API token from SOPS-encrypted secrets
#
# This private helper validates age key existence and extracts the Hetzner
# Cloud API token. Returns the token value for use by Terraform recipes.
# Used as part of a command substitution in Terraform operations.
[private]
_get-hcloud-token:
    #!/usr/bin/env bash
    set -euo pipefail
    # Validate SOPS age key exists
    if [ ! -f ~/.config/sops/age/keys.txt ] && [ ! -f /etc/sops/age/keys.txt ]; then
        echo "Error: SOPS age private key not found" >&2
        echo "Expected locations:" >&2
        echo "  - ~/.config/sops/age/keys.txt" >&2
        echo "  - /etc/sops/age/keys.txt" >&2
        exit 1
    fi
    # Extract Hetzner token
    TOKEN=$(sops -d secrets/hetzner.yaml 2>/dev/null | grep 'hcloud:' | cut -d: -f2 | xargs)
    if [ -z "$TOKEN" ]; then
        echo "Error: Failed to extract Hetzner API token from secrets/hetzner.yaml" >&2
        exit 1
    fi
    echo "$TOKEN"

# ============================================================================
# Terraform / OpenTofu Operations
# ============================================================================

# Initialize OpenTofu/Terraform working directory
#
# Must be run before any other Terraform operations. Downloads providers
# and modules, and initializes backend state.
@tf-init:
    cd terraform && tofu init

# Plan infrastructure changes
#
# Shows what changes will be made without applying them. Use this to review
# changes before running tf-apply.
@tf-plan:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform && tofu plan

# Apply infrastructure changes
#
# Applies the planned changes to create, update, or delete infrastructure
# resources. Prompts for confirmation before making changes.
@tf-apply:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform && tofu apply

# Destroy infrastructure (WARNING: destructive!)
#
# Destroys all infrastructure managed by Terraform. Protected servers with
# prevent_destroy=true will be skipped. Always review with tf-plan first.
@tf-destroy:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform
    echo "⚠️  WARNING: This will destroy infrastructure!"
    echo "Protected servers (prevent_destroy=true) will be skipped."
    tofu destroy

# Destroy specific Terraform resource
#
# Usage: just tf-destroy-target hcloud_server.test2_dev_nbg
#
# Destroys only the specified resource. Use 'tofu state list' to see
# available resource addresses.
@tf-destroy-target target:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform && tofu destroy -target={{target}}

# Import existing Hetzner resources into Terraform state
#
# Imports existing cloud resources (servers, networks, SSH keys) into
# Terraform state using the import.sh script. Run this for the initial
# setup or to recover from state loss.
@tf-import:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform && ./import.sh

# Show Terraform output values
#
# Displays all output values defined in outputs.tf, including server IPs,
# network configuration, and other exported data.
@tf-output:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform && tofu output

# Update Ansible inventory from Terraform outputs
#
# Extracts server information from Terraform state and writes it to
# ansible/inventory/hosts.yaml. Run this after infrastructure changes
# to keep Ansible inventory synchronized.
@ansible-inventory-update:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform
    tofu output -raw ansible_inventory > ../ansible/inventory/hosts.yaml
    echo "Updated ansible/inventory/hosts.yaml from Terraform output"

# ============================================================================
# Ansible Configuration Management
# ============================================================================

# Test SSH connectivity to all managed servers
#
# Runs Ansible ping module to verify SSH access and Python availability
# on all hosts. Useful for troubleshooting connectivity issues.
@ansible-ping:
    cd ansible && ansible all -m ping

# Run Ansible playbook on all hosts
#
# Usage: just ansible-deploy bootstrap
#        just ansible-deploy deploy
#        just ansible-deploy setup-storagebox
#
# Executes the specified playbook from ansible/playbooks/ directory.
@ansible-deploy playbook:
    cd ansible && ansible-playbook playbooks/{{playbook}}.yaml

# Run Ansible playbook on specific environment
#
# Usage: just ansible-deploy-env dev bootstrap
#        just ansible-deploy-env prod deploy
#
# Limits playbook execution to hosts in the specified environment (dev/prod).
@ansible-deploy-env env playbook:
    cd ansible && ansible-playbook playbooks/{{playbook}}.yaml --limit {{env}}

# List Ansible inventory in JSON format
#
# Shows all managed hosts with their variables, groups, and metadata.
# Useful for verifying inventory structure and variable assignments.
@ansible-inventory:
    cd ansible && ansible-inventory --list

# Run ad-hoc Ansible command on all hosts
#
# Usage: just ansible-cmd "uptime"
#        just ansible-cmd "df -h"
#
# Executes a shell command on all managed hosts using Ansible's command module.
@ansible-cmd command:
    cd ansible && ansible all -a "{{command}}"

# SSH into a server by name or list all available servers
#
# Usage: just ssh test-1.dev.nbg  (connect to server)
#        just ssh                 (list available servers)
#
# Looks up server IP from Terraform state and connects via SSH using the
# homelab SSH key. Requires Terraform state to be initialized.
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

# Apply stow operation to all dotfile packages (private helper)
#
# Usage: just _stow-all "-v -R"  (install/restow)
#        just _stow-all "-v -D"  (uninstall)
#        just _stow-all "-n -v -R"  (dry run)
#
# Iterates through all directories in dotfiles/ and applies the specified
# stow flags to each package. Used by install-dotfiles, uninstall-dotfiles,
# dry-run, and restow recipes.
[private]
@_stow-all flags:
    #!/usr/bin/env bash
    cd dotfiles
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            echo "  → Processing $package..."
            stow {{flags}} -t {{target}} "$package"
        fi
    done

# Install Homebrew packages and all dotfiles
#
# Convenience recipe that runs install-brew followed by install-dotfiles.
@install-all: install-brew install-dotfiles

# Install Homebrew packages from Brewfile
#
# Installs packages, casks, and Mac App Store apps defined in
# dotfiles/brew/.Brewfile using Homebrew Bundle.
@install-brew:
    echo "Installing Homebrew packages..."
    brew bundle --file=dotfiles/brew/.Brewfile

# Install all dotfiles using GNU Stow
#
# Stows all dotfile packages to the target directory (default: ~).
# Creates symlinks for each package's configuration files. Ensures
# stow is installed before proceeding.
@install-dotfiles: ensure-stow
    echo "Stowing dotfiles to {{target}}..."
    just _stow-all "-v -R"

# Uninstall all dotfiles (remove symlinks)
#
# Unstows all dotfile packages from the target directory, removing the
# symlinks created by install-dotfiles. Original files in dotfiles/ are
# preserved.
@uninstall-dotfiles:
    echo "Unstowing dotfiles from {{target}}..."
    just _stow-all "-v -D"

# Ensure GNU Stow is installed
#
# Checks if stow command is available, installs it via Homebrew if missing.
# Used as a dependency for dotfiles operations.
@ensure-stow:
    command -v stow >/dev/null 2>&1 || brew install stow

# Simulate stow operations without making changes (dry run)
#
# Shows what would happen if install-dotfiles were run, without actually
# creating any symlinks. Useful for previewing changes before installation.
@dry-run:
    echo "Simulating stow (dry run) to {{target}}..."
    just _stow-all "-n -v -R"

# Install a specific dotfile package
#
# Usage: just install zsh
#        just install nvim
#
# Stows only the specified package from dotfiles/ directory. Useful for
# installing individual configuration sets.
@install package:
    cd dotfiles && echo "Stowing {{package}} to {{target}}..." && stow -v -R -t {{target}} {{package}}

# Uninstall a specific dotfile package
#
# Usage: just uninstall zsh
#        just uninstall nvim
#
# Unstows only the specified package, removing its symlinks from the target
# directory. The original files in dotfiles/ are preserved.
@uninstall package:
    cd dotfiles && echo "Unstowing {{package}} from {{target}}..." && stow -v -D -t {{target}} {{package}}

# Restow all packages or a specific package
#
# Usage: just restow           (restow all packages)
#        just restow zsh       (restow specific package)
#
# Useful after adding new files to a package or fixing conflicts. Removes
# and recreates symlinks to pick up any changes.
@restow package:
    #!/usr/bin/env bash
    cd dotfiles
    if [ -z "{{package}}" ]; then
        echo "Restowing all packages to {{target}}..."
        just _stow-all "-v -R"
    else
        echo "Restowing {{package}} to {{target}}..."
        stow -v -R -t {{target}} {{package}}
    fi

# Check for stow conflicts before installation
#
# Performs a dry run of stow operations and reports any conflicts that would
# prevent installation. Run this before install-dotfiles to identify issues.
@check:
    #!/usr/bin/env bash
    cd dotfiles
    echo "Checking for conflicts in {{target}}..."
    has_conflicts=false
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            if stow -n -v -R -t {{target}} "$package" 2>&1 | grep -i conflict; then
                has_conflicts=true
                echo "  ⚠ Conflicts found in $package"
            fi
        fi
    done
    if [ "$has_conflicts" = false ]; then
        echo "✓ No conflicts found"
    fi

# Find and list broken symlinks in target directory
#
# Searches the target directory (up to 3 levels deep) for symlinks that
# point to non-existent files. Useful for cleaning up after uninstalling
# packages or moving dotfiles.
@clean:
    echo "Finding broken symlinks in {{target}}..."
    find {{target}} -maxdepth 3 -type l ! -exec test -e {} \; -print

# Test dotfiles installation in a temporary directory
#
# Usage: just test-install /tmp/test-dotfiles
#
# Installs dotfiles to a temporary directory for testing without affecting
# your actual home directory. Lists all created symlinks after installation.
@test-install tmpdir:
    #!/usr/bin/env bash
    echo "Testing dotfiles installation in {{tmpdir}}..."
    mkdir -p {{tmpdir}}
    STOW_TARGET={{tmpdir}} just install-dotfiles
    echo ""
    echo "Installed files in {{tmpdir}}:"
    find {{tmpdir}} -type l -ls
