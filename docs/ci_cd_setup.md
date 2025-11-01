# CI/CD Pipeline Setup and Usage

**Version:** 1.0
**Created:** 2025-11-01
**Purpose:** Automated configuration validation and testing pipeline using GitHub Actions

---

## Table of Contents

1. [Overview](#1-overview)
2. [Pipeline Architecture](#2-pipeline-architecture)
3. [Setup Instructions](#3-setup-instructions)
4. [Pipeline Jobs](#4-pipeline-jobs)
5. [Interpreting Results](#5-interpreting-results)
6. [Debugging Failures](#6-debugging-failures)
7. [Branch Protection](#7-branch-protection)
8. [Performance Optimization](#8-performance-optimization)
9. [Troubleshooting](#9-troubleshooting)
10. [Maintenance](#10-maintenance)

---

## 1. Overview

### 1.1 Purpose

The CI/CD pipeline provides automated validation and testing for all infrastructure changes before they reach production. It ensures:

- **Syntax correctness** - All configurations are valid before merge
- **Test coverage** - Infrastructure changes are validated in isolation
- **Consistent quality** - Every change meets the same standards
- **Safe deployments** - Broken code never reaches production

### 1.2 Pipeline Features

**Validation Gates:**
- Nix flake syntax validation
- Terraform HCL syntax validation
- Ansible playbook syntax validation
- Secrets format validation (optional)

**Testing Gates:**
- NixOS VM tests (system configuration validation)
- Terraform validation tests (infrastructure module validation)
- Ansible Molecule tests (role validation in Docker containers)

**Performance Features:**
- Parallel job execution (independent tests run concurrently)
- Nix binary caching via cachix (faster builds)
- Job concurrency control (cancel in-progress runs on new push)
- Smart timeouts (fail fast on hung tests)

**Quality Gates:**
- All validation gates must pass
- All test suites must pass
- Pipeline blocks PR merge on failure

### 1.3 Pipeline Triggers

**Automatic Triggers:**
- **Pull requests** - All branches, validates changes before merge
- **Push to main** - After merge, validates integrated code

**Manual Triggers:**
- Not currently supported (future enhancement: workflow_dispatch)

**Scheduled Triggers:**
- Not currently implemented (future enhancement: nightly validation)

---

## 2. Pipeline Architecture

### 2.1 Job Dependency Graph

```
┌─────────────────────────────────────────────┐
│          validate-syntax (2-5 min)          │
│  • nix flake check                          │
│  • tofu validate                            │
│  • ansible-playbook --syntax-check          │
└──────────────┬──────────────────────────────┘
               │
               ├───────────────┬────────────────┬────────────────┐
               ▼               ▼                ▼                ▼
      ┌────────────┐  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
      │ validate-  │  │ test-nixos   │ │ test-        │ │ test-ansible │
      │ secrets    │  │ (5-10 min)   │ │ terraform    │ │ (10-15 min)  │
      │ (1-2 min)  │  │              │ │ (10 sec)     │ │              │
      │ (optional) │  │ • VM tests   │ │ • Validation │ │ • Molecule   │
      └────────────┘  │              │ │   tests      │ │   tests      │
                      └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
                             │                │                │
                             └────────────────┴────────────────┘
                                              │
                                              ▼
                                   ┌──────────────────┐
                                   │ pipeline-summary │
                                   │ (5 sec)          │
                                   │ • Report results │
                                   └──────────────────┘
```

### 2.2 Execution Flow

1. **Checkout code** - Clone repository at commit SHA
2. **Install Nix** - Set up Nix package manager with cachix
3. **Syntax validation** - Fast syntax checks (fail early)
4. **Parallel testing** - Run independent test suites concurrently
5. **Summary report** - Aggregate results, report success/failure

**Total execution time:**
- **Minimum (all cached):** ~10 minutes
- **Maximum (cold cache):** ~20 minutes
- **Target (with optimizations):** <15 minutes

### 2.3 Job Parallelization

**Jobs that run in parallel (after syntax validation):**
- `validate-secrets` (if SOPS_AGE_KEY configured)
- `test-nixos` (NixOS VM tests)
- `test-terraform` (Terraform validation)
- `test-ansible` (Ansible Molecule tests)

**Why parallel execution:**
- Reduces total pipeline time from ~30 min (sequential) to ~15 min (parallel)
- Provides faster feedback to developers
- Maximizes CI runner efficiency

---

## 3. Setup Instructions

### 3.1 Prerequisites

**Required:**
- GitHub repository with Actions enabled
- Repository access to create/modify workflows
- Branch protection rules enabled (optional but recommended)

**Optional:**
- Cachix account for Nix binary caching
- SOPS age key for secrets validation

### 3.2 Initial Setup

#### Step 1: Enable GitHub Actions

1. Navigate to repository Settings → Actions → General
2. Set "Actions permissions" to:
   - **Allow all actions and reusable workflows**
   - Or "Allow select actions and reusable workflows" (whitelist)
3. Set "Workflow permissions" to:
   - **Read and write permissions** (for PR comments)
4. Save changes

#### Step 2: Configure Secrets (Optional)

**SOPS Age Key (for secrets validation):**

1. Generate or locate your age private key:
   ```bash
   # View your age key
   cat ~/.config/sops/age/keys.txt
   ```

2. Add to GitHub repository secrets:
   - Go to Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `SOPS_AGE_KEY`
   - Value: Paste your age private key (entire contents of keys.txt)
   - Click "Add secret"

   **⚠️ CRITICAL SECURITY WARNING:**
   - This key decrypts ALL secrets in the repository
   - Only use a dedicated CI/CD key (not your personal key)
   - Rotate this key periodically (recommended: every 90 days)
   - Audit GitHub Actions logs to ensure key is never printed

**Cachix Auth Token (for binary caching):**

1. Create Cachix account at https://cachix.org
2. Create a new cache (or use existing, e.g., "nix-community")
3. Generate auth token:
   - Go to cache settings → Auth tokens
   - Create "Read-only" token for CI (no write access needed)
4. Add to GitHub repository secrets:
   - Name: `CACHIX_AUTH_TOKEN`
   - Value: Paste auth token
   - Click "Add secret"

**Note:** If `CACHIX_AUTH_TOKEN` is not configured, pipeline will use public caches only (slower but functional).

#### Step 3: Commit Workflow File

The workflow file is located at `.github/workflows/validate.yaml`. To enable:

```bash
# Stage workflow file
git add .github/workflows/validate.yaml

# Commit
git commit -m "ci: add automated validation pipeline"

# Push to main branch
git push origin main
```

**Verification:**
- Go to Actions tab in GitHub repository
- You should see "Infrastructure Validation" workflow
- First run will execute on push to main

#### Step 4: Test Pipeline

Create a test pull request to verify pipeline:

```bash
# Create test branch
git checkout -b test-ci-pipeline

# Make trivial change (e.g., update README)
echo "Testing CI pipeline" >> README.md

# Commit and push
git add README.md
git commit -m "test: verify CI pipeline"
git push origin test-ci-pipeline
```

**Expected behavior:**
- Pipeline runs automatically on PR creation
- All jobs should pass (green checkmarks)
- PR shows status check results at bottom

---

## 4. Pipeline Jobs

### 4.1 Job: validate-syntax

**Purpose:** Fast syntax validation for all configuration types
**Execution Time:** 2-5 minutes
**Runs:** Always (no dependencies)

**Validation Steps:**

1. **Nix flake check**
   - Command: `nix flake check --print-build-logs`
   - Validates: All NixOS, Darwin, and Home Manager configurations evaluate
   - Fails if: Syntax errors, undefined variables, broken imports

2. **Terraform validate**
   - Command: `tofu init -backend=false && tofu validate`
   - Validates: HCL syntax, resource arguments, module sources
   - Fails if: Invalid HCL, missing required arguments, unknown resources

3. **Ansible syntax check**
   - Command: `ansible-playbook playbooks/*.yaml --syntax-check`
   - Validates: YAML syntax, task structure, module names
   - Fails if: YAML errors, invalid module names, missing parameters

**Why this job runs first:**
- Syntax errors block all downstream tests
- Fastest feedback (2-5 minutes vs 15-20 minutes for full suite)
- Prevents wasting CI resources on broken code

**Success criteria:**
- All three validation steps complete with exit code 0
- No syntax errors reported
- All configurations evaluate successfully

### 4.2 Job: validate-secrets (Optional)

**Purpose:** Validate SOPS-encrypted secrets against JSON schemas
**Execution Time:** 1-2 minutes
**Runs:** Only if `SOPS_AGE_KEY` secret is configured
**Dependencies:** None (runs in parallel with other jobs)

**Validation Steps:**

1. **Setup age key**
   - Writes `SOPS_AGE_KEY` to temporary file
   - Sets restrictive permissions (600)
   - Configures `SOPS_AGE_KEY_FILE` environment variable

2. **Validate secrets**
   - Command: `scripts/validate-secrets.sh`
   - Validates:
     - `secrets/users.yaml` (user password hashes)
     - `secrets/hetzner.yaml` (Hetzner API token)
     - `secrets/ssh-keys.yaml` (SSH keys)
     - `secrets/pgp-keys.yaml` (PGP keys)
   - Checks:
     - Secrets decrypt successfully
     - Secrets match JSON schema
     - No invalid/malformed data

**Security considerations:**
- Age key is stored in GitHub Secrets (encrypted at rest)
- Age key is written to temp file (not logged)
- Temp file is automatically deleted after job completes
- Decrypted secrets are never printed to logs

**Success criteria:**
- All secrets decrypt successfully
- All secrets pass schema validation
- No warnings or errors reported

**Skipping this job:**

If `SOPS_AGE_KEY` is not configured, this job is automatically skipped with message:

```
validate-secrets: Skipped (SOPS_AGE_KEY not configured)
```

This is **acceptable** for CI/CD environments where secrets validation is not required (e.g., public repositories, test fixtures only).

### 4.3 Job: test-nixos

**Purpose:** Validate NixOS system configurations in isolated VMs
**Execution Time:** 5-10 minutes (with caching), 10-15 minutes (cold cache)
**Runs:** After `validate-syntax` passes
**Dependencies:** `validate-syntax`

**Test Scenarios:**

1. **xmsi configuration test** (Desktop system)
   - Boots NixOS VM with xmsi configuration
   - Verifies:
     - System reaches multi-user target
     - User `mi-skam` exists with correct UID
     - Desktop environment (Plasma) starts
     - SSH daemon is running
     - Secrets decrypt successfully
   - Test file: `tests/nixos/xmsi-test.nix`

2. **srv-01 configuration test** (Server system)
   - Boots NixOS VM with srv-01 configuration
   - Verifies:
     - System reaches multi-user target
     - Users `mi-skam` and `plumps` exist
     - No desktop environment installed
     - SSH daemon is running
     - Network configuration is correct
   - Test file: `tests/nixos/srv-01-test.nix`

**VM Test Framework:**
- Uses NixOS `nixosTest` framework
- Runs in isolated QEMU VMs
- VMs have network access (for testing connectivity)
- VMs are destroyed after test completes

**Setup KVM:**

GitHub Actions runners support KVM virtualization. The pipeline configures KVM access:

```bash
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
```

This allows Nix to use hardware acceleration (faster VM boots).

**Success criteria:**
- Both VM tests complete without errors
- All verification checks pass
- Exit code 0 from `just test-nixos`

**Common failures:**
- VM fails to boot (systemd errors)
- User creation fails (secrets decryption issue)
- Service fails to start (configuration error)
- Test timeout (VM too slow or service hung)

### 4.4 Job: test-terraform

**Purpose:** Validate Terraform configurations without API calls
**Execution Time:** 10 seconds
**Runs:** After `validate-syntax` passes
**Dependencies:** `validate-syntax`

**Validation Steps:**

1. **Syntax validation**
   - Command: `tofu validate`
   - Already completed in `validate-syntax` job

2. **Plan validation**
   - Command: `tofu plan -backend=false`
   - Validates: Plan generation without state backend
   - Uses: Dummy tokens (no API calls)
   - Checks:
     - All resources can be planned
     - Dependencies are correctly defined
     - No circular dependencies

3. **Import script validation**
   - Validates: `terraform/import.sh` syntax
   - Checks: Import commands are syntactically correct

4. **Output validation**
   - Validates: Required outputs are defined in `outputs.tf`
   - Checks: Output references are valid

**Test script:**
- Command: `just test-terraform`
- Script: `terraform/run-tests.sh`
- Exit code: 0 if all tests pass, 1 if any fail

**Success criteria:**
- All validation steps complete successfully
- Plan generates without errors
- Import script is valid
- Outputs are correctly defined

**Common failures:**
- Invalid HCL syntax
- Missing required argument
- Invalid resource reference
- Import script syntax error

### 4.5 Job: test-ansible

**Purpose:** Validate Ansible roles in Docker containers
**Execution Time:** 10-15 minutes
**Runs:** After `validate-syntax` passes
**Dependencies:** `validate-syntax`

**Test Scenarios:**

1. **common role test**
   - Platforms: Debian 12, Ubuntu 24.04, Rocky Linux 9
   - Verifies:
     - Directories created (`/opt/scripts`, `/var/log/homelab`)
     - Packages installed (vim, htop, curl)
     - Bash aliases deployed (`~/.bash_aliases`)
   - Idempotency: Second run shows `changed=0`

2. **monitoring role test**
   - Platforms: Debian 12, Ubuntu 24.04, Rocky Linux 9
   - Verifies:
     - node_exporter installed and configured
     - Promtail installed and configured
     - Services are enabled
     - Metrics endpoint accessible
   - Idempotency: Second run shows `changed=0`

3. **backup role test**
   - Platforms: Debian 12, Ubuntu 24.04, Rocky Linux 9
   - Verifies:
     - restic installed
     - Backup scripts created (`/opt/scripts/backup.sh`)
     - Systemd timers configured
     - Cron jobs created (if applicable)
   - Idempotency: Second run shows `changed=0`

**Molecule Framework:**
- Driver: Docker (containers, not VMs)
- Provisioner: Ansible
- Verifier: Ansible (custom verification playbooks)

**Test Workflow (per role):**

1. **Create** - Spin up Docker containers
2. **Prepare** - Install dependencies (e.g., systemd, Python)
3. **Converge** - Apply role (first run)
4. **Converge (idempotency)** - Apply role again (second run)
5. **Verify** - Run verification tests
6. **Destroy** - Remove containers

**Setup Python venv:**

Molecule requires Python virtual environment:

```bash
python3 -m venv .venv
.venv/bin/pip install molecule molecule-docker ansible-core
```

Pipeline creates venv automatically if not present.

**Success criteria:**
- All three role tests pass
- Idempotency verified (changed=0 on second run)
- All verification checks pass
- Exit code 0 from `just test-ansible`

**Common failures:**
- Docker not running
- Container image pull failure
- Role application error
- Idempotency failure (task always shows changed)
- Verification test failure

### 4.6 Job: pipeline-summary

**Purpose:** Aggregate results and report overall pipeline status
**Execution Time:** 5 seconds
**Runs:** Always (even if previous jobs fail)
**Dependencies:** All test jobs

**Summary Report:**

```
════════════════════════════════════════
  CI/CD Pipeline Summary
════════════════════════════════════════

Syntax Validation: success
NixOS Tests:       success
Terraform Tests:   success
Ansible Tests:     success

✅ Pipeline PASSED
════════════════════════════════════════
```

**Exit code logic:**
- **Exit 0:** All jobs succeeded
- **Exit 1:** One or more jobs failed

**Why this job exists:**
- Provides single point of truth for pipeline status
- Allows downstream automation (e.g., auto-merge on success)
- Clear summary in Actions UI

---

## 5. Interpreting Results

### 5.1 GitHub Actions UI

**Accessing Pipeline Results:**

1. Navigate to repository → Actions tab
2. Click on "Infrastructure Validation" workflow
3. Click on specific run (identified by commit SHA or PR number)

**Job Status Indicators:**

| Icon | Status | Meaning |
|------|--------|---------|
| 🟢 (checkmark) | Success | Job completed without errors |
| 🔴 (X) | Failure | Job failed (exit code non-zero) |
| 🟡 (circle) | In Progress | Job is currently running |
| ⚪ (circle) | Pending | Job waiting for dependencies |
| ⚫ (circle) | Skipped | Job skipped (condition not met) |

### 5.2 Pull Request Status Checks

**Location:** PR page → "Checks" tab or bottom of "Conversation" tab

**Status Check Names:**
- `validate-syntax` - Syntax validation
- `validate-secrets` - Secrets validation (if configured)
- `test-nixos` - NixOS VM tests
- `test-terraform` - Terraform validation
- `test-ansible` - Ansible Molecule tests
- `pipeline-summary` - Overall pipeline status

**Required Status Checks:**

Configure branch protection to require:
- `validate-syntax` (blocking)
- `test-nixos` (blocking)
- `test-terraform` (blocking)
- `test-ansible` (blocking)

**Merge Restrictions:**

If branch protection is enabled:
- ✅ All required checks pass → Merge button enabled
- ❌ Any required check fails → Merge button disabled

### 5.3 Reading Job Logs

**Viewing Job Logs:**

1. Click on job name in Actions UI
2. Expand step to see detailed logs
3. Use search (Ctrl+F) to find specific errors

**Log Sections:**

```
Set up job (automatic - GitHub Actions setup)
  ├─ Runner environment info
  ├─ Job dependencies
  └─ Checkout repository

Checkout repository (step 1)
  └─ Git clone output

Install Nix (step 2)
  ├─ Nix installation progress
  └─ Version info

Configure Nix caching (step 3)
  ├─ Cachix setup
  └─ Cache hit/miss info

Validate Nix syntax (step 4)
  ├─ nix flake check output
  ├─ Evaluation results
  └─ Error messages (if any)

...

Post job cleanup (automatic)
  └─ Cleanup actions
```

**Log Formatting:**

- **Green text** - Success messages
- **Red text** - Error messages
- **Yellow text** - Warnings
- **Gray text** - Informational messages

### 5.4 Common Error Patterns

**Nix flake check errors:**

```
error: undefined variable 'pkgs'
  at /path/to/module.nix:42:5
```

**Cause:** Variable not in scope
**Solution:** Import nixpkgs or accept pkgs parameter

---

**Terraform validate errors:**

```
Error: Invalid HCL syntax
  on servers.tf line 15, in resource "hcloud_server" "mail-1":
  15:   server_type = CAX21
```

**Cause:** Missing quotes around string value
**Solution:** Change to `server_type = "CAX21"`

---

**Ansible syntax errors:**

```
ERROR! Syntax Error while loading YAML.
  found unexpected ':'
The error appears to be in '/path/to/playbook.yaml': line 23, column 5
```

**Cause:** YAML indentation error
**Solution:** Fix indentation (use 2 spaces, no tabs)

---

**Ansible idempotency failure:**

```
PLAY RECAP *************************************************************
debian-12 : ok=10 changed=2 unreachable=0 failed=0

Idempotency test failed (expected changed=0, got changed=2)
```

**Cause:** Task always reports changed
**Solution:** Add `changed_when` condition to task

---

## 6. Debugging Failures

### 6.1 Debugging Workflow

```
Pipeline fails
    │
    ▼
Identify which job failed
    │
    ├─ validate-syntax → Fix syntax errors
    ├─ test-nixos → Debug VM test failure
    ├─ test-terraform → Debug Terraform validation
    └─ test-ansible → Debug Molecule test failure
    │
    ▼
Review job logs
    │
    ├─ Find error message (red text)
    ├─ Note line number and file
    └─ Copy error message
    │
    ▼
Reproduce locally
    │
    ├─ Run same command locally
    ├─ Verify error reproduces
    └─ Debug with additional flags
    │
    ▼
Fix issue
    │
    ├─ Update code
    ├─ Test fix locally
    └─ Commit and push
    │
    ▼
Verify fix in CI
    │
    ├─ Wait for pipeline to run
    ├─ Check all jobs pass
    └─ Merge PR
```

### 6.2 Reproducing Failures Locally

**Step 1: Replicate CI environment**

```bash
# Enter Nix devshell (same as CI)
nix develop

# Verify tools available
nix --version
tofu version
ansible --version
just --version
```

**Step 2: Run failed command**

**Example: Syntax validation failure**

```bash
# Run exact command from CI logs
nix flake check --print-build-logs

# If fails, add verbose flag
nix flake check --print-build-logs --show-trace
```

**Example: NixOS test failure**

```bash
# Run specific test that failed
nix build .#checks.x86_64-linux.xmsi-test --print-build-logs

# View detailed VM logs
nix build .#checks.x86_64-linux.xmsi-test --print-build-logs --show-trace
```

**Example: Ansible test failure**

```bash
# Run specific Molecule scenario
cd ansible
molecule test -s common --debug

# Or run individual steps
molecule create -s common
molecule converge -s common
molecule verify -s common
```

**Step 3: Compare local vs CI results**

| Aspect | Local | CI |
|--------|-------|-----|
| Nix version | `nix --version` | Check "Install Nix" step |
| System architecture | `uname -m` | Always `x86_64` (GitHub runners) |
| Git state | May have uncommitted changes | Only sees committed files |
| Secrets | Local age key | CI age key (if configured) |

**Common discrepancies:**
- Local has uncommitted files (Nix flakes require `git add`)
- Local uses different Nix version
- Local has cached build artifacts (CI always starts fresh)

### 6.3 Advanced Debugging

**Enable debug logging:**

Add to workflow file (temporarily):

```yaml
- name: Enable debug logging
  run: |
    echo "ACTIONS_STEP_DEBUG=true" >> $GITHUB_ENV
    echo "ACTIONS_RUNNER_DEBUG=true" >> $GITHUB_ENV
```

**View runner system info:**

```yaml
- name: Debug runner environment
  run: |
    echo "OS: $(uname -a)"
    echo "CPU: $(nproc) cores"
    echo "Memory: $(free -h)"
    echo "Disk: $(df -h)"
    nix-shell -p neofetch --run neofetch
```

**Test with different Nix versions:**

```yaml
- name: Install Nix
  uses: cachix/install-nix-action@v27
  with:
    nix_path: nixpkgs=channel:nixos-unstable  # Use unstable
```

**Skip specific jobs for debugging:**

Add to workflow file:

```yaml
test-nixos:
  if: false  # Skip this job
```

### 6.4 Getting Help

**Resources:**

1. **Testing Strategy Document**
   - File: `docs/testing_strategy.md`
   - Contains: Comprehensive testing approach, troubleshooting guide

2. **GitHub Actions Logs**
   - Location: Actions tab → Workflow run → Job → Step logs
   - Contains: Detailed command output, error messages

3. **Local Reproduction**
   - Command: `just test-all` (runs all tests locally)
   - Verifies: Issue exists locally or is CI-specific

4. **Project Documentation**
   - File: `CLAUDE.md`
   - Contains: Architecture overview, coding standards

**Requesting Support:**

When opening an issue, include:

1. **Link to failed workflow run**
   - Example: `https://github.com/USER/REPO/actions/runs/1234567890`

2. **Error message** (copy from logs)
   ```
   error: undefined variable 'pkgs'
     at /nix/store/.../module.nix:42:5
   ```

3. **Steps to reproduce locally**
   ```bash
   nix develop
   nix flake check
   # Error: ...
   ```

4. **Expected vs actual behavior**
   - Expected: nix flake check passes
   - Actual: Error about undefined variable

---

## 7. Branch Protection

### 7.1 Configuring Branch Protection

**Purpose:** Prevent merging broken code to main branch

**Setup Steps:**

1. Navigate to Settings → Branches
2. Click "Add branch protection rule"
3. Configure rule:
   - **Branch name pattern:** `main`
   - **Require status checks to pass before merging:** ✅ Enabled
   - **Status checks that are required:**
     - `validate-syntax`
     - `test-nixos`
     - `test-terraform`
     - `test-ansible`
   - **Require branches to be up to date before merging:** ✅ Enabled
   - **Do not allow bypassing the above settings:** ✅ Enabled
4. Save changes

**Effect:**
- PRs cannot be merged until all required checks pass
- "Merge" button is disabled if any check fails
- Branch must be up-to-date with main before merge

### 7.2 Required vs Optional Checks

**Required Checks (block merge):**
- `validate-syntax` - Critical, blocks all other tests
- `test-nixos` - Critical, validates system configurations
- `test-terraform` - Critical, validates infrastructure
- `test-ansible` - Critical, validates automation

**Optional Checks (informational only):**
- `validate-secrets` - Optional (only runs if SOPS_AGE_KEY configured)
- `pipeline-summary` - Informational (aggregates results)

**Why separate optional checks:**
- Secrets validation requires SOPS_AGE_KEY secret
- Not all repositories have this configured
- Test fixtures allow builds without production secrets

### 7.3 Bypassing Checks (Emergency)

**When to bypass:**
- Critical security patch
- Production incident requires immediate fix
- CI/CD infrastructure outage

**How to bypass:**

1. **Temporary bypass** (single PR):
   - Repository admin can override branch protection
   - Click "Merge without waiting for requirements to be met"
   - **⚠️ Use with extreme caution**

2. **Permanent bypass** (not recommended):
   - Remove branch protection rule
   - Merge PR
   - Re-enable branch protection
   - **⚠️ Creates security vulnerability window**

**Best practice:**
- Never bypass checks unless absolutely necessary
- Document reason for bypass in PR comment
- Fix underlying issue immediately after merge
- Re-run tests manually post-merge to verify

---

## 8. Performance Optimization

### 8.1 Current Performance

**Baseline (cold cache):**
- validate-syntax: 5 minutes
- test-nixos: 15 minutes
- test-terraform: 10 seconds
- test-ansible: 15 minutes
- **Total (parallel):** ~20 minutes

**Target (with optimizations):**
- validate-syntax: 2 minutes
- test-nixos: 8 minutes
- test-terraform: 10 seconds
- test-ansible: 10 minutes
- **Total (parallel):** <15 minutes

### 8.2 Caching Strategy

**Nix Binary Cache (cachix):**

**Setup:**
```yaml
- name: Configure Nix caching
  uses: cachix/cachix-action@v15
  with:
    name: nix-community
    authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
    skipPush: true  # Read-only (no write access needed)
```

**Benefits:**
- Pre-built packages downloaded instead of built
- Reduces build time from 15 min → 5 min
- Shared across all workflow runs

**Cache locations:**
- https://cache.nixos.org (official NixOS cache)
- https://nix-community.cachix.org (community cache)

**GitHub Actions Cache:**

Not currently implemented (future enhancement):

```yaml
- name: Cache Nix store
  uses: actions/cache@v4
  with:
    path: /nix/store
    key: ${{ runner.os }}-nix-${{ hashFiles('flake.lock') }}
```

**Docker Image Cache:**

Molecule pulls Docker images (Debian, Ubuntu, Rocky). Future enhancement:

```yaml
- name: Cache Docker images
  run: |
    docker pull debian:12
    docker pull ubuntu:24.04
    docker pull rockylinux:9
```

### 8.3 Parallel Execution

**Current parallelization:**

Jobs run in parallel after `validate-syntax`:
- test-nixos
- test-terraform
- test-ansible
- validate-secrets (if configured)

**Why this improves performance:**

Sequential execution:
```
validate-syntax (5 min)
  → test-nixos (15 min)
    → test-terraform (10 sec)
      → test-ansible (15 min)
Total: 35 minutes
```

Parallel execution:
```
validate-syntax (5 min)
  → test-nixos (15 min)    ┐
  → test-terraform (10 sec)├─ All run simultaneously
  → test-ansible (15 min)  ┘
Total: 20 minutes (limited by slowest job)
```

**Matrix strategy (future enhancement):**

Run tests across multiple platforms:

```yaml
test-nixos:
  strategy:
    matrix:
      config: [xmsi, srv-01]
  steps:
    - run: nix build .#checks.x86_64-linux.${{ matrix.config }}-test
```

Benefit: Both tests run in parallel (~8 min instead of ~15 min)

### 8.4 Timeout Configuration

**Current timeouts:**
- validate-syntax: 10 minutes
- test-nixos: 15 minutes
- test-terraform: 5 minutes
- test-ansible: 20 minutes
- pipeline-summary: 5 minutes

**Why timeouts matter:**
- Prevent hung jobs from blocking pipeline indefinitely
- Free up CI runners for other workflows
- Fail fast on configuration errors

**Adjusting timeouts:**

```yaml
test-nixos:
  timeout-minutes: 20  # Increase if tests legitimately take longer
```

---

## 9. Troubleshooting

### 9.1 Common Issues

**Issue: Pipeline doesn't trigger on PR**

**Symptoms:**
- PR created, but no status checks appear
- Actions tab shows no workflow runs

**Causes:**
1. Workflow file not committed to main branch
2. GitHub Actions disabled in repository settings
3. Workflow file has syntax errors

**Solutions:**
1. Verify workflow file exists on main branch:
   ```bash
   git checkout main
   ls .github/workflows/validate.yaml
   ```
2. Check Actions are enabled (Settings → Actions → General)
3. Validate workflow syntax:
   ```bash
   # Use GitHub's workflow validator
   # https://rhysd.github.io/actionlint/
   ```

---

**Issue: Job fails with "Permission denied"**

**Symptoms:**
```
Error: EACCES: permission denied, open '/tmp/file'
```

**Causes:**
- File permissions incorrect
- Writing to restricted directory

**Solutions:**
```yaml
- name: Fix permissions
  run: chmod +x scripts/validate-secrets.sh
```

---

**Issue: Secrets validation fails with "key not found"**

**Symptoms:**
```
Error: SOPS age key not found
```

**Causes:**
1. `SOPS_AGE_KEY` not configured in GitHub Secrets
2. Age key format incorrect (missing header/footer)
3. Age key is for different secrets files

**Solutions:**
1. Verify secret is configured (Settings → Secrets)
2. Check age key format:
   ```
   # Valid age key format
   AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```
3. Test decryption locally:
   ```bash
   export SOPS_AGE_KEY_FILE=/tmp/keys.txt
   echo "$SOPS_AGE_KEY" > /tmp/keys.txt
   sops -d secrets/users.yaml
   ```

---

**Issue: NixOS VM tests timeout**

**Symptoms:**
```
error: timeout waiting for machine to start
```

**Causes:**
1. VM boot is slow (no KVM acceleration)
2. Service takes too long to start
3. Test script waits indefinitely

**Solutions:**
1. Verify KVM is configured (check "Setup KVM" step logs)
2. Increase timeout in test script:
   ```nix
   machine.wait_for_unit("sshd.service", timeout=120)
   ```
3. Debug VM boot:
   ```bash
   nix build .#checks.x86_64-linux.xmsi-test --print-build-logs --show-trace
   ```

---

**Issue: Ansible Molecule fails with "docker: command not found"**

**Symptoms:**
```
Error: docker: command not found
```

**Causes:**
- Docker not available on runner
- Docker not in PATH

**Solutions:**
GitHub Actions runners have Docker pre-installed. If error persists:

```yaml
- name: Verify Docker
  run: |
    which docker
    docker --version
    docker info
```

---

**Issue: Pipeline completes but "Merge" button still disabled**

**Symptoms:**
- All checks green
- Merge button grayed out

**Causes:**
1. Branch not up-to-date with main
2. Additional required checks configured
3. Branch protection requires admin approval

**Solutions:**
1. Update branch:
   ```bash
   git checkout feature-branch
   git merge main
   git push
   ```
2. Check branch protection settings (Settings → Branches)
3. Request admin review if required

### 9.2 Performance Issues

**Issue: Pipeline takes >30 minutes**

**Causes:**
1. No Nix binary cache configured
2. Cold Docker image cache
3. Slow GitHub Actions runners

**Solutions:**
1. Configure cachix (see Section 3.2)
2. Pre-pull Docker images (see Section 8.2)
3. Contact GitHub support for runner performance issues

---

**Issue: Nix builds always rebuild (no cache hits)**

**Causes:**
1. `flake.lock` changes on every run
2. Cache key doesn't match
3. Cachix auth token invalid

**Solutions:**
1. Commit `flake.lock` to repository
2. Verify cache configuration:
   ```yaml
   - name: Check cache hits
     run: |
       echo "Cache hit: ${{ steps.cache.outputs.cache-hit }}"
   ```
3. Test cachix auth token locally:
   ```bash
   cachix authtoken $CACHIX_AUTH_TOKEN
   cachix use nix-community
   ```

### 9.3 Debugging Checklist

When pipeline fails:

- [ ] Identify which job failed
- [ ] Review job logs (expand all steps)
- [ ] Copy error message
- [ ] Reproduce locally (`nix develop` → run command)
- [ ] Verify file is git-tracked (`git status`)
- [ ] Check for uncommitted changes
- [ ] Test fix locally before pushing
- [ ] Review related documentation
- [ ] Search GitHub Actions logs for similar errors
- [ ] Open issue if problem persists

---

## 10. Maintenance

### 10.1 Regular Maintenance Tasks

**Weekly:**
- [ ] Review failed pipeline runs
- [ ] Update flake inputs if security patches available
- [ ] Check cachix cache hit rate

**Monthly:**
- [ ] Review pipeline performance metrics
- [ ] Update workflow dependencies (actions versions)
- [ ] Audit SOPS_AGE_KEY access logs
- [ ] Clean up old workflow runs (Settings → Actions → General)

**Quarterly:**
- [ ] Review and update timeout values
- [ ] Benchmark pipeline performance
- [ ] Update documentation for new features
- [ ] Rotate SOPS_AGE_KEY (security best practice)

### 10.2 Updating Dependencies

**Nix version:**

Update in workflow file:

```yaml
- name: Install Nix
  uses: cachix/install-nix-action@v27  # Update version here
  with:
    nix_path: nixpkgs=channel:nixos-24.11  # Update channel here
```

**GitHub Actions:**

Update action versions:

```yaml
- uses: actions/checkout@v4  # Check for v5
- uses: cachix/install-nix-action@v27  # Check for v28
- uses: cachix/cachix-action@v15  # Check for v16
```

**Flake inputs:**

Update Nix dependencies:

```bash
nix flake update
git add flake.lock
git commit -m "chore: update flake inputs"
git push
```

Pipeline will run on push to verify updates don't break builds.

### 10.3 Monitoring Pipeline Health

**Metrics to track:**

1. **Success rate**
   - Target: >95% (excluding legitimate failures)
   - Measure: (successful runs) / (total runs)

2. **Average execution time**
   - Target: <15 minutes with caching
   - Measure: Median time from start to completion

3. **Cache hit rate**
   - Target: >80% (after first run)
   - Measure: (cache hits) / (total cache checks)

4. **Failure categories**
   - Syntax errors (developer error)
   - Test failures (code regression)
   - Infrastructure failures (CI/CD platform issue)

**Viewing metrics:**

GitHub provides basic metrics:
- Actions tab → Workflows → Infrastructure Validation → Insights (if available)

For advanced metrics, use GitHub Actions API:
```bash
gh api repos/OWNER/REPO/actions/workflows/validate.yaml/runs \
  --jq '.workflow_runs[] | {conclusion, run_started_at, updated_at}'
```

### 10.4 Security Maintenance

**SOPS age key rotation:**

Every 90 days (recommended):

1. Generate new age key:
   ```bash
   age-keygen -o /tmp/new-ci-key.txt
   ```

2. Re-encrypt secrets with new key:
   ```bash
   # Add new key to .sops.yaml
   # Re-encrypt all secrets
   for secret in secrets/*.yaml; do
     sops updatekeys "$secret"
   done
   ```

3. Update GitHub Secret:
   - Settings → Secrets → SOPS_AGE_KEY → Update

4. Test pipeline with new key

5. Remove old key from .sops.yaml

**Audit access logs:**

Regularly review who has access to:
- GitHub repository (Settings → Collaborators)
- GitHub Secrets (Settings → Secrets)
- Workflow modification rights (branch protection)

**Security best practices:**
- ✅ Use read-only tokens (cachix)
- ✅ Rotate secrets regularly (SOPS_AGE_KEY)
- ✅ Limit workflow permissions (minimum required)
- ✅ Enable branch protection (prevent bypasses)
- ❌ Never commit secrets to workflow files
- ❌ Never print secrets in logs

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-01 | Initial CI/CD setup documentation |

---

**End of CI/CD Setup Documentation**
