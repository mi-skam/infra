#!/usr/bin/env just --justfile

# Target directory for stow (defaults to home)
target := env_var_or_default("STOW_TARGET", "~")

# Hetzner API token from SOPS
hcloud_token := `sops -d secrets/hetzner.yaml 2>/dev/null | grep hcloud_token | cut -d: -f2 | xargs || echo ""`

# List available recipes
@default:
    just --list

# ============================================================================
# Terraform / OpenTofu Commands
# ============================================================================

# Initialize OpenTofu/Terraform
@tf-init:
    cd terraform && tofu init

# Plan infrastructure changes
@tf-plan:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
    tofu plan

# Apply infrastructure changes
@tf-apply:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
    tofu apply

# Destroy infrastructure (WARNING: destructive!)
@tf-destroy:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
    echo "⚠️  WARNING: This will destroy infrastructure!"
    echo "Protected servers (prevent_destroy=true) will be skipped."
    tofu destroy

# Destroy specific resource (e.g., just tf-destroy-target hcloud_server.test2_dev_nbg)
@tf-destroy-target target:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
    tofu destroy -target={{target}}

# Import existing Hetzner resources
@tf-import:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
    ./import.sh

# Show Terraform outputs
@tf-output:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
    tofu output

# Update Ansible inventory from Terraform output
@ansible-inventory-update:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
    tofu output -raw ansible_inventory > ../ansible/inventory/hosts.yaml
    echo "Updated ansible/inventory/hosts.yaml from Terraform output"

# ============================================================================
# Ansible Commands
# ============================================================================

# Test connectivity to all servers
@ansible-ping:
    cd ansible && ansible all -m ping

# Run Ansible playbook (e.g., just ansible-deploy bootstrap, just ansible-deploy deploy, just ansible-deploy setup-storagebox)
@ansible-deploy playbook:
    cd ansible && ansible-playbook playbooks/{{playbook}}.yaml

# Run Ansible playbook on specific environment (e.g., just ansible-deploy-to dev bootstrap)
@ansible-deploy-to env playbook:
    cd ansible && ansible-playbook playbooks/{{playbook}}.yaml --limit {{env}}

# List Ansible inventory
@ansible-inventory:
    cd ansible && ansible-inventory --list

# Run ad-hoc Ansible command
@ansible-cmd command:
    cd ansible && ansible all -a "{{command}}"

# SSH into a server by name (e.g., just ssh test-2.dev.nbg) or list all servers if no argument
@ssh server="":
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"

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
# Validation Commands
# ============================================================================

# Validate SOPS secrets against schema
@validate-secrets:
    scripts/validate-secrets.sh

# ============================================================================
# Dotfiles Commands (existing)
# ============================================================================

# Install all dotfiles
@install-all: install-brew install-dotfiles

# Install Homebrew packages
@install-brew:
    echo "Installing Homebrew packages..."
    brew bundle --file=dotfiles/brew/.Brewfile

# Install dotfiles using stow
@install-dotfiles: ensure-stow
    #!/usr/bin/env bash
    cd dotfiles
    echo "Stowing dotfiles to {{target}}..."
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            echo "  → Stowing $package..."
            stow -v -R -t {{target}} "$package"
        fi
    done

# Uninstall dotfiles
@uninstall-dotfiles:
    #!/usr/bin/env bash
    cd dotfiles
    echo "Unstowing dotfiles from {{target}}..."
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            echo "  → Unstowing $package..."
            stow -v -D -t {{target}} "$package"
        fi
    done

# Ensure stow is installed
@ensure-stow:
    command -v stow >/dev/null 2>&1 || brew install stow

# Simulate stow (dry run)
@dry-run:
    #!/usr/bin/env bash
    cd dotfiles
    echo "Simulating stow (dry run) to {{target}}..."
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            echo "  → Dry run for $package..."
            stow -n -v -R -t {{target}} "$package"
        fi
    done

# Install a specific package
@install package:
    cd dotfiles && echo "Stowing {{package}} to {{target}}..." && stow -v -R -t {{target}} {{package}}

# Uninstall a specific package
@uninstall package:
    cd dotfiles && echo "Unstowing {{package}} from {{target}}..." && stow -v -D -t {{target}} {{package}}

# Restow (useful after adding new files)
@restow package="":
    #!/usr/bin/env bash
    cd dotfiles
    if [ -z "{{package}}" ]; then
        echo "Restowing all packages to {{target}}..."
        for dir in */; do
            if [ -d "$dir" ]; then
                package="${dir%/}"
                echo "  → Restowing $package..."
                stow -v -R -t {{target}} "$package"
            fi
        done
    else
        echo "Restowing {{package}} to {{target}}..."
        stow -v -R -t {{target}} {{package}}
    fi

# Check for conflicts
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

# Clean broken symlinks in target directory
@clean:
    echo "Finding broken symlinks in {{target}}..."
    find {{target}} -maxdepth 3 -type l ! -exec test -e {} \; -print

# Test with a temporary directory
@test-install tmpdir="/tmp/dotfiles-test":
    #!/usr/bin/env bash
    echo "Testing dotfiles installation in {{tmpdir}}..."
    mkdir -p {{tmpdir}}
    STOW_TARGET={{tmpdir}} just install-dotfiles
    echo ""
    echo "Installed files in {{tmpdir}}:"
    find {{tmpdir}} -type l -ls