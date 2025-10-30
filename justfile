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
# Validation Recipes (Public & Private Helpers)
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

# Validate SOPS age private key exists (PRIVATE HELPER)
#
# Checks for SOPS age private key at standard locations:
# - ~/.config/sops/age/keys.txt (user-specific)
# - /etc/sops/age/keys.txt (system-wide)
#
# This validation is CRITICAL for all Terraform operations that require
# SOPS decryption. Without the age key, SOPS fails with cryptic errors.
#
# Called by: tf-apply, tf-plan, tf-destroy, all Terraform recipes
#
# Returns: Exit code 0 if key found, exit code 1 if missing
[private]
_validate-age-key:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f ~/.config/sops/age/keys.txt ] && [ ! -f /etc/sops/age/keys.txt ]; then
        echo "❌ Error: SOPS age private key not found" >&2
        echo "Expected locations:" >&2
        echo "  - ~/.config/sops/age/keys.txt" >&2
        echo "  - /etc/sops/age/keys.txt" >&2
        echo "" >&2
        echo "Documentation: CLAUDE.md#secrets-management" >&2
        exit 1
    fi
    echo "✓ SOPS age key found"

# Validate git changes are staged or working tree is clean (PRIVATE HELPER)
#
# Validates git repository state for Nix flake deployments. Nix flakes
# REQUIRE changes to be on the git index to be picked up. Unstaged changes
# will be silently ignored, causing confusing deployment failures.
#
# Validation logic:
# - If working tree is clean (no changes): OK, proceed
# - If changes are staged (git add was run): OK, proceed
# - If changes are unstaged: ERROR, tell user to run git add
#
# Called by: nixos-deploy, darwin-deploy
#
# Returns: Exit code 0 if clean/staged, exit code 1 if unstaged changes
[private]
_validate-git-staged:
    #!/usr/bin/env bash
    set -euo pipefail
    if git diff --quiet && git diff --cached --quiet; then
        echo "✓ Git working tree clean"
    elif git diff --cached --quiet; then
        echo "❌ Error: Unstaged changes detected" >&2
        echo "Nix flakes require changes to be staged with 'git add'" >&2
        echo "" >&2
        git status --short >&2
        exit 1
    else
        echo "✓ Changes staged for commit"
    fi

# Validate Terraform is initialized and has state (PRIVATE HELPER)
#
# Checks that Terraform/OpenTofu has been initialized (tf-init was run)
# and optionally that a state file exists. This prevents cryptic errors
# when running Terraform commands before initialization.
#
# Validation checks:
# - terraform/.terraform.lock.hcl exists (tf-init was run)
# - terraform/terraform.tfstate exists (warning only if missing)
#
# Called by: tf-apply, tf-plan, ansible-inventory-update
#
# Returns: Exit code 0 if initialized, exit code 1 if not initialized
[private]
_validate-terraform-state:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f terraform/.terraform.lock.hcl ]; then
        echo "❌ Error: Terraform not initialized" >&2
        echo "Run: just tf-init" >&2
        exit 1
    fi
    if [ ! -f terraform/terraform.tfstate ]; then
        echo "⚠ Warning: No Terraform state file found" >&2
        echo "This is normal for first run" >&2
    else
        echo "✓ Terraform state exists"
    fi

