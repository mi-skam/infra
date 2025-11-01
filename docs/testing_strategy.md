# Infrastructure Testing Strategy

**Version:** 1.0
**Created:** 2025-10-30
**Purpose:** Define comprehensive testing approaches for Nix configurations, Terraform modules, and Ansible roles

---

## Table of Contents

1. [Strategy Overview](#1-strategy-overview)
2. [Testing Pyramid for Infrastructure](#2-testing-pyramid-for-infrastructure)
3. [NixOS Testing Approach](#3-nixos-testing-approach)
4. [Terraform Testing Approach](#4-terraform-testing-approach)
5. [Ansible Testing Approach](#5-ansible-testing-approach)
6. [Test Environments](#6-test-environments)
7. [Test Data Management](#7-test-data-management)
8. [Coverage Goals and Prioritization](#8-coverage-goals-and-prioritization)
9. [Workflow Integration](#9-workflow-integration)
10. [Continuous Testing Integration](#10-continuous-testing-integration)
11. [Appendix: Quick Reference](#11-appendix-quick-reference)

---

## 1. Strategy Overview

### 1.1 Testing Philosophy

Infrastructure testing validates that configurations, modules, and automation scripts work correctly before deployment to production. Unlike application testing, infrastructure testing focuses on:

- **Declarative correctness**: Configurations evaluate without syntax errors
- **Idempotency**: Running automation multiple times produces the same result
- **Integration**: Components work together in realistic environments
- **Deployment safety**: Changes can be safely applied to production

### 1.2 Core Principles

**1. Fail Early, Fail Fast**
Catch errors at the earliest possible stage:
- Syntax validation before evaluation
- Evaluation before build
- Build before deployment
- Check-mode before actual deployment

**2. Test in Isolation, Validate in Integration**
Individual modules must work standalone, but complete systems must be tested together.

**3. Idempotency is Non-Negotiable**
Every test must verify that running twice produces identical results (`changed=0` on second run).

**4. Use Production-Like Environments**
Test environments should mirror production as closely as possible (same OS, same package versions).

**5. Automate Everything**
Manual testing is error-prone and doesn't scale. Every test should be automatable via CI/CD.

### 1.3 Success Metrics

- **80% test coverage** for critical paths (P0 priorities)
- **50% test coverage** for secondary paths (P1 priorities)
- **Zero breaking changes** reach production
- **< 5 minute** test feedback loop for developers
- **100% idempotency** verification for all Ansible roles

---

## 2. Testing Pyramid for Infrastructure

### 2.1 Infrastructure Testing Pyramid

```
                    ┌─────────────────┐
                    │   Deployment    │  ← Validation Tests
                    │   Validation    │     (End-to-end)
                    └─────────────────┘
                           ▲
                    ┌─────────────────┐
                    │   Integration   │  ← Integration Tests
                    │      Tests      │     (System-level)
                    └─────────────────┘
                           ▲
                    ┌─────────────────┐
                    │   Unit Tests    │  ← Unit Tests
                    │   (Modules)     │     (Component-level)
                    └─────────────────┘
```

### 2.2 Test Types Explained

#### Unit Tests (Fast, Many)

**Purpose:** Verify individual modules/configurations work in isolation
**Execution Time:** Seconds
**Frequency:** Every code change
**Examples:**
- Nix module syntax validation (`nix flake check`)
- Terraform syntax validation (`tofu validate`)
- Ansible playbook syntax validation (`ansible-playbook --syntax-check`)

**Characteristics:**
- No external dependencies
- No network access required
- Run in parallel
- Deterministic results

#### Integration Tests (Medium, Moderate)

**Purpose:** Verify components work together correctly
**Execution Time:** Minutes
**Frequency:** On pull requests
**Examples:**
- NixOS VM tests (full system boot in isolated VM)
- Terraform plan validation (checks resource interdependencies)
- Ansible check-mode against test environment

**Characteristics:**
- May require test data (SOPS test fixtures)
- May require limited network access
- Run sequentially or with limited parallelism
- Mostly deterministic

#### Validation Tests (Slow, Few)

**Purpose:** Verify full deployment workflows in production-like environment
**Execution Time:** 10-30 minutes
**Frequency:** Before merge, scheduled nightly
**Examples:**
- Complete NixOS system deployment to test-1.dev.nbg
- Terraform apply with state validation
- Ansible playbook deployment with idempotency check (two runs)

**Characteristics:**
- Requires real infrastructure
- Network-dependent
- State-dependent
- May have side effects

### 2.3 Test Selection Guidelines

**When to write unit tests:**
- New Nix modules added
- New Terraform resources defined
- New Ansible tasks created
- Syntax/structure changes

**When to write integration tests:**
- Multiple modules interact
- Cross-module dependencies added
- System-level configuration changes
- Platform-specific logic (Darwin vs Linux)

**When to run validation tests:**
- Before production deployment
- After infrastructure changes
- Periodically (nightly) to catch drift
- When troubleshooting production issues

---

## 3. NixOS Testing Approach

### 3.1 Test Levels

#### Level 1: Syntax Validation (Unit)

**Tool:** `nix flake check`
**Purpose:** Verify all flake outputs evaluate without errors
**Execution Time:** ~10 seconds
**When to Run:** Every commit, pre-push hook

**Command:**
```bash
nix flake check
```

**What it validates:**
- All NixOS configurations evaluate
- All Darwin configurations evaluate
- All Home Manager configurations evaluate
- All module imports resolve
- No syntax errors in Nix expressions
- Type correctness

**Expected Output:**
```
evaluating flake...
checking flake output 'nixosConfigurations'...
checking NixOS configuration 'nixosConfigurations.xmsi'...
checking NixOS configuration 'nixosConfigurations.srv-01'...
✓ All checks passed
```

**Failure Handling:**
- Fix immediately - syntax errors block all downstream tests
- Review error message for exact location
- Stage fixes with `git add` (flakes require git-tracked files)

#### Level 2: Build Validation (Integration)

**Tool:** `nix build` with `--dry-run`
**Purpose:** Verify configurations build without downloading/building
**Execution Time:** ~30 seconds per configuration
**When to Run:** On pull requests, after module changes

**Commands:**
```bash
# NixOS configurations
nix build '.#nixosConfigurations.xmsi.config.system.build.toplevel' --dry-run
nix build '.#nixosConfigurations.srv-01.config.system.build.toplevel' --dry-run

# Darwin configurations
nix build '.#darwinConfigurations.xbook.system' --dry-run

# Home Manager configurations
nix build '.#homeConfigurations."mi-skam@xmsi".activationPackage' --dry-run
nix build '.#homeConfigurations."plumps@xbook".activationPackage' --dry-run
nix build '.#homeConfigurations."plumps@srv-01".activationPackage' --dry-run
```

**What it validates:**
- All dependencies can be resolved
- Closure is consistent
- No broken references
- Platform-specific configurations work (Darwin vs Linux)
- Secrets files are accessible (test fixtures)

**Expected Output:**
```
these 287 derivations will be built:
  /nix/store/...
these 2102 paths will be fetched (3850.45 MiB download):
  /nix/store/...
```

**Failure Handling:**
- **Missing dependency**: Add to flake inputs
- **Broken package**: Pin to working version or use alternative
- **Missing secrets**: Ensure test fixtures present and git-tracked
- **Import error**: Check relative paths in module imports

#### Level 3: VM Testing (Integration)

**Tool:** `nixosTest` framework
**Purpose:** Boot complete system in isolated VM, verify functionality
**Execution Time:** 2-5 minutes per test
**When to Run:** Before merge, on critical module changes

**Test File Location:** `tests/nixos/`

**Example Test Structure:**
```nix
# tests/nixos/xmsi-test.nix
{ pkgs, ... }:

pkgs.nixosTest {
  name = "xmsi-system-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../hosts/xmsi/configuration.nix
    ];
  };

  testScript = ''
    # Wait for system to boot
    machine.wait_for_unit("multi-user.target")

    # Verify SSH service is running
    machine.wait_for_unit("sshd.service")

    # Verify user exists
    machine.succeed("id mi-skam")

    # Verify secrets are decrypted
    machine.succeed("test -f /run/secrets/mi-skam")

    # Verify network is configured
    machine.succeed("ping -c 1 1.1.1.1")

    # Verify disk partitions are correct
    machine.succeed("lsblk | grep -q nvme0n1p1")
  '';
}
```

**Running VM Tests:**
```bash
# Run specific test
nix-build tests/nixos/xmsi-test.nix

# Run all nixos tests
nix-build tests/nixos/all-tests.nix
```

**What to Test in VM Tests:**

**Critical Path (Must Test):**
- System boots to multi-user target
- SSH daemon starts and listens on port 22
- Users exist with correct UIDs and groups
- Secrets decrypt successfully
- Network configuration is applied
- Essential services start (systemd units)

**Secondary Path (Should Test):**
- Desktop environment starts (for desktop configs)
- Package installations are correct
- File permissions are correct
- Firewall rules are applied
- Time zone is set correctly

**What NOT to Test:**
- Application functionality (that's app-level testing)
- Performance characteristics
- Long-running operations (backups, updates)

**Failure Handling:**
- **Boot failure**: Check systemd journal output in test logs
- **Service failure**: Verify service definition in modules
- **Secret failure**: Check SOPS configuration and key access
- **Test timeout**: Increase timeout or optimize boot time

### 3.2 Test Coverage for NixOS Configurations

#### xmsi (Desktop, Priority: P0)

**Test File:** `tests/nixos/xmsi-test.nix`

**Tests to Implement:**
```nix
testScript = ''
  # Boot test
  machine.wait_for_unit("multi-user.target")

  # User test
  machine.succeed("id mi-skam")
  machine.succeed("groups mi-skam | grep -q wheel")

  # Secrets test
  machine.succeed("test -f /run/secrets/mi-skam")

  # Desktop environment test
  machine.wait_for_unit("display-manager.service")
  machine.wait_for_unit("plasma-kwin_x11.service")

  # Network test
  machine.succeed("ping -c 1 1.1.1.1")

  # SSH test
  machine.wait_for_unit("sshd.service")
  machine.wait_for_open_port(22)
'';
```

**Why These Tests:**
- Boot test: Verifies system reaches usable state
- User test: Validates mkUser.nix consolidation works
- Secrets test: Confirms SOPS integration is functional
- Desktop test: Validates Plasma configuration
- Network test: Confirms basic connectivity
- SSH test: Essential for remote management

#### srv-01 (Server, Priority: P0)

**Test File:** `tests/nixos/srv-01-test.nix`

**Tests to Implement:**
```nix
testScript = ''
  # Boot test (faster on server - no GUI)
  machine.wait_for_unit("multi-user.target")

  # Users test
  machine.succeed("id mi-skam")
  machine.succeed("id plumps")

  # Secrets test
  machine.succeed("test -f /run/secrets/mi-skam")
  machine.succeed("test -f /run/secrets/plumps")

  # Server services test
  machine.wait_for_unit("sshd.service")

  # No GUI test
  machine.fail("systemctl is-active display-manager.service")

  # Network test
  machine.succeed("ping -c 1 1.1.1.1")
'';
```

**Why These Tests:**
- Multi-user boot: Server systems don't need graphical.target
- Multiple users: srv-01 has both users configured
- No GUI test: Negative test ensures desktop packages not installed
- Network test: Servers must have working network

### 3.3 Test Data Requirements

**SOPS Test Fixtures (Required):**
- `secrets/users.yaml` - Encrypted user passwords
- `secrets/ssh-keys.yaml` - SSH key placeholders
- `secrets/pgp-keys.yaml` - PGP key placeholders

**Test Fixture Content (Example):**
```yaml
# secrets/users.yaml (encrypted with SOPS)
mi-skam: "$6$rounds=65536$test-salt-placeholder$..." # Test password hash
plumps: "$6$rounds=65536$test-salt-placeholder$..."  # Test password hash
```

**Creating Test Fixtures:**
```bash
# Generate test password hash
mkpasswd -m sha-512 "test-password-placeholder"

# Edit secrets file
sops secrets/users.yaml

# Stage for git (required for flakes)
git add secrets/users.yaml
```

**Important:** Test fixtures use placeholder data only. Production secrets are never committed.

### 3.4 Home Manager Testing

**Special Considerations:**

Home Manager configurations can't use nixosTest (no VM support). Instead, use build validation:

```bash
# Syntax check (fast)
nix flake check

# Build check (comprehensive)
nix build '.#homeConfigurations."mi-skam@xmsi".activationPackage' --dry-run

# Full build (for critical tests)
nix build '.#homeConfigurations."mi-skam@xmsi".activationPackage'
```

**What to Verify:**
- Configuration evaluates without errors
- All packages resolve correctly
- Platform-specific packages selected (Darwin vs Linux)
- Helper functions work (mkNeovimConfig, mkStarshipConfig)
- User secrets decrypt

**Known Issues to Handle:**
- **Broken upstream packages** (e.g., ghostty): Document as expected failures, consider alternatives
- **Platform-specific failures**: Test on both Darwin and Linux systems

---

## 4. Terraform Testing Approach

### 4.1 Test Levels

#### Level 1: Syntax Validation (Unit)

**Tool:** `tofu validate`
**Purpose:** Verify Terraform configuration is syntactically correct
**Execution Time:** ~2 seconds
**When to Run:** Every commit, pre-push hook

**Command:**
```bash
cd terraform/
tofu validate
```

**What it validates:**
- HCL syntax is correct
- All required arguments are present
- Resource types are valid
- Variable types match usage
- Module sources are accessible

**Expected Output:**
```
Success! The configuration is valid.
```

**Failure Handling:**
- **Syntax error**: Fix HCL syntax, check for typos
- **Missing argument**: Add required argument to resource
- **Invalid resource type**: Check provider version and documentation
- **Module source error**: Verify module path or URL

#### Level 2: Plan Validation (Integration)

**Tool:** `tofu plan`
**Purpose:** Verify Terraform can generate execution plan without errors
**Execution Time:** ~5-10 seconds
**When to Run:** On pull requests, before apply

**Command:**
```bash
cd terraform/
export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep hcloud_token | cut -d: -f2 | xargs)"
tofu plan -out=tfplan
```

**What it validates:**
- Provider authentication works
- All resources can be planned
- Dependencies are correctly defined
- Expected resource count matches
- No circular dependencies

**Expected Output:**
```
Terraform will perform the following actions:

  # hcloud_server.mail-1 will be created
  + resource "hcloud_server" "mail-1" {
      + id = (known after apply)
      ...
    }

Plan: 6 to add, 0 to change, 0 to destroy.
```

**Key Metrics to Verify:**
- **No unexpected changes**: If plan shows changes when none expected, investigate drift
- **Resource count matches**: Expected number of adds/changes/destroys
- **Dependency order**: Resources created in correct order

**Failure Handling:**
- **Authentication error**: Check SOPS secrets, verify API token
- **Resource not found**: May indicate deleted resource - check state
- **Dependency cycle**: Restructure resource references
- **Provider error**: Check provider version and API compatibility

#### Level 3: State Import Validation (Integration)

**Tool:** `terraform/import.sh` script
**Purpose:** Verify existing infrastructure can be imported into state
**Execution Time:** ~30 seconds
**When to Run:** After infrastructure changes, periodically

**Command:**
```bash
cd terraform/
./import.sh
```

**What it validates:**
- All existing Hetzner resources are in Terraform state
- Resource IDs match actual infrastructure
- Import commands work correctly
- No orphaned resources

**Expected Output:**
```
Importing hcloud_server.mail-1...
Import successful!
Importing hcloud_network.homelab...
Import successful!
...
```

**Verification After Import:**
```bash
# Check state consistency
tofu plan

# Expected output:
# No changes. Your infrastructure matches the configuration.
```

**Failure Handling:**
- **Resource already in state**: Run `tofu state rm` first if re-importing
- **Resource not found**: Check resource still exists in Hetzner Cloud
- **ID mismatch**: Verify correct resource ID from `hcloud` CLI

#### Level 4: Drift Detection (Validation)

**Tool:** `terraform/drift-detection.sh`
**Purpose:** Detect configuration drift between Terraform state and actual infrastructure
**Execution Time:** ~10 seconds
**When to Run:** Scheduled (daily), before deployments

**Command:**
```bash
cd terraform/
./drift-detection.sh
```

**What it validates:**
- Infrastructure matches Terraform configuration
- No manual changes outside Terraform
- State is synchronized with reality

**Exit Codes:**
- `0`: No drift detected
- `1`: Drift detected (changes needed)
- `2`: Error (authentication, network, etc.)

**Expected Output (No Drift):**
```
No changes. Your infrastructure matches the configuration.
```

**Expected Output (Drift Detected):**
```
Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform:
  # hcloud_server.mail-1 has been modified
  ~ resource "hcloud_server" "mail-1" {
      ~ labels = {
          - "env" = "prod" -> null
        }
    }
```

**Handling Drift:**
1. **Intentional changes**: Update Terraform config to match
2. **Unintentional changes**: Run `tofu apply` to revert
3. **Emergency changes**: Document in runbook, update config later

### 4.2 Test Scenarios

#### Scenario 1: New Resource Addition

**Test Procedure:**
```bash
# 1. Add new resource to .tf file
# 2. Validate syntax
tofu validate

# 3. Check plan
tofu plan

# Verify:
# - Plan shows exactly 1 resource to add
# - Dependencies are correct
# - No unexpected changes to existing resources

# 4. Review plan output
# Plan: 1 to add, 0 to change, 0 to destroy
```

#### Scenario 2: Resource Modification

**Test Procedure:**
```bash
# 1. Modify resource configuration
# 2. Validate syntax
tofu validate

# 3. Check plan
tofu plan

# Verify:
# - Plan shows in-place update or replace (as expected)
# - Dependent resources handled correctly
# - Replacement is acceptable (check for data loss risk)

# 4. For destructive changes, test in dev first
tofu apply --target=hcloud_server.test-1
```

#### Scenario 3: State Consistency Check

**Test Procedure:**
```bash
# 1. Refresh state from actual infrastructure
tofu refresh

# 2. Check for drift
tofu plan

# Verify:
# - No changes needed (state matches reality)
# - If changes detected, investigate cause

# 3. If drift found, decide on remediation
# Option A: Update Terraform config
# Option B: Apply Terraform config to revert drift
```

### 4.3 Test Coverage

**Critical Resources (P0) - Must Validate:**
- `hcloud_server.*` - All VPS instances
- `hcloud_network.homelab` - Private network
- `hcloud_network_subnet.homelab` - Subnet configuration
- `hcloud_ssh_key.homelab-hetzner` - SSH key for access

**Secondary Resources (P1) - Should Validate:**
- `hcloud_firewall.*` - Firewall rules (if defined)
- `hcloud_volume.*` - Additional storage (if defined)
- `hcloud_load_balancer.*` - Load balancers (if defined)

**Test Matrix:**

| Resource Type | Syntax | Plan | Import | Drift | Priority |
|--------------|--------|------|--------|-------|----------|
| hcloud_server | ✅ | ✅ | ✅ | ✅ | P0 |
| hcloud_network | ✅ | ✅ | ✅ | ✅ | P0 |
| hcloud_network_subnet | ✅ | ✅ | ✅ | ✅ | P0 |
| hcloud_ssh_key | ✅ | ✅ | ✅ | ✅ | P0 |
| hcloud_firewall | ✅ | ✅ | ⚠️ | ✅ | P1 |

### 4.4 Automation via Justfile

**Recommended Justfile Recipes:**

```just
# Validate Terraform syntax
tf-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    cd terraform
    tofu validate

# Generate Terraform plan
tf-plan:
    #!/usr/bin/env bash
    set -euo pipefail
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep hcloud_token | cut -d: -f2 | xargs)"
    tofu plan -out=tfplan

# Check for infrastructure drift
tf-drift:
    #!/usr/bin/env bash
    set -euo pipefail
    cd terraform
    ./drift-detection.sh

# Validate state import
tf-import-test:
    #!/usr/bin/env bash
    set -euo pipefail
    cd terraform
    # Backup current state
    cp terraform.tfstate terraform.tfstate.backup
    # Run import script
    ./import.sh
    # Verify no changes needed
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep hcloud_token | cut -d: -f2 | xargs)"
    tofu plan
    # Restore backup
    mv terraform.tfstate.backup terraform.tfstate
```

**Usage:**
```bash
# Run all Terraform tests
just tf-validate && just tf-plan && just tf-drift
```

---

## 5. Ansible Testing Approach

### 5.1 Test Levels

#### Level 1: Syntax Validation (Unit)

**Tool:** `ansible-playbook --syntax-check`
**Purpose:** Verify playbook syntax is correct
**Execution Time:** ~1 second
**When to Run:** Every commit, pre-push hook

**Commands:**
```bash
# Validate playbooks
ansible-playbook playbooks/bootstrap.yaml --syntax-check
ansible-playbook playbooks/deploy.yaml --syntax-check
ansible-playbook playbooks/setup-storagebox.yaml --syntax-check
ansible-playbook playbooks/mailcow-backup.yaml --syntax-check
```

**What it validates:**
- YAML syntax is correct
- Module names are valid
- Required parameters are present
- Task structure is correct

**Expected Output:**
```
playbook: playbooks/deploy.yaml
```

**Failure Handling:**
- **YAML syntax error**: Check indentation, quotes, special characters
- **Unknown module**: Check module name, ensure collection installed
- **Missing parameter**: Add required parameter to task

#### Level 2: Role Validation (Unit)

**Tool:** `ansible-lint`
**Purpose:** Enforce Ansible best practices and style guidelines
**Execution Time:** ~5 seconds
**When to Run:** On pull requests

**Commands:**
```bash
# Lint specific role
ansible-lint ansible/roles/common/

# Lint all roles
ansible-lint ansible/roles/

# Lint playbooks
ansible-lint ansible/playbooks/
```

**What it validates:**
- Best practices followed
- Task naming conventions
- Proper use of modules
- Handler usage
- Variable naming
- Deprecated syntax

**Expected Output:**
```
Passed: 0 failure(s), 0 warning(s) on 24 files.
```

**Common Issues:**
```
[201] Trailing whitespace
[204] Lines should be no longer than 160 chars
[305] Use shell only when shell functionality is required
[503] Tasks that run when changed should likely be handlers
```

**Failure Handling:**
- **Cosmetic issues (201, 204)**: Fix formatting
- **Best practice violations (305, 503)**: Refactor to use recommended approach
- **Deprecated syntax**: Update to current Ansible syntax

#### Level 3: Check Mode (Integration)

**Tool:** `ansible-playbook --check`
**Purpose:** Simulate playbook execution without making changes
**Execution Time:** ~30 seconds
**When to Run:** Before every deployment, on pull requests

**Commands:**
```bash
# Check against single host
ansible-playbook playbooks/deploy.yaml --check --limit test-1.dev.nbg

# Check against environment
ansible-playbook playbooks/deploy.yaml --check --limit prod

# Verbose output for debugging
ansible-playbook playbooks/deploy.yaml --check --diff -vv --limit test-1.dev.nbg
```

**What it validates:**
- Playbook can connect to hosts
- Tasks execute without errors
- Expected changes are reported
- No syntax errors in templates
- Variables are correctly defined

**Expected Output:**
```
PLAY [Deploy configurations] ************************************

TASK [Gathering Facts] ******************************************
ok: [test-1.dev.nbg]

TASK [common : Create common directories] ***********************
changed: [test-1.dev.nbg] => (item=/opt/scripts)
changed: [test-1.dev.nbg] => (item=/var/log/homelab)

PLAY RECAP ******************************************************
test-1.dev.nbg : ok=5 changed=3 unreachable=0 failed=0
```

**Key Metrics:**
- **ok**: Tasks that found no changes needed
- **changed**: Tasks that would make changes
- **failed**: Tasks that failed (should be 0)

**Failure Handling:**
- **Connection failure**: Check SSH keys, network connectivity
- **Task failure**: Review task parameters, check target system state
- **Undefined variable**: Add missing variable to inventory or defaults

#### Level 4: Idempotency Testing (Integration)

**Tool:** Actual playbook run (twice)
**Purpose:** Verify running playbook twice produces no changes
**Execution Time:** 2-5 minutes (two full runs)
**When to Run:** After role changes, before production deployment

**Test Procedure:**
```bash
# First run - apply changes
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg

# Capture first run summary
# Expected: Some "changed" tasks

# Second run - verify idempotency
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg

# Capture second run summary
# Expected: changed=0 (all tasks show "ok", none show "changed")
```

**Expected Output (First Run):**
```
PLAY RECAP ******************************************************
test-1.dev.nbg : ok=12 changed=5 unreachable=0 failed=0
```

**Expected Output (Second Run - IDEMPOTENT):**
```
PLAY RECAP ******************************************************
test-1.dev.nbg : ok=12 changed=0 unreachable=0 failed=0
```

**Idempotency Verification:**
- **changed=0**: Perfect idempotency ✅
- **changed>0**: Investigate non-idempotent tasks ⚠️

**Common Non-Idempotent Patterns:**
```yaml
# BAD: shell module without changed_when
- name: Run script
  shell: /path/to/script.sh

# GOOD: shell module with changed_when
- name: Run script
  shell: /path/to/script.sh
  register: script_result
  changed_when: script_result.rc != 0
```

**Failure Handling:**
- **Always reports changed**: Add `changed_when` condition
- **Timestamp/random data**: Use templates without date/random values
- **Package updates**: Control with variables (common_upgrade_packages: false)

#### Level 5: Molecule Testing (Integration)

**Tool:** Molecule with Docker driver
**Purpose:** Test roles in isolated containers
**Execution Time:** 1-3 minutes per role
**When to Run:** After role modifications, on pull requests

**Setup for Role:**
```bash
cd ansible/roles/common
molecule init scenario
```

**Molecule Configuration (`molecule/default/molecule.yml`):**
```yaml
---
driver:
  name: docker
platforms:
  - name: debian-12
    image: debian:12
    pre_build_image: true
  - name: ubuntu-2404
    image: ubuntu:24.04
    pre_build_image: true
  - name: rockylinux-9
    image: rockylinux:9
    pre_build_image: true
provisioner:
  name: ansible
  playbooks:
    converge: converge.yml
  inventory:
    group_vars:
      all:
        common_packages: [vim, htop, curl]
verifier:
  name: ansible
```

**Converge Playbook (`molecule/default/converge.yml`):**
```yaml
---
- name: Converge
  hosts: all
  become: true
  roles:
    - role: common
```

**Verify Playbook (`molecule/default/verify.yml`):**
```yaml
---
- name: Verify
  hosts: all
  tasks:
    - name: Check directories exist
      stat:
        path: "{{ item }}"
      register: dir_check
      failed_when: not dir_check.stat.exists
      loop:
        - /opt/scripts
        - /var/log/homelab

    - name: Check packages installed
      command: which vim
      changed_when: false

    - name: Check bash aliases
      stat:
        path: /root/.bash_aliases
      register: aliases_check
      failed_when: not aliases_check.stat.exists
```

**Running Molecule Tests:**
```bash
# Test role on all platforms
cd ansible/roles/common
molecule test

# Test on specific platform
molecule test --platform-name debian-12

# Manual testing workflow
molecule create    # Create containers
molecule converge  # Run playbook (first time)
molecule converge  # Run again (idempotency check)
molecule verify    # Run verification tests
molecule destroy   # Clean up containers
```

**Expected Output:**
```
--> Test matrix
└── default
    ├── dependency
    ├── cleanup
    ├── destroy
    ├── syntax
    ├── create
    ├── prepare
    ├── converge
    ├── idempotence
    ├── side_effect
    ├── verify
    └── cleanup
    └── destroy

--> Scenario: 'default'
--> Action: 'test'
...
PLAY RECAP *****************************************************
debian-12: ok=5 changed=0 unreachable=0 failed=0
```

**What Molecule Tests:**
- Role works on all target platforms (Debian, Ubuntu, Rocky Linux)
- Role is idempotent (converge runs twice, second shows changed=0)
- Verification tests pass (files exist, services running)

**Failure Handling:**
- **Platform-specific failure**: Add conditional logic for that OS family
- **Idempotency failure**: Add `changed_when` to non-idempotent tasks
- **Verification failure**: Check actual state vs expected state

### 5.2 Test Coverage for Ansible Roles

#### Role: common (Priority: P0)

**Molecule Test Status:** To be implemented
**Test File:** `ansible/roles/common/molecule/default/`

**Tests to Implement:**
```yaml
# verify.yml
- name: Verify common role
  hosts: all
  tasks:
    # Directory test
    - name: Check /opt/scripts exists
      stat:
        path: /opt/scripts
      register: scripts_dir
      failed_when: not scripts_dir.stat.exists or scripts_dir.stat.mode != '0755'

    # Package test
    - name: Verify vim installed
      command: which vim
      changed_when: false

    # Bash aliases test
    - name: Check bash aliases file
      stat:
        path: /root/.bash_aliases
      register: aliases
      failed_when: not aliases.stat.exists

    # Aliases content test
    - name: Verify ll alias exists
      shell: grep -q "alias ll=" /root/.bash_aliases
      changed_when: false
```

**Why These Tests:**
- Directory creation is core functionality
- Package installation validates package module works
- Bash aliases verify template rendering
- Content check ensures aliases are usable

#### Role: monitoring (Priority: P1)

**Molecule Test Status:** To be implemented (role not yet implemented)
**Test File:** `ansible/roles/monitoring/molecule/default/`

**Tests to Implement (Once Role Built):**
```yaml
# verify.yml
- name: Verify monitoring role
  hosts: all
  tasks:
    # Service test
    - name: Check node_exporter service
      systemd:
        name: node_exporter
        state: started
      check_mode: yes
      register: service_check
      failed_when: service_check.changed

    # Port test
    - name: Verify node_exporter port listening
      wait_for:
        port: 9100
        timeout: 5

    # Metrics test
    - name: Check metrics endpoint
      uri:
        url: http://localhost:9100/metrics
        status_code: 200
```

#### Role: storagebox (Priority: P1)

**Molecule Test Status:** To be implemented
**Test File:** `ansible/roles/storagebox/molecule/default/`

**Special Considerations:**
- Cannot test actual CIFS mounting in containers
- Focus on package installation and file creation
- Use delegated driver for real mount testing

**Tests to Implement:**
```yaml
# verify.yml
- name: Verify storagebox role
  hosts: all
  tasks:
    # Package test
    - name: Check cifs-utils installed
      command: which mount.cifs
      changed_when: false

    # Mount point test
    - name: Check mount point exists
      stat:
        path: /mnt/storagebox
      register: mount_point
      failed_when: not mount_point.stat.exists or not mount_point.stat.isdir

    # Credentials file test
    - name: Check credentials file exists with correct permissions
      stat:
        path: /root/.storagebox-credentials
      register: creds
      failed_when: not creds.stat.exists or creds.stat.mode != '0600'

    # Note: Actual mount test requires real Storage Box, test in integration environment
```

#### Role: backup (Priority: P0)

**Molecule Test Status:** To be implemented
**Test File:** `ansible/roles/backup/molecule/default/`

**Tests to Implement:**
```yaml
# verify.yml
- name: Verify backup role
  hosts: all
  tasks:
    # Backup script test
    - name: Check backup script exists
      stat:
        path: /opt/scripts/backup.sh
      register: backup_script
      failed_when: not backup_script.stat.exists or not backup_script.stat.executable

    # Cron job test
    - name: Verify backup cron job
      shell: crontab -l | grep -q backup.sh
      changed_when: false

    # Log directory test
    - name: Check backup log directory
      stat:
        path: /var/log/homelab
      register: log_dir
      failed_when: not log_dir.stat.exists
```

### 5.3 Idempotency Requirements

**Definition:** Running a playbook twice against the same system MUST produce:
- First run: `changed` > 0 (initial configuration applied)
- Second run: `changed` = 0 (no further changes needed)

**Verification Command:**
```bash
# Run twice, compare changed counts
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg | tee run1.log
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg | tee run2.log

# Check second run shows changed=0
grep "changed=" run2.log
# Expected: changed=0
```

**Common Non-Idempotent Patterns to Avoid:**

```yaml
# ❌ BAD: Always reports changed
- name: Run script
  shell: /path/to/script.sh

# ✅ GOOD: Conditional change reporting
- name: Run script
  shell: /path/to/script.sh
  register: result
  changed_when: "'CHANGED' in result.stdout"

# ❌ BAD: Package upgrade always runs
- name: Upgrade all packages
  apt:
    upgrade: dist

# ✅ GOOD: Controlled by variable
- name: Upgrade all packages
  apt:
    upgrade: dist
  when: common_upgrade_dist | default(false)

# ❌ BAD: Template with timestamp
- name: Deploy config with timestamp
  template:
    src: config.j2
    dest: /etc/config
  vars:
    timestamp: "{{ ansible_date_time.iso8601 }}"

# ✅ GOOD: Template without dynamic data
- name: Deploy config
  template:
    src: config.j2
    dest: /etc/config
  # No timestamp variable
```

### 5.4 Automation via Justfile

**Recommended Justfile Recipes:**

```just
# Validate Ansible syntax
ansible-syntax:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible
    ansible-playbook playbooks/bootstrap.yaml --syntax-check
    ansible-playbook playbooks/deploy.yaml --syntax-check

# Lint Ansible roles
ansible-lint:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible
    ansible-lint roles/ playbooks/

# Run Ansible check-mode against test environment
ansible-check:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible
    ansible-playbook playbooks/deploy.yaml --check --diff --limit test-1.dev.nbg

# Test Ansible idempotency
ansible-idempotency-test:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible
    echo "=== First run (applying changes) ==="
    ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg | tee /tmp/ansible-run1.log
    echo "=== Second run (checking idempotency) ==="
    ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg | tee /tmp/ansible-run2.log
    # Extract changed count from second run
    CHANGED=$(grep "changed=" /tmp/ansible-run2.log | tail -1 | sed 's/.*changed=\\([0-9]*\\).*/\\1/')
    if [ "$CHANGED" -eq 0 ]; then
        echo "✅ Idempotency verified: changed=0"
        exit 0
    else
        echo "❌ Idempotency FAILED: changed=$CHANGED (expected 0)"
        exit 1
    fi

# Run Molecule tests for specific role
ansible-molecule-test role:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible/roles/{{role}}
    molecule test
```

**Usage:**
```bash
# Run all Ansible tests
just ansible-syntax && just ansible-lint && just ansible-check

# Test specific role with Molecule
just ansible-molecule-test common

# Verify idempotency before deployment
just ansible-idempotency-test
```

---

## 6. Test Environments

### 6.1 Environment Definitions

#### Local Development Environment

**Purpose:** Fast feedback loop for syntax and unit tests
**Location:** Developer's workstation
**Infrastructure:** None (dry-run only)
**Test Types:** Unit tests, syntax validation, build validation

**Characteristics:**
- No real infrastructure required
- Tests run in seconds
- No side effects
- Highly parallelizable

**Usage:**
```bash
# Nix tests
nix flake check
nix build --dry-run ...

# Terraform tests
tofu validate

# Ansible tests
ansible-playbook --syntax-check ...
ansible-lint ...
```

**Limitations:**
- Cannot test actual deployments
- Cannot verify system integration
- Cannot test real network connectivity

#### test-1.dev.nbg (Integration Test Environment)

**Purpose:** Integration testing in realistic environment
**Location:** Hetzner Cloud (Nuremberg datacenter)
**Infrastructure:**
- Server: Ubuntu 24.04
- Type: CAX11 (ARM64, 2 cores, 4GB RAM)
- Network: 10.0.0.20 (private), public IP
- Environment: dev

**Test Types:** Integration tests, check-mode validation, idempotency tests

**Characteristics:**
- Real VPS instance
- Safe to break and rebuild
- Production-like configuration
- Network-isolated (test environment)

**Usage:**
```bash
# Ansible check-mode
ansible-playbook playbooks/deploy.yaml --check --limit test-1.dev.nbg

# Ansible deployment
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg

# Idempotency testing
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg  # Run twice
```

**Limitations:**
- Single test instance (cannot test clustering)
- ARM64 architecture (may differ from x86_64 production servers)
- Not identical to production (Ubuntu vs Debian/Rocky)

**Best Practices:**
- Treat as disposable - can rebuild anytime
- Test destructive operations here first
- Do not store important data
- Document any manual configuration

#### Production Environment (prod)

**Purpose:** Final validation before real use
**Location:** Hetzner Cloud (multiple datacenters)
**Infrastructure:**
- mail-1.prod.nbg: Debian 12, CAX21 (4 cores, 8GB)
- syncthing-1.prod.hel: Rocky Linux 9, CAX11 (2 cores, 4GB)

**Test Types:** Validation tests, smoke tests only

**Characteristics:**
- Real production systems
- Cannot be broken
- Requires maintenance windows
- Full backup before changes

**Usage:**
```bash
# Always use --check first
ansible-playbook playbooks/deploy.yaml --check --limit prod

# Review changes carefully
# If safe, apply
ansible-playbook playbooks/deploy.yaml --limit prod

# Verify after deployment
ansible-playbook playbooks/deploy.yaml --check --limit prod
# Expected: changed=0 (idempotent)
```

**Limitations:**
- Downtime affects users
- Cannot test destructive operations
- Rollback required if issues found

**Best Practices:**
- Never test new features in production first
- Always run check-mode first
- Have rollback plan ready
- Schedule changes for maintenance windows
- Verify in test-1.dev.nbg before production

### 6.2 Test Environment Usage Matrix

| Test Type | Local | test-1.dev.nbg | Production |
|-----------|-------|----------------|------------|
| **Nix Tests** |
| nix flake check | ✅ Every commit | ❌ Not applicable | ❌ Not applicable |
| Dry-run builds | ✅ Every commit | ❌ Not applicable | ❌ Not applicable |
| NixOS VM tests | ✅ Before merge | ❌ Not applicable | ❌ Not applicable |
| **Terraform Tests** |
| tofu validate | ✅ Every commit | ❌ Not applicable | ❌ Not applicable |
| tofu plan | ✅ Before apply | ⚠️ Review only | ⚠️ Before apply |
| Drift detection | ✅ Scheduled | ❌ Not applicable | ✅ Daily |
| **Ansible Tests** |
| Syntax check | ✅ Every commit | ❌ Not applicable | ❌ Not applicable |
| ansible-lint | ✅ Before PR | ❌ Not applicable | ❌ Not applicable |
| Check-mode | ❌ No target | ✅ Before deploy | ✅ Before deploy |
| Idempotency test | ❌ No target | ✅ After changes | ⚠️ Verification only |
| Molecule tests | ✅ After role changes | ❌ Not needed | ❌ Not needed |

### 6.3 Environment Selection Guidelines

**Choose Local Environment when:**
- Testing syntax changes
- Validating module structure
- Running unit tests
- Quick iteration during development

**Choose test-1.dev.nbg when:**
- Testing Ansible playbooks
- Verifying system integration
- Testing network configuration
- Validating secrets decryption
- Checking idempotency

**Choose Production when:**
- Final deployment step
- Validation after deployment
- Drift detection
- Smoke testing

---

## 7. Test Data Management

### 7.1 SOPS Test Fixtures

**Purpose:** Enable builds and tests without requiring production secrets

**Fixture Files:**
- `secrets/users.yaml` - User password hashes (test data)
- `secrets/ssh-keys.yaml` - SSH key placeholders (test data)
- `secrets/pgp-keys.yaml` - PGP key placeholders (test data)
- `secrets/storagebox.yaml` - Storage Box credentials (production - NOT a fixture)

**Test Fixture Characteristics:**
- Encrypted with SOPS using project age key
- Contain placeholder data (e.g., "test-password-placeholder")
- Committed to git (safe because encrypted and not real secrets)
- Enable `nix flake check` and build tests without production data

**Creating Test Fixtures:**

```bash
# 1. Create plaintext secret file
cat > /tmp/users-test.yaml <<EOF
mi-skam: "\$6\$rounds=65536\$test-salt-placeholder\$..."
plumps: "\$6\$rounds=65536\$test-salt-placeholder\$..."
EOF

# 2. Encrypt with SOPS
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops encrypt /tmp/users-test.yaml > secrets/users.yaml

# 3. Stage for git (required for Nix flakes)
git add secrets/users.yaml

# 4. Clean up plaintext
rm /tmp/users-test.yaml
```

**Generating Test Password Hashes:**

```bash
# Generate SHA-512 hash for test password
mkpasswd -m sha-512 "test-password-placeholder"
# Output: $6$rounds=65536$...
```

### 7.2 Production Secrets Management

**Production secrets are NEVER committed to git.**

**Deployment Process:**

1. **Age Key Deployment (One-Time Setup):**
   ```bash
   # On NixOS systems
   sudo mkdir -p /etc/sops/age
   sudo cp ~/.config/sops/age/keys.txt /etc/sops/age/keys.txt
   sudo chmod 600 /etc/sops/age/keys.txt
   sudo chown root:root /etc/sops/age/keys.txt

   # For Home Manager
   mkdir -p ~/.config/sops/age
   cp /path/to/keys.txt ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

2. **Replace Test Fixtures with Production Secrets:**
   ```bash
   # Edit production secrets
   sops secrets/users.yaml
   # Replace test password hashes with real hashes

   # Do NOT commit these changes to git
   # Keep production secrets local only
   ```

3. **Verify Secrets Decrypt:**
   ```bash
   # Test decryption
   sops -d secrets/users.yaml
   # Should show real password hashes
   ```

### 7.3 Test Data vs Production Data

| Secret File | Test Fixture | Production |
|-------------|--------------|------------|
| `secrets/users.yaml` | ✅ Committed (test hashes) | ❌ Local only (real hashes) |
| `secrets/ssh-keys.yaml` | ✅ Committed (dummy keys) | ❌ Local only (real keys) |
| `secrets/pgp-keys.yaml` | ✅ Committed (dummy keys) | ❌ Local only (real keys) |
| `secrets/hetzner.yaml` | ✅ Committed (dummy token) | ❌ Local only (real token) |
| `secrets/storagebox.yaml` | ❌ Never committed | ❌ Local only (real credentials) |

### 7.4 Test Resource Cleanup

**Terraform Test Resources:**

No separate test resources created - Terraform tests validate real infrastructure in dry-run mode.

**Ansible Test Containers (Molecule):**

```bash
# Cleanup after Molecule tests
cd ansible/roles/common
molecule destroy

# Cleanup all Molecule instances
for role in ansible/roles/*/; do
    cd "$role"
    if [ -d molecule ]; then
        molecule destroy
    fi
    cd -
done
```

**NixOS VM Tests:**

VM tests create temporary VMs that are automatically cleaned up after test completion. No manual cleanup required.

---

## 8. Coverage Goals and Prioritization

### 8.1 Test Prioritization Framework

**Priority 0 (P0) - Critical Path**
**Coverage Goal:** 80%
**Definition:** Failures break production deployments or cause data loss

**Includes:**
- NixOS/Darwin system builds
- User account creation and authentication
- Secrets decryption
- SSH access
- Terraform state operations
- Ansible common role (base system configuration)
- Backup operations

**Why P0:**
- System unusable if these fail
- No workaround available
- Affects all users/services

**Testing Requirements:**
- Unit tests (syntax validation)
- Integration tests (build validation, VM tests)
- Validation tests (actual deployment)
- Idempotency verification

---

**Priority 1 (P1) - Standard Features**
**Coverage Goal:** 50%
**Definition:** Failures impact user experience but have workarounds

**Includes:**
- Home Manager configurations
- Desktop environment setup
- Development tools
- Ansible monitoring role
- Ansible storagebox role
- Terraform drift detection

**Why P1:**
- Important for usability but not critical
- Workarounds exist (manual configuration)
- Affects specific users or use cases

**Testing Requirements:**
- Unit tests (syntax validation)
- Integration tests (build validation)
- Basic smoke tests

---

**Priority 2 (P2) - Optional Features**
**Coverage Goal:** 20%
**Definition:** Nice-to-have features with minimal impact if broken

**Includes:**
- Optional packages (ghostty, qbittorrent)
- Experimental configurations
- Nice-to-have customizations
- Legacy compatibility

**Why P2:**
- Can be disabled without major impact
- Affects small subset of users
- Non-essential functionality

**Testing Requirements:**
- Unit tests (syntax validation)
- No dedicated integration tests
- Best-effort validation

### 8.2 Priority Classification by Component

#### Nix Configurations

| Component | Priority | Coverage Target | Rationale |
|-----------|----------|-----------------|-----------|
| **System Modules** |
| modules/nixos/common.nix | P0 | 80% | Base system configuration |
| modules/darwin/common.nix | P0 | 80% | Base macOS configuration |
| modules/users/* | P0 | 80% | User authentication critical |
| modules/nixos/server.nix | P0 | 80% | Server deployments depend on this |
| modules/nixos/desktop.nix | P1 | 50% | Desktop feature, not critical |
| modules/nixos/plasma.nix | P1 | 50% | Optional desktop environment |
| **Home Modules** |
| modules/hm/common.nix | P1 | 50% | User environment important but not critical |
| modules/hm/dev.nix | P1 | 50% | Development tools |
| modules/hm/desktop.nix | P2 | 20% | Desktop apps |
| modules/hm/qbittorrent.nix | P2 | 20% | Optional package |
| modules/hm/ghostty.nix | P2 | 20% | Optional package |
| **Library Modules** |
| modules/lib/mkUser.nix | P0 | 80% | Used by all user configs |
| modules/lib/system-common.nix | P0 | 80% | Used by all system configs |
| modules/lib/hm-helpers.nix | P1 | 50% | Helper functions |
| modules/lib/platform.nix | P1 | 50% | Platform detection utility |
| **Secrets** |
| modules/*/secrets.nix | P0 | 80% | Secrets decryption critical |

#### Terraform Modules

| Component | Priority | Coverage Target | Rationale |
|-----------|----------|-----------------|-----------|
| terraform/servers.tf | P0 | 80% | VPS instances critical |
| terraform/network.tf | P0 | 80% | Network connectivity critical |
| terraform/outputs.tf | P1 | 50% | Output useful but not critical |
| terraform/import.sh | P0 | 80% | State consistency critical |
| terraform/drift-detection.sh | P1 | 50% | Drift detection important |

#### Ansible Roles

| Role | Priority | Coverage Target | Rationale |
|------|----------|-----------------|-----------|
| common | P0 | 80% | Base configuration for all servers |
| backup | P0 | 80% | Data loss prevention |
| storagebox | P1 | 50% | Backup storage important |
| monitoring | P1 | 50% | Observability important |

#### Playbooks

| Playbook | Priority | Coverage Target | Rationale |
|----------|----------|-----------------|-----------|
| bootstrap.yaml | P0 | 80% | Initial server setup |
| deploy.yaml | P0 | 80% | Configuration updates |
| setup-storagebox.yaml | P1 | 50% | Storage setup |
| mailcow-backup.yaml | P0 | 80% | Email backup critical |

### 8.3 Test Coverage Metrics

**How to Measure Coverage:**

**Nix Configurations:**
```bash
# Total configurations
TOTAL_CONFIGS=$(nix flake show --json | jq '[.nixosConfigurations, .darwinConfigurations, .homeConfigurations] | add | length')

# Configurations with tests
TESTED_CONFIGS=$(find tests/nixos -name "*.nix" | wc -l)

# Coverage percentage
COVERAGE=$((TESTED_CONFIGS * 100 / TOTAL_CONFIGS))
echo "Nix Test Coverage: $COVERAGE%"
```

**Terraform Resources:**
```bash
# Total resources
TOTAL_RESOURCES=$(cd terraform && tofu state list | wc -l)

# Resources with validation tests (all resources have syntax/plan tests)
TESTED_RESOURCES=$TOTAL_RESOURCES  # All resources tested via validate/plan

# Coverage percentage
echo "Terraform Test Coverage: 100% (all resources validated via plan)"
```

**Ansible Roles:**
```bash
# Total roles
TOTAL_ROLES=$(find ansible/roles -maxdepth 1 -type d | tail -n +2 | wc -l)

# Roles with Molecule tests
TESTED_ROLES=$(find ansible/roles -name "molecule" -type d | wc -l)

# Coverage percentage
COVERAGE=$((TESTED_ROLES * 100 / TOTAL_ROLES))
echo "Ansible Role Coverage: $COVERAGE%"
```

### 8.4 Coverage Goals Timeline

**Phase 1 (I6.T1-I6.T4): Foundation (Current)**
- Establish testing strategy ✅
- Implement P0 tests for critical components
- Target: 80% P0 coverage

**Phase 2 (I6.T5): Integration**
- Implement P1 tests for standard features
- Target: 50% P1 coverage
- Integrate tests into justfile/CI

**Phase 3 (Future): Optimization**
- Implement P2 tests for optional features
- Target: 20% P2 coverage
- Optimize test execution time

**Measurement Cadence:**
- **Weekly:** Review P0 coverage (must stay ≥80%)
- **Monthly:** Review P1/P2 coverage trends
- **Quarterly:** Reassess priorities based on usage patterns

---

## 9. Workflow Integration

### 9.1 When to Run Tests

Infrastructure testing is integrated into the development and deployment workflow at multiple stages to catch errors early and ensure safe deployments.

#### Local Development (Every Code Change)

**When:** Making changes to Nix modules, Terraform configurations, or Ansible roles
**Tests to Run:** Syntax validation (fast feedback)
**Execution Time:** < 30 seconds
**Command:**
```bash
# Quick syntax check before committing
nix flake check                                    # Nix configurations
cd terraform && tofu validate                       # Terraform syntax
cd ansible && ansible-playbook playbooks/*.yaml --syntax-check  # Ansible syntax
```

**Why:** Catch syntax errors immediately before they propagate to other developers or break builds.

#### Pre-Commit (Before Staging Changes)

**When:** Before running `git add` and `git commit`
**Tests to Run:** Syntax validation + basic build validation
**Execution Time:** 1-2 minutes
**Command:**
```bash
# Comprehensive pre-commit check
nix flake check
nix build '.#nixosConfigurations.xmsi.config.system.build.toplevel' --dry-run
cd terraform && tofu validate && tofu plan -backend=false
cd ansible && ansible-lint roles/ playbooks/
```

**Why:** Ensure changes build correctly before committing. Prevents broken commits from entering git history.

#### Pre-Deployment (Before Any Production Change)

**When:** Before deploying to production systems
**Tests to Run:** Complete validation (secrets + all tests)
**Execution Time:** ~15 minutes
**Command:**
```bash
# Master validation command
just validate-all

# Or run components separately
just validate-secrets  # ~2 seconds
just test-all         # ~15 minutes
```

**Why:** Final safety gate before production deployment. Validates both secrets and infrastructure configurations are correct.

#### CI/CD Pipeline (Automated)

**When:** On every pull request and merge to main
**Tests to Run:** Full test suite + deployment validation
**Execution Time:** 15-20 minutes
**Triggers:**
- Pull request opened/updated
- Commit pushed to main branch
- Scheduled nightly builds

**Why:** Automated validation ensures all changes meet quality standards before merge. Catches issues that might have been missed locally.

### 9.2 How to Run Tests

#### Individual Test Suites

**NixOS VM Tests:**
```bash
just test-nixos

# What it does:
# - Checks system architecture (skips on non-x86_64-linux)
# - Runs xmsi configuration test (desktop)
# - Runs srv-01 configuration test (server)
# - Verifies boot, users, secrets, services

# Expected output:
# ════════════════════════════════════════
#   NixOS VM Testing
# ════════════════════════════════════════
# → Running xmsi configuration test...
# ✓ xmsi test passed
# → Running srv-01 configuration test...
# ✓ srv-01 test passed
# ════════════════════════════════════════
# ✅ All NixOS VM tests passed
# ════════════════════════════════════════
```

**Terraform Validation Tests:**
```bash
just test-terraform

# What it does:
# - Runs terraform/run-tests.sh validation suite
# - Validates HCL syntax (tofu validate)
# - Checks plan generation (tofu plan -backend=false)
# - Validates import script syntax
# - Verifies required outputs are defined

# Expected output:
# ════════════════════════════════════════
#   Terraform Validation Testing
# ════════════════════════════════════════
# → Running validation tests...
# ✓ Syntax validation passed
# ✓ Plan validation passed
# ✓ Import script validation passed
# ✓ Output validation passed
# ════════════════════════════════════════
# ✅ All Terraform tests passed
# ════════════════════════════════════════
```

**Ansible Molecule Tests:**
```bash
just test-ansible

# What it does:
# - Checks Docker is running
# - Runs Molecule tests for common role
# - Runs Molecule tests for monitoring role
# - Runs Molecule tests for backup role
# - Verifies idempotency (second run has changed=0)

# Expected output:
# ════════════════════════════════════════
#   Ansible Molecule Testing
# ════════════════════════════════════════
# → Testing common role...
# ✓ common role tests passed
# → Testing monitoring role...
# ✓ monitoring role tests passed
# → Testing backup role...
# ✓ backup role tests passed
# ════════════════════════════════════════
# ✅ All Ansible Molecule tests passed
# ════════════════════════════════════════
```

#### Master Test Command

**Run All Tests:**
```bash
just test-all

# What it does:
# - Runs test-nixos (NixOS VM tests)
# - Runs test-terraform (Terraform validation)
# - Runs test-ansible (Ansible Molecule tests)
# - Provides comprehensive test summary
# - Exits on first failure (fail-fast)

# Expected output:
# ════════════════════════════════════════
#   Infrastructure Test Suite
# ════════════════════════════════════════
# Running all infrastructure tests...
#
# → Running NixOS tests...
# [NixOS test output]
# ✓ NixOS tests passed
#
# → Running Terraform tests...
# [Terraform test output]
# ✓ Terraform tests passed
#
# → Running Ansible tests...
# [Ansible test output]
# ✓ Ansible tests passed
#
# ════════════════════════════════════════
# Test Summary (Complete)
# ════════════════════════════════════════
# NixOS:     PASS
# Terraform: PASS
# Ansible:   PASS
# Overall:   PASS
# ════════════════════════════════════════
#
# ✅ All infrastructure tests passed
```

#### Comprehensive Validation

**Run Secrets + All Tests:**
```bash
just validate-all

# What it does:
# - Runs validate-secrets (secrets format validation)
# - Runs test-all (all infrastructure tests)
# - Provides comprehensive validation summary
# - Exits on first failure (fail-fast)

# Expected output:
# ════════════════════════════════════════
#   Comprehensive Pre-Deployment Validation
# ════════════════════════════════════════
#
# → Validating secrets...
# ✓ Secrets validated
#
# → Running all infrastructure tests...
# [Test output from test-all]
#
# ════════════════════════════════════════
# Validation Summary
# ════════════════════════════════════════
# Secrets:   PASS
# Tests:     PASS
# Overall:   PASS
# ════════════════════════════════════════
#
# ✅ Comprehensive validation successful - safe to deploy
```

### 9.3 How to Interpret Test Results

#### Exit Codes

All test commands follow consistent exit code conventions:

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| `0` | All tests passed | Safe to proceed |
| `1` | One or more tests failed | Fix issues before proceeding |
| `2` | Error (e.g., Docker not running) | Resolve environment issue |

**Checking exit codes:**
```bash
just test-all
echo $?  # 0 = success, 1 = failure

# Or use in scripts
if just test-all; then
    echo "Tests passed"
else
    echo "Tests failed" >&2
    exit 1
fi
```

#### Output Format

**Success Indicators:**
- `✓` - Individual test passed
- `✅` - All tests in suite passed
- `PASS` - Test result is success

**Failure Indicators:**
- `❌` - Test failed
- `FAIL` - Test result is failure
- `NOT RUN` - Test was skipped due to earlier failure

**Info Indicators:**
- `→` - Test is running
- `⚠️` - Warning (test skipped for valid reason)

#### Test Summary

All test commands provide a summary at the end:

```
════════════════════════════════════════
Test Summary (Complete)
════════════════════════════════════════
NixOS:     PASS
Terraform: PASS
Ansible:   PASS
Overall:   PASS
════════════════════════════════════════
```

**Reading the summary:**
- **Individual results** show status of each test suite
- **Overall** shows aggregated result (PASS only if all PASS)
- **Partial summary** shown if test suite exits early

### 9.4 Debugging Test Failures

When tests fail, follow this debugging workflow:

#### Step 1: Identify Which Test Failed

Look at the test summary or error output:

```
→ Running NixOS tests...
❌ NixOS tests failed
════════════════════════════════════════
Test Summary (Partial)
════════════════════════════════════════
NixOS:     FAIL
Terraform: NOT RUN
Ansible:   NOT RUN
Overall:   FAIL
════════════════════════════════════════
```

**Failed test:** NixOS

#### Step 2: Run Failed Test in Isolation

```bash
# Run just the failed test suite for detailed output
just test-nixos

# For even more detail, run the underlying command directly
nix build .#checks.x86_64-linux.xmsi-test --print-build-logs
```

#### Step 3: Analyze Error Messages

**Common NixOS test errors:**

```
Error: Test timeout waiting for systemd target
```
**Cause:** System failed to boot or service failed to start
**Solution:** Check systemd unit configuration, review service logs in test output

```
Error: User 'mi-skam' does not exist
```
**Cause:** User creation failed or mkUser.nix not imported correctly
**Solution:** Verify user module imports, check SOPS secrets decryption

```
Error: Secret file not found at /run/secrets/mi-skam
```
**Cause:** SOPS secrets failed to decrypt
**Solution:** Check age key configuration, verify secrets file format

**Common Terraform test errors:**

```
Error: Invalid HCL syntax
```
**Cause:** Syntax error in .tf files
**Solution:** Run `tofu validate` to identify exact location

```
Error: Plan generation failed: authentication error
```
**Cause:** Hetzner API token invalid or missing
**Solution:** Check `secrets/hetzner.yaml`, verify token is encrypted correctly

**Common Ansible test errors:**

```
Error: Docker daemon not accessible
```
**Cause:** Docker not running or not in PATH
**Solution:** Start Docker, ensure `docker info` works

```
TASK [common : Install packages] ... changed: [debian-12]
... [second run]
TASK [common : Install packages] ... changed: [debian-12]
Idempotency test failed
```
**Cause:** Task is not idempotent (always reports changed)
**Solution:** Add `changed_when` condition or use more specific module

#### Step 4: Fix and Re-test

```bash
# After fixing the issue, re-run the test
just test-nixos

# If passes, run full suite to ensure fix didn't break other tests
just test-all
```

#### Step 5: Verify in Clean Environment

```bash
# Clean Nix build cache
nix-collect-garbage

# Re-run tests to verify fix works in clean environment
just test-all
```

### 9.5 CI/CD Integration Notes

Tests are designed to run in CI/CD environments with the following considerations:

#### Non-Interactive Execution

**All test commands are non-interactive:**
- No user prompts
- No password requests
- No manual confirmations

**Example:** Safe to run in CI pipelines
```bash
# These commands never prompt for input
just test-all
just validate-all
```

#### Clear Exit Codes

**Exit code 0 = success, 1 = failure:**
```bash
# CI/CD can check exit code directly
just test-all || exit 1
```

#### CI/CD-Friendly Output

**Output characteristics:**
- Clear section headers (easy to parse)
- Consistent format (machine-readable)
- Progress indicators (→, ✓, ❌)
- Summary at end (test results)

**Example CI/CD integration (GitHub Actions):**
```yaml
- name: Run infrastructure tests
  run: just test-all

- name: Check test results
  if: failure()
  run: |
    echo "Tests failed - check logs above"
    exit 1
```

#### Platform Compatibility

**NixOS VM tests:**
- Only run on `x86_64-linux` (automatically skipped on other platforms)
- Test output shows skip reason: `⚠️ Skipping NixOS VM tests (only available on x86_64-linux)`

**Ansible Molecule tests:**
- Require Docker (automatically checks for Docker availability)
- Skip gracefully if Docker not running

**Terraform tests:**
- No external dependencies (run on any platform)
- Use dummy tokens for syntax validation (no API calls)

#### Execution Time Considerations

**Test suite execution times:**
- `just test-nixos`: ~5 minutes
- `just test-terraform`: ~10 seconds
- `just test-ansible`: ~10 minutes
- `just test-all`: ~15 minutes total

**Optimization for CI/CD:**
- Run tests in parallel where possible (separate jobs)
- Cache Nix builds between runs
- Cache Docker images for Molecule tests
- Use fast workers for critical path (syntax checks)

**Example parallel execution (GitHub Actions):**
```yaml
jobs:
  test-nix:
    runs-on: ubuntu-latest
    steps:
      - run: just test-nixos

  test-terraform:
    runs-on: ubuntu-latest
    steps:
      - run: just test-terraform

  test-ansible:
    runs-on: ubuntu-latest
    steps:
      - run: just test-ansible
```

**Total execution time with parallelism:** ~10 minutes (limited by slowest test suite)

---

## 10. Continuous Testing Integration

**Note:** This section describes a future CI/CD integration. The infrastructure tests are designed to be CI/CD-compatible, but automatic pipeline execution is not yet implemented. See Section 9.5 for CI/CD integration considerations.

### 10.1 Future CI/CD Pipeline Architecture

**Planned Pipeline Stages:**

```
┌─────────────────┐
│   Code Change   │
│   (git push)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Stage 1: Fast  │
│   Validation    │
│   (~30 sec)     │
├─────────────────┤
│ • nix flake     │
│   check         │
│ • tofu validate │
│ • ansible       │
│   --syntax-check│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Stage 2: Build  │
│   Validation    │
│   (~2 min)      │
├─────────────────┤
│ • nix build     │
│   --dry-run     │
│ • tofu plan     │
│ • ansible-lint  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Stage 3: Integ   │
│   Tests         │
│   (~5 min)      │
├─────────────────┤
│ • NixOS VM tests│
│ • Ansible check │
│   -mode         │
│ • Molecule tests│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Stage 4: PR    │
│   Review        │
│   (manual)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Stage 5: Deploy │
│   Validation    │
│   (~10 min)     │
├─────────────────┤
│ • Deploy to     │
│   test-1.dev    │
│ • Idempotency   │
│   check         │
│ • Smoke tests   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Production     │
│  Deployment     │
│  (manual)       │
└─────────────────┘
```

### 10.2 Planned Test Triggers

#### Trigger: Every Commit (Pre-Push Hook)

**Purpose:** Catch errors before pushing to remote
**Execution Time:** ~30 seconds
**Blocking:** Yes (prevents push if fails)

**Tests to Run:**
```bash
# .git/hooks/pre-push
#!/usr/bin/env bash
set -euo pipefail

echo "Running pre-push validation..."

# Nix syntax
nix flake check || exit 1

# Terraform syntax
cd terraform && tofu validate || exit 1

# Ansible syntax
cd ansible
ansible-playbook playbooks/bootstrap.yaml --syntax-check || exit 1
ansible-playbook playbooks/deploy.yaml --syntax-check || exit 1

echo "✅ Pre-push validation passed"
```

**Setup:**
```bash
# Install pre-push hook
cp scripts/pre-push-hook.sh .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

#### Trigger: Pull Request

**Purpose:** Comprehensive validation before merge
**Execution Time:** ~10 minutes
**Blocking:** Yes (PR cannot merge if fails)

**Tests to Run:**
```yaml
# .github/workflows/pr-validation.yml
name: PR Validation

on: [pull_request]

jobs:
  fast-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - name: Nix flake check
        run: nix flake check
      - name: Terraform validate
        run: cd terraform && terraform validate
      - name: Ansible syntax check
        run: |
          cd ansible
          ansible-playbook playbooks/*.yaml --syntax-check

  build-validation:
    needs: fast-validation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - name: Build NixOS configs
        run: |
          nix build '.#nixosConfigurations.xmsi.config.system.build.toplevel' --dry-run
          nix build '.#nixosConfigurations.srv-01.config.system.build.toplevel' --dry-run
      - name: Terraform plan
        env:
          TF_VAR_hcloud_token: ${{ secrets.HETZNER_API_TOKEN }}
        run: cd terraform && terraform plan

  integration-tests:
    needs: build-validation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - name: Run NixOS VM tests
        run: nix-build tests/nixos/xmsi-test.nix
      - name: Run Molecule tests
        run: |
          cd ansible/roles/common
          molecule test
```

#### Trigger: Module Changes

**Purpose:** Run targeted tests when specific modules change
**Execution Time:** Variable
**Blocking:** Yes for critical modules (P0)

**Conditional Test Execution:**
```yaml
# .github/workflows/module-tests.yml
name: Module Tests

on:
  pull_request:
    paths:
      - 'modules/**'
      - 'ansible/roles/**'

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      nix-modules: ${{ steps.filter.outputs.nix }}
      ansible-roles: ${{ steps.filter.outputs.ansible }}
    steps:
      - uses: actions/checkout@v3
      - uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            nix:
              - 'modules/**/*.nix'
            ansible:
              - 'ansible/roles/**/*.yaml'

  test-nix-modules:
    needs: detect-changes
    if: needs.detect-changes.outputs.nix-modules == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - name: Run NixOS VM tests
        run: nix-build tests/nixos/all-tests.nix

  test-ansible-roles:
    needs: detect-changes
    if: needs.detect-changes.outputs.ansible-roles == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Molecule tests for changed roles
        run: |
          # Detect which roles changed
          CHANGED_ROLES=$(git diff --name-only HEAD^ | grep "^ansible/roles/" | cut -d/ -f3 | sort -u)
          for role in $CHANGED_ROLES; do
            cd ansible/roles/$role
            if [ -d molecule ]; then
              molecule test
            fi
            cd -
          done
```

#### Trigger: Scheduled (Nightly)

**Purpose:** Detect drift, validate long-running stability
**Execution Time:** ~30 minutes
**Blocking:** No (reports only)

**Scheduled Tests:**
```yaml
# .github/workflows/nightly-validation.yml
name: Nightly Validation

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily

jobs:
  drift-detection:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check Terraform drift
        env:
          TF_VAR_hcloud_token: ${{ secrets.HETZNER_API_TOKEN }}
        run: |
          cd terraform
          ./drift-detection.sh

  full-integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - name: Run all NixOS VM tests
        run: nix-build tests/nixos/all-tests.nix
      - name: Deploy to test environment
        run: |
          cd ansible
          ansible-playbook playbooks/deploy.yaml --check --limit test-1.dev.nbg

  dependency-updates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - name: Update flake inputs
        run: |
          nix flake update
          nix flake check
      - name: Create PR if updates succeed
        if: success()
        uses: peter-evans/create-pull-request@v5
        with:
          title: "chore: Update Nix flake inputs (automated)"
          body: "Automated flake input updates from nightly job"
```

### 10.3 Integration with Justfile

**Unified Test Command:**

```just
# Run all tests (comprehensive validation)
test:
    @echo "=== Running comprehensive test suite ==="
    just test-nix
    just test-terraform
    just test-ansible
    @echo "✅ All tests passed"

# Test Nix configurations
test-nix:
    @echo "=== Testing Nix configurations ==="
    nix flake check
    nix build '.#nixosConfigurations.xmsi.config.system.build.toplevel' --dry-run
    nix build '.#nixosConfigurations.srv-01.config.system.build.toplevel' --dry-run
    nix build '.#darwinConfigurations.xbook.system' --dry-run
    @echo "✅ Nix tests passed"

# Test Terraform configuration
test-terraform:
    @echo "=== Testing Terraform configuration ==="
    cd terraform && tofu validate
    just tf-plan
    cd terraform && ./drift-detection.sh
    @echo "✅ Terraform tests passed"

# Test Ansible roles and playbooks
test-ansible:
    @echo "=== Testing Ansible configuration ==="
    cd ansible && ansible-playbook playbooks/bootstrap.yaml --syntax-check
    cd ansible && ansible-playbook playbooks/deploy.yaml --syntax-check
    cd ansible && ansible-lint roles/ playbooks/
    cd ansible && ansible-playbook playbooks/deploy.yaml --check --limit test-1.dev.nbg
    @echo "✅ Ansible tests passed"

# Test specific component
test-component component:
    @echo "=== Testing {{component}} ==="
    @if [ "{{component}}" = "nix" ]; then just test-nix; \
     elif [ "{{component}}" = "terraform" ]; then just test-terraform; \
     elif [ "{{component}}" = "ansible" ]; then just test-ansible; \
     else echo "❌ Unknown component: {{component}}"; exit 1; fi

# Run tests before committing
pre-commit:
    @echo "=== Running pre-commit validation ==="
    nix flake check
    cd terraform && tofu validate
    cd ansible && ansible-playbook playbooks/*.yaml --syntax-check
    @echo "✅ Pre-commit validation passed - safe to commit"

# Run tests before pushing
pre-push:
    @echo "=== Running pre-push validation ==="
    just pre-commit
    just test-nix
    @echo "✅ Pre-push validation passed - safe to push"
```

**Usage:**
```bash
# Run all tests
just test

# Run specific test suite
just test-nix
just test-terraform
just test-ansible

# Pre-commit check (fast)
just pre-commit

# Pre-push check (comprehensive)
just pre-push
```

### 10.4 Test Failure Handling

**Failure Response Workflow:**

```
Test Fails
    │
    ▼
Identify Stage
    │
    ├─→ Stage 1 (Syntax): Fix immediately, block all work
    ├─→ Stage 2 (Build): Fix before PR, block merge
    ├─→ Stage 3 (Integration): Fix before merge, allow WIP commits
    └─→ Stage 4 (Deployment): Rollback, create incident

    │
    ▼
Root Cause Analysis
    │
    ├─→ Syntax error: Fix code, add pre-commit hook
    ├─→ Dependency issue: Pin versions, update lockfile
    ├─→ Configuration error: Fix config, add validation
    ├─→ Environment issue: Document, add to runbook
    └─→ Test flake: Fix test, add idempotency check

    │
    ▼
Verify Fix
    │
    ├─→ Run failed test locally
    ├─→ Run full test suite
    └─→ Deploy to test environment

    │
    ▼
Prevent Recurrence
    │
    ├─→ Add new test case
    ├─→ Update documentation
    ├─→ Enhance CI/CD pipeline
    └─→ Update runbook
```

**Notification Channels:**

- **Stage 1-2 failures**: Developer notification (IDE, CLI)
- **Stage 3 failures**: PR comment, Slack/Discord notification
- **Stage 4 failures**: PagerDuty alert, email, SMS

### 10.5 Performance Optimization

**Test Execution Time Targets:**

| Stage | Current | Target | Optimization Strategy |
|-------|---------|--------|----------------------|
| Stage 1 (Syntax) | 30s | 15s | Parallel execution, caching |
| Stage 2 (Build) | 2m | 1m | Nix binary cache, incremental builds |
| Stage 3 (Integration) | 5m | 3m | Parallel VM tests, Docker caching |
| Stage 4 (Deployment) | 10m | 5m | Ansible fact caching, parallel execution |
| **Total** | **17.5m** | **<10m** | Comprehensive optimization |

**Optimization Techniques:**

**1. Nix Binary Cache:**
```nix
# flake.nix
{
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
```

**2. Ansible Fact Caching:**
```ini
# ansible/ansible.cfg
[defaults]
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400  # 24 hours
```

**3. Parallel Test Execution:**
```yaml
# .github/workflows/parallel-tests.yml
jobs:
  test:
    strategy:
      matrix:
        test-suite:
          - nix-nixos
          - nix-darwin
          - nix-home
          - terraform
          - ansible-common
          - ansible-monitoring
      max-parallel: 6
    steps:
      - name: Run ${{ matrix.test-suite }}
        run: just test-${{ matrix.test-suite }}
```

---

## 11. Appendix: Quick Reference

### 11.1 Common Test Commands

**Nix:**
```bash
# Fast syntax check (10s)
nix flake check

# Build validation - NixOS (30s)
nix build '.#nixosConfigurations.xmsi.config.system.build.toplevel' --dry-run

# Build validation - Darwin (20s)
nix build '.#darwinConfigurations.xbook.system' --dry-run

# Build validation - Home Manager (30s)
nix build '.#homeConfigurations."mi-skam@xmsi".activationPackage' --dry-run

# VM test (2-5m)
nix-build tests/nixos/xmsi-test.nix
```

**Terraform:**
```bash
# Syntax check (2s)
cd terraform && tofu validate

# Plan validation (10s)
just tf-plan

# Drift detection (10s)
cd terraform && ./drift-detection.sh

# State import test (30s)
cd terraform && ./import.sh && tofu plan
```

**Ansible:**
```bash
# Syntax check (1s)
ansible-playbook playbooks/deploy.yaml --syntax-check

# Linting (5s)
ansible-lint ansible/roles/ ansible/playbooks/

# Check-mode (30s)
ansible-playbook playbooks/deploy.yaml --check --limit test-1.dev.nbg

# Idempotency test (5m)
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg  # Run twice

# Molecule test (3m per role)
cd ansible/roles/common && molecule test
```

### 11.2 Test Decision Tree

```
Need to test infrastructure change?
│
├─ Changed Nix module?
│  ├─ Yes → nix flake check
│  │      → nix build --dry-run
│  │      → VM test if critical (P0)
│  └─ No → Continue
│
├─ Changed Terraform config?
│  ├─ Yes → tofu validate
│  │      → tofu plan
│  │      → Review plan output
│  └─ No → Continue
│
├─ Changed Ansible role/playbook?
│  ├─ Yes → ansible-playbook --syntax-check
│  │      → ansible-lint
│  │      → ansible-playbook --check
│  │      → Molecule test (if role changed)
│  │      → Idempotency test (2 runs)
│  └─ No → Continue
│
└─ All tests passed?
   ├─ Yes → Safe to deploy
   └─ No → Fix issues, repeat tests
```

### 11.3 Troubleshooting Guide

**Problem: nix flake check fails with "path does not exist"**
- **Cause:** Nix flakes only see git-tracked files
- **Solution:** `git add <file>` then run test again

**Problem: Terraform plan shows unexpected changes**
- **Cause:** Configuration drift or manual changes
- **Solution:** Run `./drift-detection.sh` to identify drift source

**Problem: Ansible shows changed=N on second run (not idempotent)**
- **Cause:** Task always reports changed even when no change made
- **Solution:** Add `changed_when` condition to task

**Problem: Secrets decryption fails in tests**
- **Cause:** SOPS age key not accessible or test fixtures missing
- **Solution:** Ensure `secrets/*.yaml` test fixtures are git-tracked

**Problem: Molecule test fails with "docker: command not found"**
- **Cause:** Docker not installed or not in PATH
- **Solution:** Install Docker or use delegated driver

**Problem: VM test times out**
- **Cause:** VM boot too slow or test waiting for unavailable service
- **Solution:** Increase timeout or remove problematic service from test

### 11.4 Test Maintenance Checklist

**Weekly:**
- [ ] Review failed test reports
- [ ] Update test fixtures if secret format changed
- [ ] Check test execution times (flag slowdowns)

**Monthly:**
- [ ] Review test coverage metrics (P0: 80%, P1: 50%)
- [ ] Update VM tests for new system configurations
- [ ] Audit Molecule tests for deprecated syntax

**Quarterly:**
- [ ] Review and update test prioritization (P0/P1/P2)
- [ ] Benchmark test execution times, optimize slow tests
- [ ] Update testing strategy document

**After Major Changes:**
- [ ] Add tests for new features
- [ ] Update test documentation
- [ ] Verify all existing tests still pass
- [ ] Update CI/CD pipeline if needed

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-30 | Initial comprehensive testing strategy |

---

**End of Testing Strategy Document**
