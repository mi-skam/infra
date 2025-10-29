#!/usr/bin/env just --justfile

# Variables
target := env_var_or_default("STOW_TARGET", "~")

# Utility Recipes
# List available recipes
@default:
    just --list

# Validation Recipes
# Validate SOPS secrets against schema
@validate-secrets:
    scripts/validate-secrets.sh

# Secrets Management (Private Helpers)
# Extract Hetzner API token from SOPS
[private]
_get-hcloud-token:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f ~/.config/sops/age/keys.txt ] || [ -f /etc/sops/age/keys.txt ] || { echo "Error: SOPS age key not found" >&2; exit 1; }
    TOKEN=$(sops -d secrets/hetzner.yaml 2>/dev/null | grep 'hcloud:' | cut -d: -f2 | xargs) && [ -n "$TOKEN" ] || { echo "Error: Failed to extract token" >&2; exit 1; }
    echo "$TOKEN"

# Terraform / OpenTofu Operations
# Initialize OpenTofu/Terraform working directory
@tf-init:
    cd terraform && tofu init

# Plan infrastructure changes
@tf-plan:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && tofu plan

# Apply infrastructure changes
@tf-apply:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && tofu apply

# Destroy infrastructure (WARNING: destructive!)
@tf-destroy:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform
    echo "⚠️  WARNING: This will destroy infrastructure! Protected servers will be skipped."
    tofu destroy

# Destroy specific Terraform resource by address
@tf-destroy-target target:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && tofu destroy -target={{target}}

# Import existing Hetzner resources into Terraform state
@tf-import:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && ./import.sh

# Show Terraform output values
@tf-output:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform && tofu output

# Update Ansible inventory from Terraform outputs
@ansible-inventory-update:
    #!/usr/bin/env bash
    set -euo pipefail
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)" && cd terraform
    tofu output -raw ansible_inventory > ../ansible/inventory/hosts.yaml && echo "Updated ansible/inventory/hosts.yaml"

# Ansible Configuration Management
# Test SSH connectivity to all managed servers
@ansible-ping:
    cd ansible && ansible all -m ping

# Run Ansible playbook on all hosts
@ansible-deploy playbook:
    cd ansible && ansible-playbook playbooks/{{playbook}}.yaml

# Run Ansible playbook on specific environment (dev/prod)
@ansible-deploy-env env playbook:
    cd ansible && ansible-playbook playbooks/{{playbook}}.yaml --limit {{env}}

# List Ansible inventory in JSON format
@ansible-inventory:
    cd ansible && ansible-inventory --list

# Run ad-hoc Ansible command on all hosts
@ansible-cmd command:
    cd ansible && ansible all -a "{{command}}"

# SSH into a server by name or list all available servers
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

# Dotfiles Management
# Apply stow to all dotfile packages (private helper)
[private]
@_stow-all flags:
    #!/usr/bin/env bash
    cd dotfiles && for dir in */; do [ -d "$dir" ] && package="${dir%/}" && echo "  → $package" && stow {{flags}} -t {{target}} "$package"; done

# Install Homebrew packages and all dotfiles
@install-all: install-brew install-dotfiles

# Install Homebrew packages from Brewfile
@install-brew:
    echo "Installing Homebrew packages..."
    brew bundle --file=dotfiles/brew/.Brewfile

# Install all dotfiles using GNU Stow
@install-dotfiles: ensure-stow
    echo "Stowing dotfiles to {{target}}..."
    just _stow-all "-v -R"

# Uninstall all dotfiles (remove symlinks)
@uninstall-dotfiles:
    echo "Unstowing dotfiles from {{target}}..."
    just _stow-all "-v -D"

# Ensure GNU Stow is installed
@ensure-stow:
    command -v stow >/dev/null 2>&1 || brew install stow

# Simulate stow operations without making changes (dry run)
@dry-run:
    echo "Simulating stow (dry run) to {{target}}..."
    just _stow-all "-n -v -R"

# Install a specific dotfile package
@install package:
    cd dotfiles && echo "Stowing {{package}} to {{target}}..." && stow -v -R -t {{target}} {{package}}

# Uninstall a specific dotfile package
@uninstall package:
    cd dotfiles && echo "Unstowing {{package}} from {{target}}..." && stow -v -D -t {{target}} {{package}}

# Restow packages (all if no package specified)
@restow package:
    #!/usr/bin/env bash
    cd dotfiles && [ -z "{{package}}" ] && echo "Restowing all..." && just _stow-all "-v -R" || (echo "Restowing {{package}}..." && stow -v -R -t {{target}} {{package}})

# Check for stow conflicts before installation
@check:
    #!/usr/bin/env bash
    cd dotfiles && echo "Checking for conflicts..." && has_conflicts=false
    for dir in */; do [ -d "$dir" ] && package="${dir%/}" && stow -n -v -R -t {{target}} "$package" 2>&1 | grep -i conflict && has_conflicts=true && echo "  ⚠ $package"; done
    [ "$has_conflicts" = false ] && echo "✓ No conflicts found"

# Find and list broken symlinks in target directory
@clean:
    echo "Finding broken symlinks in {{target}}..."
    find {{target}} -maxdepth 3 -type l ! -exec test -e {} \; -print

# Test dotfiles installation in a temporary directory
@test-install tmpdir:
    #!/usr/bin/env bash
    echo "Testing dotfiles installation in {{tmpdir}}..." && mkdir -p {{tmpdir}}
    STOW_TARGET={{tmpdir}} just install-dotfiles
    echo "Installed files:" && find {{tmpdir}} -type l -ls