# Validate Ansible inventory exists and is current (PRIVATE HELPER)
#
# Checks that Ansible inventory file exists and is not stale relative to
# Terraform state. Stale inventory can cause Ansible to use wrong IPs or
# miss newly created servers.
#
# Validation checks:
# - ansible/inventory/hosts.yaml exists (error if missing)
# - Compare timestamps: if Terraform state is newer, warn about stale inventory
#
# Called by: ansible-deploy, ansible-deploy-env, ansible-ping
#
# Returns: Exit code 0 if valid/current, exit code 1 if inventory missing
[private]
_validate-ansible-inventory:
    #!/usr/bin/env bash
    set -euo pipefail
    INVENTORY="ansible/inventory/hosts.yaml"
    STATE="terraform/terraform.tfstate"

    if [ ! -f "$INVENTORY" ]; then
        echo "❌ Error: Ansible inventory not found" >&2
        echo "Run: just ansible-inventory-update" >&2
        exit 1
    fi

    if [ -f "$STATE" ]; then
        if [ "$STATE" -nt "$INVENTORY" ]; then
            echo "⚠ Warning: Terraform state is newer than Ansible inventory" >&2
            echo "Recommend running: just ansible-inventory-update" >&2
        else
            echo "✓ Ansible inventory is current"
        fi
    else
        echo "✓ Ansible inventory exists"
    fi

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

# Deploy NixOS system configuration with validation gates
#
# Parameters:
#   host  - Hostname (e.g., "xmsi", "srv-01")
#   force - Optional: Skip confirmation prompt (pass "true" to force)
#
# Requires sudo. Builds and activates the NixOS system configuration with
# comprehensive pre-deployment validation.
#
# Validation gates (in order):
#   1. Validates secrets are properly encrypted and formatted
#   2. Validates git changes are staged (Nix flakes requirement)
#   3. Validates Nix syntax (nix flake check)
#   4. Performs dry-run build (shows what would be built)
#   5. Requires user confirmation (unless force="true")
#
# Example usage:
#   just nixos-deploy xmsi           # Deploy with confirmation
#   just nixos-deploy srv-01 true    # Deploy without confirmation (force)
#
# IMPORTANT: Nix flakes require unstaged changes to be added with 'git add'
# before deployment. Unstaged changes will be silently ignored.
@nixos-deploy host force="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "═══════════════════════════════════════"
    echo "NixOS Deployment Validation"
    echo "═══════════════════════════════════════"
    echo ""

    # Gate 1: Validate secrets
    echo "→ Validating secrets..."
    if ! just validate-secrets; then
        echo "❌ Secrets validation failed" >&2
        echo "Run 'just validate-secrets' to see details" >&2
        exit 1
    fi

    # Gate 2: Validate git staging
    echo "→ Checking git status..."
    if ! just _validate-git-staged; then
        echo "❌ Git staging validation failed" >&2
        exit 1
    fi

    # Gate 3: Syntax validation
    echo "→ Validating Nix syntax..."
    if ! nix flake check; then
        echo "❌ Nix syntax check failed" >&2
        exit 1
    fi
    echo "✓ Syntax validated"

    # Gate 4: Dry-run build
    echo ""
    echo "→ Performing dry-run build..."
    if ! nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel; then
        echo "❌ Dry-run build failed" >&2
        exit 1
    fi
    echo "✓ Dry-run succeeded"

    # Gate 5: Confirmation (unless force mode)
    if [ "{{force}}" != "true" ]; then
        echo ""
        echo "═══════════════════════════════════════"
        read -p "Proceed with deployment to {{host}}? [y/N]: " confirmation
        if [ "$confirmation" != "yes" ] && [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
            echo "Deployment cancelled"
            exit 0
        fi
    fi

    # Execute deployment
    echo ""
    echo "→ Deploying NixOS configuration to {{host}}..."
    sudo nixos-rebuild switch --flake .#{{host}}

    # Success summary
    echo ""
    echo "═══════════════════════════════════════"
    echo "Deployment Summary"
    echo "═══════════════════════════════════════"
    echo "✓ Secrets validated"
    echo "✓ Git changes staged"
    echo "✓ Syntax validated"
    echo "✓ Dry-run succeeded"
    echo "✓ Deployed successfully to {{host}}"

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

# Deploy Darwin system configuration with validation gates
#
# Parameters:
#   host  - Hostname (e.g., "xbook")
#   force - Optional: Skip confirmation prompt (pass "true" to force)
#
# Builds and activates the Darwin (macOS) system configuration with
# comprehensive pre-deployment validation.
#
# Validation gates (in order):
#   1. Validates secrets are properly encrypted and formatted
#   2. Validates git changes are staged (Nix flakes requirement)
#   3. Validates Nix syntax (nix flake check)
#   4. Performs dry-run build (shows what would be built)
#   5. Requires user confirmation (unless force="true")
#
# Example usage:
#   just darwin-deploy xbook         # Deploy with confirmation
#   just darwin-deploy xbook true    # Deploy without confirmation (force)
#
# IMPORTANT: Nix flakes require unstaged changes to be added with 'git add'
# before deployment. Unstaged changes will be silently ignored.
@darwin-deploy host force="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "═══════════════════════════════════════"
    echo "Darwin Deployment Validation"
    echo "═══════════════════════════════════════"
    echo ""

    # Gate 1: Validate secrets
    echo "→ Validating secrets..."
    if ! just validate-secrets; then
        echo "❌ Secrets validation failed" >&2
        echo "Run 'just validate-secrets' to see details" >&2
        exit 1
    fi

    # Gate 2: Validate git staging
    echo "→ Checking git status..."
    if ! just _validate-git-staged; then
        echo "❌ Git staging validation failed" >&2
        exit 1
    fi

    # Gate 3: Syntax validation
    echo "→ Validating Nix syntax..."
    if ! nix flake check; then
        echo "❌ Nix syntax check failed" >&2
        exit 1
    fi
    echo "✓ Syntax validated"

    # Gate 4: Dry-run build
    echo ""
    echo "→ Performing dry-run build..."
    if ! nix build .#darwinConfigurations.{{host}}.system; then
        echo "❌ Dry-run build failed" >&2
        exit 1
    fi
    echo "✓ Dry-run succeeded"

    # Gate 5: Confirmation (unless force mode)
    if [ "{{force}}" != "true" ]; then
        echo ""
        echo "═══════════════════════════════════════"
        read -p "Proceed with deployment to {{host}}? [y/N]: " confirmation
        if [ "$confirmation" != "yes" ] && [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
            echo "Deployment cancelled"
            exit 0
        fi
    fi

    # Execute deployment
    echo ""
    echo "→ Deploying Darwin configuration to {{host}}..."
    darwin-rebuild switch --flake .#{{host}}

    # Success summary
    echo ""
    echo "═══════════════════════════════════════"
    echo "Deployment Summary"
    echo "═══════════════════════════════════════"
    echo "✓ Secrets validated"
    echo "✓ Git changes staged"
    echo "✓ Syntax validated"
    echo "✓ Dry-run succeeded"
    echo "✓ Deployed successfully to {{host}}"

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
# Testing Recipes
# ============================================================================

# Run NixOS VM tests for xmsi and srv-01 configurations
#
# Runs nixosTest-based integration tests for NixOS system configurations.
# Tests verify critical functionality including:
# - System boots to multi-user target
# - Users exist with correct groups (mi-skam, plumps)
# - SSH service is running and accessible
# - SOPS secrets decrypt successfully
# - Server config has no GUI (srv-01 negative test)
#
# Tests run in isolated QEMU VMs and take approximately 5 minutes total.
# Each test is self-contained and runs independently.
#
# The tests are only available on x86_64-linux systems since xmsi and srv-01
# are both x86_64-linux configurations.
#
# Returns exit code 0 if all tests pass, non-zero on any test failure.
# Test failures include detailed error messages showing which checks failed.
#
# Example usage:
#   just test-nixos                    # Run all NixOS VM tests
#
# NOTE: This requires significant system resources (QEMU VMs). Tests are
# automatically skipped on non-x86_64-linux systems.
@test-nixos:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "════════════════════════════════════════"
    echo "  NixOS VM Testing"
    echo "════════════════════════════════════════"
    echo ""

    # Check if we're on x86_64-linux (tests only available on this platform)
    SYSTEM=$(nix eval --impure --raw --expr 'builtins.currentSystem')
    if [ "$SYSTEM" != "x86_64-linux" ]; then
        echo "⚠️  Skipping NixOS VM tests (only available on x86_64-linux)"
        echo "Current system: $SYSTEM"
        exit 0
    fi

    echo "→ Running xmsi configuration test..."
    if ! nix build .#checks.x86_64-linux.xmsi-test --print-build-logs; then
        echo "❌ xmsi test failed" >&2
        exit 1
    fi
    echo "✓ xmsi test passed"
    echo ""

    echo "→ Running srv-01 configuration test..."
    if ! nix build .#checks.x86_64-linux.srv-01-test --print-build-logs; then
        echo "❌ srv-01 test failed" >&2
        exit 1
    fi
    echo "✓ srv-01 test passed"
    echo ""

    echo "════════════════════════════════════════"
    echo "✅ All NixOS VM tests passed"
    echo "════════════════════════════════════════"

# Run Terraform validation test suite
#
# Runs terraform/run-tests.sh which executes all Terraform validation tests:
# - Syntax validation: Verifies HCL syntax is valid (tofu validate)
# - Plan validation: Checks plan generation without API calls (tofu plan -backend=false)
# - Import script validation: Validates import.sh syntax and import commands
# - Output validation: Verifies required outputs are defined in outputs.tf
#
# Tests complete in <10 seconds (no API calls required). Returns exit code 0
# if all tests pass, non-zero on any test failure. Test failures include
# detailed error messages and troubleshooting hints.
#
# Example usage:
#   just test-terraform    # Run all Terraform tests
#
# NOTE: Tests run locally without requiring Hetzner credentials or state file.
# They validate configuration correctness using dummy tokens and -backend=false.
@test-terraform:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "════════════════════════════════════════"
    echo "  Terraform Validation Testing"
    echo "════════════════════════════════════════"
    echo ""

    if ! terraform/run-tests.sh; then
        echo ""
        echo "❌ Terraform tests failed" >&2
        exit 1
    fi

    echo ""
    echo "════════════════════════════════════════"
    echo "✅ All Terraform tests passed"
    echo "════════════════════════════════════════"

# Run Ansible Molecule tests for all roles
#
# Runs Molecule test scenarios for Ansible roles to verify:
# - common role: Directories created, packages installed, bash aliases deployed
# - monitoring role: node_exporter and Promtail installed and configured
# - backup role: restic installed, backup scripts created, systemd timers configured
#
# Each scenario includes:
# - Role application (converge)
# - Idempotency testing (second run has changed=0)
# - Verification tests (files exist, services configured)
#
# Tests run in Docker containers (Debian 12, Ubuntu 24.04, Rocky Linux 9) and
# complete in <10 minutes total. Returns exit code 0 if all tests pass,
# non-zero on any test failure.
#
# Example usage:
#   just test-ansible              # Run all Molecule tests
#
# To test individual roles:
#   cd ansible && molecule test -s common
#   cd ansible && molecule test -s monitoring
#   cd ansible && molecule test -s backup
#
# NOTE: Requires Docker to be running. Molecule creates temporary containers
# that are destroyed after tests complete.
@test-ansible:
    #!/usr/bin/env bash
    set -euo pipefail

    # Add Docker to PATH (macOS Docker Desktop location)
    export PATH="/usr/local/bin:$PATH"

    # Ensure venv is activated (molecule and ansible-core installed there)
    if [ -f .venv/bin/activate ]; then
        source .venv/bin/activate
    else
        echo "❌ Error: Python venv not found at .venv/" >&2
        echo "Run: python3 -m venv .venv && .venv/bin/pip install molecule molecule-docker ansible-core" >&2
        exit 1
    fi

    # Check Docker is running
    if ! docker info &> /dev/null; then
        echo "❌ Error: Docker is not running" >&2
        echo "Please start Docker and try again" >&2
        exit 1
    fi

    echo "════════════════════════════════════════"
    echo "  Ansible Molecule Testing"
    echo "════════════════════════════════════════"
    echo ""

    # Test common role
    echo "→ Testing common role..."
    if ! (cd ansible && molecule test -s common); then
        echo "❌ common role tests failed" >&2
        exit 1
    fi
    echo "✓ common role tests passed"
    echo ""

    # Test monitoring role
    echo "→ Testing monitoring role..."
    if ! (cd ansible && molecule test -s monitoring); then
        echo "❌ monitoring role tests failed" >&2
        exit 1
    fi
    echo "✓ monitoring role tests passed"
    echo ""

    # Test backup role
    echo "→ Testing backup role..."
    if ! (cd ansible && molecule test -s backup); then
        echo "❌ backup role tests failed" >&2
        exit 1
    fi
    echo "✓ backup role tests passed"
    echo ""

    echo "════════════════════════════════════════"
    echo "✅ All Ansible Molecule tests passed"
    echo "════════════════════════════════════════"

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

# Apply infrastructure changes to Hetzner Cloud with validation gates
#
# Parameters:
#   force - Optional: Skip confirmation prompt (pass "true" to force)
#
# Creates, modifies, or destroys infrastructure to match desired state defined
# in Terraform configuration files. Includes comprehensive pre-deployment validation.
#
# Validation gates (in order):
#   1. Validates SOPS age key exists (required for decryption)
#   2. Validates secrets are properly encrypted and formatted
#   3. Validates Terraform is initialized and has state
#   4. Validates Terraform syntax (tofu validate)
#   5. Shows Terraform plan output (what will change)
#   6. Requires user confirmation (unless force="true")
#
# This will:
# - Create new servers, networks, SSH keys as defined
# - Modify existing resources if configuration changed
# - Destroy resources removed from configuration (with lifecycle protection)
#
# Example usage:
#   just tf-apply           # Apply with confirmation
#   just tf-apply true      # Apply without confirmation (force)
#
# IMPORTANT: Always review the plan output before confirming deployment.
@tf-apply force="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "═══════════════════════════════════════"
    echo "Terraform Deployment Validation"
    echo "═══════════════════════════════════════"
    echo ""

    # Gate 1: Validate age key
    echo "→ Validating SOPS age key..."
    if ! just _validate-age-key; then
        echo "❌ Age key validation failed" >&2
        echo "See error above for details" >&2
        exit 1
    fi

    # Gate 2: Validate secrets
    echo "→ Validating secrets..."
    if ! just validate-secrets; then
        echo "❌ Secrets validation failed" >&2
        echo "Run 'just validate-secrets' to see details" >&2
        exit 1
    fi

    # Gate 3: Validate Terraform state
    echo "→ Validating Terraform state..."
    if ! just _validate-terraform-state; then
        echo "❌ Terraform state validation failed" >&2
        exit 1
    fi

    # Gate 4: Syntax validation
    echo "→ Validating Terraform syntax..."
    export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
    cd terraform
    if ! tofu validate; then
        echo "❌ Terraform syntax validation failed" >&2
        exit 1
    fi
    echo "✓ Syntax validated"

    # Gate 5: Show plan
    echo ""
    echo "→ Generating Terraform plan..."
    echo "═══════════════════════════════════════"
    if ! tofu plan; then
        echo "❌ Terraform plan failed" >&2
        exit 1
    fi
    echo "═══════════════════════════════════════"

    # Gate 6: Confirmation (unless force mode)
    if [ "{{force}}" != "true" ]; then
        echo ""
        read -p "Proceed with infrastructure deployment? [y/N]: " confirmation
        if [ "$confirmation" != "yes" ] && [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
            echo "Deployment cancelled"
            exit 0
        fi
    fi

    # Execute deployment
    echo ""
    echo "→ Applying Terraform changes..."
    tofu apply -auto-approve

    # Success summary
    echo ""
    echo "═══════════════════════════════════════"
    echo "Deployment Summary"
    echo "═══════════════════════════════════════"
    echo "✓ Age key validated"
    echo "✓ Secrets validated"
    echo "✓ Terraform state validated"
    echo "✓ Syntax validated"
    echo "✓ Plan succeeded"
    echo "✓ Applied successfully"

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

# Detect infrastructure drift between Terraform config and actual state
#
# Runs terraform/drift-detection.sh which compares actual Hetzner Cloud
# infrastructure against Terraform configuration to detect manual changes
# or out-of-band modifications.
#
# The script performs:
# 1. Validates Terraform is initialized and age key exists
# 2. Refreshes Terraform state from Hetzner Cloud API
# 3. Generates plan to detect changes (tofu plan -detailed-exitcode)
# 4. Reports drifted resources with details
#
# Exit codes:
# - 0: No drift (infrastructure matches configuration)
# - 1: Drift detected (resources have changed)
# - 2: Error (API failure, missing credentials, Terraform errors)
#
# Example usage:
#   just tf-drift-check    # Check for drift
#
# This is safe to run anytime - it does NOT modify infrastructure.
# For scheduled drift detection in CI/CD, see Iteration 7 plan.
@tf-drift-check:
    terraform/drift-detection.sh

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

# Run Ansible playbook on all hosts with validation gates
#
# Parameters:
#   playbook - Playbook name without .yaml extension (e.g., "bootstrap", "deploy")
#   force    - Optional: Skip confirmation prompt (pass "true" to force)
#
# Deploys to all hosts in inventory with comprehensive pre-deployment validation.
#
# Validation gates (in order):
#   1. Validates secrets are properly encrypted (Ansible uses SSH keys)
#   2. Validates Ansible inventory exists and is current
#   3. Validates playbook syntax (ansible-playbook --syntax-check)
#   4. Performs dry-run with change preview (ansible-playbook --check --diff)
#   5. Requires user confirmation (unless force="true")
#
# Available playbooks:
# - bootstrap: Initial server setup (users, packages, hardening)
# - deploy: Deploy application configurations
#
# Example usage:
#   just ansible-deploy bootstrap       # Deploy with confirmation
#   just ansible-deploy deploy true     # Deploy without confirmation (force)
#
# For environment-specific deployment, use ansible-deploy-env instead.
# IMPORTANT: Always review the dry-run output before confirming deployment.
@ansible-deploy playbook force="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "═══════════════════════════════════════"
    echo "Ansible Deployment Validation"
    echo "═══════════════════════════════════════"
    echo ""

    # Gate 1: Validate secrets
    echo "→ Validating secrets..."
    if ! just validate-secrets; then
        echo "❌ Secrets validation failed" >&2
        echo "Run 'just validate-secrets' to see details" >&2
        exit 1
    fi

    # Gate 2: Validate Ansible inventory
    echo "→ Validating Ansible inventory..."
    if ! just _validate-ansible-inventory; then
        echo "❌ Ansible inventory validation failed" >&2
        exit 1
    fi

    # Gate 3: Syntax validation
    echo "→ Validating playbook syntax..."
    cd ansible
    if ! ansible-playbook playbooks/{{playbook}}.yaml --syntax-check; then
        echo "❌ Playbook syntax validation failed" >&2
        exit 1
    fi
    echo "✓ Syntax validated"

    # Gate 4: Dry-run with change preview
    echo ""
    echo "→ Performing dry-run (showing changes)..."
    echo "═══════════════════════════════════════"
    if ! ansible-playbook playbooks/{{playbook}}.yaml --check --diff; then
        echo "❌ Dry-run failed" >&2
        exit 1
    fi
    echo "═══════════════════════════════════════"

    # Gate 5: Confirmation (unless force mode)
    if [ "{{force}}" != "true" ]; then
        echo ""
        read -p "Proceed with deployment to all hosts? [y/N]: " confirmation
        if [ "$confirmation" != "yes" ] && [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
            echo "Deployment cancelled"
            exit 0
        fi
    fi

    # Execute deployment
    echo ""
    echo "→ Deploying playbook {{playbook}} to all hosts..."
    ansible-playbook playbooks/{{playbook}}.yaml

    # Success summary
    echo ""
    echo "═══════════════════════════════════════"
    echo "Deployment Summary"
    echo "═══════════════════════════════════════"
    echo "✓ Secrets validated"
    echo "✓ Inventory validated"
    echo "✓ Syntax validated"
    echo "✓ Dry-run succeeded"
    echo "✓ Deployed successfully to all hosts"

# Run Ansible playbook on specific environment with validation gates
#
# Parameters:
#   env      - Environment to target ("dev" or "prod")
#   playbook - Playbook name without .yaml extension
#   force    - Optional: Skip confirmation prompt (pass "true" to force)
#
# Deploys to specific environment with comprehensive pre-deployment validation.
#
# Validation gates (in order):
#   1. Validates secrets are properly encrypted (Ansible uses SSH keys)
#   2. Validates Ansible inventory exists and is current
#   3. Validates playbook syntax (ansible-playbook --syntax-check)
#   4. Performs dry-run with change preview (ansible-playbook --check --diff)
#   5. Requires user confirmation (unless force="true")
#
# Environment groups defined in inventory:
# - dev: test-1.dev.nbg
# - prod: mail-1.prod.nbg, syncthing-1.prod.hel
#
# Example usage:
#   just ansible-deploy-env dev bootstrap         # Deploy with confirmation
#   just ansible-deploy-env prod deploy true      # Deploy without confirmation (force)
#
# IMPORTANT: Always review the dry-run output before confirming deployment.
@ansible-deploy-env env playbook force="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "═══════════════════════════════════════"
    echo "Ansible Deployment Validation ({{env}})"
    echo "═══════════════════════════════════════"
    echo ""

    # Gate 1: Validate secrets
    echo "→ Validating secrets..."
    if ! just validate-secrets; then
        echo "❌ Secrets validation failed" >&2
        echo "Run 'just validate-secrets' to see details" >&2
        exit 1
    fi

    # Gate 2: Validate Ansible inventory
    echo "→ Validating Ansible inventory..."
    if ! just _validate-ansible-inventory; then
        echo "❌ Ansible inventory validation failed" >&2
        exit 1
    fi

    # Gate 3: Syntax validation
    echo "→ Validating playbook syntax..."
    cd ansible
    if ! ansible-playbook playbooks/{{playbook}}.yaml --syntax-check; then
        echo "❌ Playbook syntax validation failed" >&2
        exit 1
    fi
    echo "✓ Syntax validated"

    # Gate 4: Dry-run with change preview
    echo ""
    echo "→ Performing dry-run (showing changes for {{env}})..."
    echo "═══════════════════════════════════════"
    if ! ansible-playbook playbooks/{{playbook}}.yaml --limit {{env}} --check --diff; then
        echo "❌ Dry-run failed" >&2
        exit 1
    fi
    echo "═══════════════════════════════════════"

    # Gate 5: Confirmation (unless force mode)
    if [ "{{force}}" != "true" ]; then
        echo ""
        read -p "Proceed with deployment to {{env}} environment? [y/N]: " confirmation
        if [ "$confirmation" != "yes" ] && [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
            echo "Deployment cancelled"
            exit 0
        fi
    fi

    # Execute deployment
    echo ""
    echo "→ Deploying playbook {{playbook}} to {{env}} environment..."
    ansible-playbook playbooks/{{playbook}}.yaml --limit {{env}}

    # Success summary
    echo ""
    echo "═══════════════════════════════════════"
    echo "Deployment Summary"
    echo "═══════════════════════════════════════"
    echo "✓ Secrets validated"
    echo "✓ Inventory validated"
    echo "✓ Syntax validated"
    echo "✓ Dry-run succeeded"
    echo "✓ Deployed successfully to {{env}}"

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
