# Infrastructure Refactoring Baseline Report

**Document Version:** 1.0
**Report Date:** 2025-10-28
**Purpose:** Establish comprehensive baseline snapshot before Iteration 2+ refactoring
**Scope:** Complete infrastructure inventory, code metrics, gaps, and refactoring opportunities

---

## Executive Summary

This baseline report documents the current state of the infrastructure management system before refactoring begins. The project manages a heterogeneous infrastructure using specialized tools: Nix Flakes for local systems, OpenTofu for Hetzner Cloud provisioning, and Ansible for traditional VPS configuration.

### Key Findings

**Infrastructure Maturity:**
- **6 managed systems** across 3 environments (local, Hetzner Cloud production, Hetzner Cloud dev)
- **1,810 total lines of infrastructure code** across 4 technology stacks
- **18% code duplication rate** in Nix modules (160 duplicated lines)
- **0% Ansible role completeness** against Galaxy standards
- **8x critical duplication** in justfile SOPS token extraction

**Critical Gaps Identified:**
1. **No monitoring stack** - zero observability for production services
2. **No automated backups** - manual mailcow-backup.yaml exists but requires manual execution
3. **No CI/CD pipeline** - all deployments are manual, no automated validation
4. **No automated testing** - zero test coverage for configurations
5. **No drift detection** - infrastructure state inconsistencies not monitored

**Refactoring Opportunity Quantification:**
- **Nix modules:** 20 modules, 973 lines, 4 high-impact shared library opportunities
- **Ansible roles:** 3 roles, 0% Galaxy-compliant, 75 lines to extract from playbooks
- **Justfile:** 27 recipes, 230 lines, 8 consolidation opportunities
- **Terraform:** 6 files, 250 lines, well-structured (no major refactoring needed)

**Post-Refactoring Targets:**
- Reduce code duplication to <5% across all components
- Achieve 100% Ansible Galaxy compliance (5 roles with complete structure)
- Implement monitoring for all 6 production/dev systems
- Add automated backups for 2 stateful services (mail-1, syncthing-1)
- Establish CI/CD pipeline with pre-deployment validation

---

## 1. System Inventory

### 1.1 Managed Systems Overview

| System Name | Environment | OS | Architecture | Instance Type | Management |
|-------------|-------------|----|--------------|--------------|-----------|
| **xbook** | Local | macOS (Darwin) | ARM64 | MacBook | Nix Darwin + Home Manager |
| **xmsi** | Local | NixOS | x86_64 | Desktop workstation | NixOS + Home Manager |
| **srv-01** | Local | NixOS | x86_64 | Server | NixOS + Home Manager (config only) |
| **mail-1.prod.nbg** | Production | Debian 12 | ARM64 | CAX21 (4 cores, 8GB) | OpenTofu + Ansible |
| **syncthing-1.prod.hel** | Production | Rocky Linux 9 | ARM64 | CAX11 (2 cores, 4GB) | OpenTofu + Ansible |
| **test-1.dev.nbg** | Development | Ubuntu 24.04 | ARM64 | CAX11 (2 cores, 4GB) | OpenTofu + Ansible |

**Total Systems:** 6 (3 local, 2 production, 1 development)

### 1.2 Software Versions

**Nix Ecosystem:**
- nixpkgs: 25.05 (stable)
- nixpkgs-unstable: latest
- home-manager: release-25.05
- nix-darwin: nix-darwin-25.05
- sops-nix: latest (follows nixpkgs)

**Infrastructure Tools:**
- OpenTofu: version managed via devshell
- Ansible: version managed via devshell
- justfile: 230 lines, 27 recipes

**Hetzner Cloud Resources:**
- Private network: `homelab` (10.0.0.0/16)
- Subnet: 10.0.0.0/24 (eu-central)
- SSH key: `homelab-hetzner`

### 1.3 Service Distribution

**Stateful Services (Backup Required):**
- mail-1.prod.nbg: Mail server (mailcow)
- syncthing-1.prod.hel: File synchronization

**Stateless Services:**
- test-1.dev.nbg: Test environment
- xbook, xmsi, srv-01: Development/workstation systems

---

## 2. Code Metrics

### 2.1 Total Lines of Code by Component

| Component | Files | Lines | Purpose | Status |
|-----------|-------|-------|---------|--------|
| **Nix Modules** | 20 | 973 | NixOS/Darwin/Home Manager configurations | 18% duplication |
| **Ansible** | 12 | 357 | VPS configuration management | 0% Galaxy compliance |
| **Terraform** | 6 | 250 | Hetzner Cloud infrastructure | Well-structured |
| **Justfile** | 1 | 230 | Task automation and orchestration | 8x SOPS duplication |
| **Total** | **39** | **1,810** | Complete infrastructure codebase | Multiple improvement opportunities |

### 2.2 Nix Module Breakdown

**By Category:**
- NixOS System Modules: 172 lines (6 modules)
- Darwin System Modules: 137 lines (3 modules)
- Home Manager Modules: 565 lines (9 modules)
- Home Manager User Configs: 34 lines (2 modules)
- System User Configs: 87 lines (2 modules)

**Largest Modules (Refactoring Targets):**
1. `modules/home/common.nix` - 264 lines (contains neovim ~60 lines, starship ~35 lines)
2. `modules/home/dev.nix` - 101 lines
3. `modules/darwin/desktop.nix` - 81 lines
4. `modules/nixos/common.nix` - 57 lines
5. `modules/home/ssh.nix` - 52 lines

**Module Size Distribution:**
- Small (<20 lines): 7 modules (35%)
- Medium (20-60 lines): 10 modules (50%)
- Large (60-100 lines): 2 modules (10%)
- Very Large (100+ lines): 1 module (5%)

**Duplication Metrics:**
- Total Duplicated Lines: ~160 lines (18% of codebase)
- User account structure: 80 lines (50% of duplication)
- System common settings: 30-40 lines (25% of duplication)
- Platform detection let bindings: 18 lines (11% of duplication)

### 2.3 Ansible Code Breakdown

**By Type:**
- Roles: 3 (common, monitoring, storagebox)
- Role tasks: 67 lines
- Playbooks: 4 (bootstrap.yaml, deploy.yaml, setup-storagebox.yaml, mailcow-backup.yaml)
- Playbook tasks: ~200 lines
- Inventory/vars: ~90 lines

**Role Maturity Matrix:**

| Role | Tasks | Handlers | Templates | Defaults | Meta | README | Completeness |
|------|-------|----------|-----------|----------|------|--------|--------------|
| common | 37 lines | Empty dir | Empty dir | ❌ | ❌ | ❌ | 30% |
| monitoring | Empty | Empty | ❌ | ❌ | ❌ | ❌ | 5% |
| storagebox | 30 lines | 4 lines | ✓ | 12 lines | ❌ | ❌ | 60% |

**Critical Gap:** Bootstrap playbook contains ~75 lines of role-worthy logic that should be extracted.

### 2.4 Terraform Code Distribution

| File | Lines | Purpose |
|------|-------|---------|
| providers.tf | ~40 | Provider configuration (hcloud, sops) |
| variables.tf | ~30 | Variable definitions |
| network.tf | ~50 | Network, subnet, SSH key resources |
| servers.tf | ~80 | Server definitions (mail-1, syncthing-1, test-1) |
| outputs.tf | ~30 | Server IPs and network info |
| ssh_keys.tf | ~20 | SSH key management |
| **Total** | **250** | Complete Hetzner infrastructure |

**Assessment:** Terraform code is well-structured with no major refactoring needed.

### 2.5 Justfile Metrics

**Recipe Distribution:**
- Terraform/OpenTofu recipes: 9 (33%)
- Ansible recipes: 6 (22%)
- Dotfiles recipes: 11 (41%)
- Utility recipes: 1 (4%)

**Total:** 27 recipes, 230 lines

**Code Quality Issues:**
- SOPS token extraction duplicated 8 times
- Unused `hcloud_token` variable (line 7)
- Pattern inconsistency: `hcloud_token` vs `hcloud:` grep patterns
- Zero pre-flight validations
- Minimal error handling (3/27 recipes)

---

## 3. Secrets Inventory

### 3.1 Secret Files

| File | Purpose | Format | Status |
|------|---------|--------|--------|
| `secrets/hetzner.yaml` | Hetzner Cloud API token | SOPS-encrypted YAML | Active |
| `secrets/storagebox.yaml` | Storage Box credentials | SOPS-encrypted YAML | Active |
| `secrets/authorized_keys` | SSH public keys | Plain text | Active |

**Total Secret Files:** 3

### 3.2 Secrets by Category

**API Tokens:**
- Hetzner Cloud API token (OpenTofu provisioning)

**Storage Credentials:**
- Storage Box username, password, host

**SSH Keys:**
- Authorized public keys for all systems

**User Secrets (referenced but not in secrets/):**
- User passwords (managed by SOPS in separate files)
- PGP keys (mentioned in CLAUDE.md but file not present)

### 3.3 Secret Management Assessment

**Strengths:**
- ✓ SOPS with age encryption properly configured
- ✓ Secrets never committed to git
- ✓ SOPS integration in Nix, Terraform, and Ansible

**Gaps (to be addressed in Iteration 2):**
- ❌ No secrets rotation procedures documented
- ❌ No automated validation of age key bootstrap
- ❌ Missing documentation for adding new secrets
- ❌ No backup/recovery procedures for age private key

---

## 4. Operational Procedures

### 4.1 Manual Operational Procedures

**NixOS System Management:**
```bash
# Build and activate NixOS configuration
sudo nixos-rebuild switch --flake .#xmsi

# Test configuration without activating
sudo nixos-rebuild build --flake .#xmsi
```

**Darwin System Management:**
```bash
# Build and activate Darwin configuration
darwin-rebuild switch --flake .#xbook

# Test configuration without activating
nix build .#darwinConfigurations.xbook.system
```

**Home Manager Configuration:**
```bash
# Deploy user environment
home-manager switch --flake .#mi-skam@xmsi
home-manager switch --flake .#plumps@xbook

# Test without activating
home-manager build --flake .#user@host
```

**Terraform Infrastructure Management:**
```bash
# Initialize Terraform
just tf-init

# Preview infrastructure changes
just tf-plan

# Apply infrastructure changes
just tf-apply

# Import existing resources
just tf-import

# Show outputs (server IPs)
just tf-output
```

**Ansible Configuration Management:**
```bash
# Test connectivity
just ansible-ping

# Bootstrap new servers (initial setup)
just ansible-bootstrap

# Deploy configurations
just ansible-deploy

# Deploy to specific environment
just ansible-deploy-env prod
just ansible-deploy-env dev

# List managed servers
just ansible-inventory
```

**Secret Management:**
```bash
# Edit encrypted secrets
sops secrets/hetzner.yaml
sops secrets/storagebox.yaml

# View decrypted secrets
sops -d secrets/users.yaml
```

**Flake Management:**
```bash
# Update all flake inputs
nix flake update

# Validate flake configuration
nix flake check
```

### 4.2 Deployment Workflow

**Current Workflow for System Changes:**
1. Edit configuration files
2. Stage changes with `git add` (critical for Nix flakes!)
3. Run appropriate rebuild command
4. Manually verify changes
5. Commit to git

**Current Workflow for Infrastructure Changes:**
1. Edit Terraform files
2. Run `just tf-plan` to preview changes
3. Manually review plan output
4. Run `just tf-apply` to apply changes
5. Manually verify infrastructure state
6. Update Ansible inventory with `just ansible-inventory-update`

**Current Workflow for VPS Configuration:**
1. Edit Ansible playbooks/roles
2. Run `ansible-playbook playbooks/deploy.yaml --check` for dry run
3. Run `just ansible-deploy` to apply changes
4. Manually verify service status

### 4.3 Gaps in Operational Procedures

**No Automated Testing:**
- No pre-deployment validation for Nix configurations
- No automated testing of Ansible playbooks
- No integration tests for complete deployment workflow

**No Rollback Procedures:**
- NixOS has built-in rollback via generations (not documented)
- Terraform rollback requires manual state manipulation
- Ansible rollback requires manual intervention
- No documented recovery procedures

**No Health Checks:**
- No automated verification after deployments
- No monitoring of deployment success/failure
- No alerting on configuration drift

---

## 5. Gap Analysis

### 5.1 Monitoring Stack (Critical Gap)

**Current State:** Zero monitoring infrastructure

**Requirements (from project objectives):**
- Secondary Objective: "Observability Baseline - Establish monitoring and logging infrastructure for production services"
- NFR: Reliability & Availability requirements imply need for monitoring

**Impact:**
- No visibility into service health (mail-1, syncthing-1)
- No alerting on failures or performance degradation
- No historical metrics for capacity planning
- Cannot detect configuration drift or unauthorized changes

**Recommended Solution (Iteration 5+):**
- Implement Prometheus + Grafana stack
- Deploy node_exporter on all managed hosts
- Add Ansible monitoring role (skeleton exists, needs implementation)
- Create alerting rules for critical services
- Implement log aggregation

**Effort Estimate:** Medium (1-2 weeks)

### 5.2 Automated Backups (Critical Gap)

**Current State:** Manual backup playbook exists but requires manual execution

**Evidence:**
- `ansible/playbooks/mailcow-backup.yaml` exists (59 lines)
- Runs mailcow backup script to Storage Box
- Must be executed manually: no cron, no automation

**Requirements (from project objectives):**
- Secondary Objective: "Data Protection - Implement automated backup strategies for stateful services"
- Services requiring backup: mail-1 (mailcow), syncthing-1 (file sync data)

**Impact:**
- Risk of data loss if manual backups forgotten
- No backup verification or testing
- No retention policy enforcement
- Recovery procedures not documented or tested

**Recommended Solution (Iteration 5+):**
- Add cron job for mailcow-backup.yaml (daily at 2 AM)
- Create backup verification playbook
- Implement backup retention policy (30 days)
- Add Syncthing data backup
- Document and test disaster recovery procedures

**Effort Estimate:** Medium (1 week)

### 5.3 CI/CD Pipeline (High-Priority Gap)

**Current State:** All deployments are manual, no automated validation

**Requirements (from project objectives):**
- Secondary Objective: "CI/CD Integration - Add automated configuration validation pipelines"
- NFR: Configuration Validation - "All configuration changes must be validated before application"

**Impact:**
- No automated testing of configuration changes
- Risk of deploying broken configurations
- No enforcement of code quality standards
- Cannot prevent regressions

**Recommended Solution (Iteration 6+):**
- Add GitHub Actions workflows
- Automated Nix flake checks on PR
- Ansible lint validation
- Terraform plan validation (without apply)
- Pre-commit hooks for secret scanning

**Effort Estimate:** Medium-High (1-2 weeks)

### 5.4 Testing Infrastructure (High-Priority Gap)

**Current State:** Zero test coverage across all components

**Requirements (from project objectives):**
- NFR: Configuration Validation requirement
- Primary Objective: "Infrastructure Reliability - Add automated testing for configurations"

**Impact:**
- No regression detection
- Cannot verify idempotency of Ansible playbooks
- No validation of cross-platform compatibility (NixOS/Darwin/Debian/Rocky/Ubuntu)

**Recommended Solution (Iteration 6+):**
- Add NixOS VM tests for system configurations
- Implement Molecule tests for Ansible roles
- Add integration tests for complete deployment workflows
- Test Terraform plans with terratest or similar

**Effort Estimate:** High (2-3 weeks)

### 5.5 Drift Detection (Medium-Priority Gap)

**Current State:** No automated detection of infrastructure state inconsistencies

**Requirements (from project objectives):**
- Primary Objective: "Infrastructure Reliability - Implement infrastructure drift detection"
- NFR: State Consistency - "Infrastructure state must remain consistent"

**Impact:**
- Manual changes to servers not detected
- Terraform state may diverge from actual infrastructure
- Ansible facts may become stale
- Cannot ensure compliance with desired state

**Recommended Solution (Iteration 7+):**
- Add periodic `terraform plan` execution with diff reporting
- Implement Ansible fact caching and staleness detection
- Add scheduled `ansible-playbook --check` runs
- Alert on detected drift

**Effort Estimate:** Medium (1-2 weeks)

### 5.6 Gap Summary Table

| Gap | Priority | Iteration | Effort | Blocking Factor |
|-----|----------|-----------|--------|-----------------|
| No monitoring stack | Critical | I5+ | Medium | None |
| No automated backups | Critical | I5+ | Medium | Storage Box already configured |
| No CI/CD pipeline | High | I6+ | Medium-High | Need refactoring complete first |
| No automated testing | High | I6+ | High | Need refactoring complete first |
| No drift detection | Medium | I7+ | Medium | Need monitoring first |

---

## 6. Refactoring Opportunities

This section synthesizes findings from the three completed analyses (I1.T4, I1.T5, I1.T6).

### 6.1 Nix Module Refactoring Opportunities

**Source:** `docs/refactoring/nix_module_analysis.md`

**Key Findings:**
- 20 modules totaling 973 lines
- 18% code duplication (~160 duplicated lines)
- 4 high-value shared library opportunities

**Priority 1 Opportunities:**

#### 1. Create User Account Builder (`modules/lib/mkUser.nix`)
- **Impact:** Eliminates 80+ lines of duplication
- **Scope:** User account structure duplicated across `modules/users/mi-skam.nix` and `modules/users/plumps.nix`
- **Benefit:** 95% identical code consolidated, standardized user creation pattern
- **Effort:** 2-3 hours
- **Iteration:** I3

#### 2. Create System Common Library (`modules/lib/system-common.nix`)
- **Impact:** Eliminates 30-40 lines
- **Scope:** Nix experimental features, allowUnfree, timezone, shell config duplicated across `modules/nixos/common.nix` and `modules/darwin/common.nix`
- **Benefit:** Single source of truth for common system settings
- **Effort:** 1-2 hours
- **Iteration:** I3

**Priority 2 Opportunities:**

#### 3. Extract Home Manager Config Helpers (`modules/lib/hm-helpers.nix`)
- **Impact:** Reduces `modules/home/common.nix` from 264 to ~150 lines
- **Scope:** Extract neovim config (~60 lines), starship config (~35 lines), common package lists
- **Benefit:** Reusable editor/shell configurations across users
- **Effort:** 4-6 hours
- **Iteration:** I3

#### 4. Create Platform Detection Utility (`modules/lib/platform.nix`)
- **Impact:** Eliminates 15-20 lines total
- **Scope:** Platform detection let bindings duplicated across 6+ modules
- **Benefit:** Consistent platform detection pattern
- **Effort:** 1 hour
- **Iteration:** I3

**Expected Outcomes:**
- Reduce codebase by ~195 lines (21.8% reduction)
- Decrease duplication from 18% to <5%
- Improve maintainability through shared libraries

### 6.2 Ansible Role Refactoring Opportunities

**Source:** `docs/refactoring/ansible_role_analysis.md`

**Key Findings:**
- 3 existing roles with 0% Galaxy structure completeness
- 0% of roles have README.md documentation
- Bootstrap playbook contains ~75 lines that should be in roles
- 8 hardcoded values requiring parameterization

**Priority 1 Opportunities (Blocking):**

#### 1. Extract Bootstrap Tasks to Roles
- **Impact:** Reduces `bootstrap.yaml` from 96 to ≤30 lines (69% reduction)
- **Scope:**
  - Create `ssh-hardening` role (lines 51-68: SSH configuration)
  - Create `security-baseline` role (lines 70-89: auto-updates)
  - Move package installation to `common` role (lines 22-45)
- **Benefit:** Reusable security configurations, cleaner playbooks
- **Effort:** Medium (1 week)
- **Iteration:** I3

#### 2. Add Galaxy Structure to All Roles
- **Impact:** Achieve 100% Galaxy compliance (up from 0%)
- **Scope:** Add `meta/main.yaml`, `defaults/main.yaml`, `README.md` to 3 existing + 2 new roles
- **Benefit:** Roles become publishable to Galaxy, self-documenting, properly versioned
- **Effort:** Medium (1 week)
- **Iteration:** I3

#### 3. Parameterize Hardcoded Values
- **Impact:** Eliminate all 8 hardcoded values
- **Scope:**
  - `/opt/scripts`, `/var/log/homelab` → `common_scripts_dir`, `common_log_dir`
  - Bash aliases → template file
  - Mailcow paths → role defaults or group_vars
- **Benefit:** Flexible configuration, easier testing
- **Effort:** Low-Medium (1 week)
- **Iteration:** I3

**Priority 2 Opportunities (High Value):**

#### 4. Implement Monitoring Role
- **Impact:** Enable observability baseline (addresses Gap 5.1)
- **Scope:** Implement skeleton monitoring role with node_exporter, log forwarding
- **Benefit:** Production readiness, alerting capability
- **Effort:** Medium (1 week)
- **Iteration:** I5+

**Expected Outcomes:**
- 5 roles with 100% Galaxy structure (up from 0%)
- Bootstrap playbook: 96 → 25 lines (-74%)
- Reusability score: 4/10 → 11/10 (+175%)
- Documentation coverage: 0% → 100%

### 6.3 Justfile Refactoring Opportunities

**Source:** `docs/refactoring/justfile_analysis.md`

**Key Findings:**
- 27 recipes, 230 lines
- SOPS token extraction duplicated 8 times (critical issue)
- No pre-flight validation checks
- Minimal error handling (3/27 recipes)

**Priority 1 Opportunities (Critical):**

#### 1. Extract SOPS Token Decryption
- **Impact:** Eliminates 8 duplicate command executions
- **Scope:** Lines 25, 32, 39, 48, 55, 62, 69, 101
- **Current:** `export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"`
- **Solution:** Create helper recipe `_export-hcloud-token` with validation
- **Benefit:** Single source of truth, proper error handling
- **Effort:** 2-3 hours
- **Iteration:** I4

#### 2. Add Pre-flight Validation Recipes
- **Impact:** Prevents cryptic failures, improves user experience
- **Scope:**
  - `_validate-age-key`: Check SOPS age key exists
  - `_validate-terraform-state`: Verify Terraform initialization
  - `_validate-ansible-inventory`: Check inventory freshness
- **Benefit:** Clear error messages, fail-fast behavior
- **Effort:** 3-4 hours
- **Iteration:** I4

#### 3. Fix Pattern Inconsistency
- **Impact:** Eliminates confusion between line 7 unused variable and inline patterns
- **Scope:** Standardize on `hcloud:` grep pattern, remove unused variable
- **Benefit:** Consistent codebase
- **Effort:** 30 minutes
- **Iteration:** I4

**Priority 2 Opportunities:**

#### 4. Consolidate Dotfiles Loop Pattern
- **Impact:** Reduces 40+ lines of duplication
- **Scope:** Extract common bash loop from 5 recipes to `_stow-all` helper
- **Benefit:** DRY principle, easier maintenance
- **Effort:** 2 hours
- **Iteration:** I4

#### 5. Add Error Handling
- **Impact:** Improves reliability
- **Scope:** Add `set -euo pipefail` to bash recipes, validate exit codes
- **Benefit:** Fail-fast, clear error reporting
- **Effort:** 2-3 hours
- **Iteration:** I4

**Expected Outcomes:**
- Total lines: 230 → ~200 (-13%)
- Duplicate SOPS commands: 8 → 0 (-100%)
- Recipes with error handling: 3 → 14 (+367%)
- Validation checks: 0 → 5 (+∞)

### 6.4 Refactoring Scope Summary

| Component | Files/Modules | Current Lines | Duplication | Opportunities | Target Iteration |
|-----------|---------------|---------------|-------------|---------------|------------------|
| **Nix Modules** | 20 | 973 | 18% (~160 lines) | 4 shared libraries | I3 |
| **Ansible Roles** | 3 → 5 | 357 | Package lists | 2 new roles, Galaxy structure | I3 |
| **Justfile** | 1 (27 recipes) | 230 | 8x SOPS duplication | Validation, consolidation | I4 |
| **Terraform** | 6 | 250 | Minimal | No major refactoring needed | - |

**Total Refactoring Scope:**
- **15 Nix modules** to analyze for shared library extraction
- **3 Ansible roles** to enhance with Galaxy structure
- **2 new Ansible roles** to create (ssh-hardening, security-baseline)
- **27 justfile recipes** to refactor for validation and consolidation
- **8 consolidation opportunities** across all components

---

## 7. Next Steps and Iteration Mapping

### 7.1 Iteration Roadmap

**Iteration 2: Secrets Management (Current)**
- Document age key bootstrap process
- Implement secrets rotation procedures
- Add secrets validation checks
- Create backup/recovery procedures for age keys

**Iteration 3: Module and Role Refactoring**
- Phase 1: Create Nix shared libraries (mkUser.nix, system-common.nix, hm-helpers.nix)
- Phase 2: Extract bootstrap tasks to Ansible roles (ssh-hardening, security-baseline)
- Phase 3: Add Galaxy structure to all Ansible roles
- Phase 4: Parameterize all hardcoded values

**Iteration 4: Justfile Enhancement**
- Extract SOPS token decryption to helper recipe
- Add pre-flight validation recipes
- Consolidate dotfiles loop pattern
- Add error handling to all bash recipes
- Improve documentation with inline comments

**Iteration 5: Observability Baseline**
- Implement monitoring role with Prometheus node_exporter
- Deploy monitoring stack (Prometheus + Grafana)
- Add log aggregation
- Implement automated backups with cron
- Create backup verification procedures

**Iteration 6: CI/CD and Testing**
- Add GitHub Actions workflows
- Implement Nix flake checks, Ansible lint, Terraform validation
- Add Molecule tests for Ansible roles
- Create integration tests for deployment workflows
- Add pre-commit hooks

**Iteration 7: Infrastructure Reliability**
- Implement drift detection
- Add periodic `terraform plan` with reporting
- Create alerting for configuration drift
- Document rollback procedures
- Test disaster recovery scenarios

### 7.2 Success Criteria for Refactoring

**By End of Iteration 3:**
- [ ] Nix module duplication reduced from 18% to <5%
- [ ] All 5 Ansible roles have 100% Galaxy structure
- [ ] Bootstrap playbook reduced from 96 to ≤30 lines
- [ ] Zero hardcoded values in roles or modules

**By End of Iteration 4:**
- [ ] Justfile SOPS duplication eliminated (8 → 0)
- [ ] Pre-flight validation added (0 → 5 checks)
- [ ] Error handling coverage: 3/27 → 14/27 recipes

**By End of Iteration 7:**
- [ ] Monitoring stack deployed and operational
- [ ] Automated backups running for 2 stateful services
- [ ] CI/CD pipeline validating all changes
- [ ] Drift detection alerting operational
- [ ] Zero-downtime deployment procedures documented and tested

### 7.3 Metrics Tracking

**Baseline Metrics (Current):**
- Total infrastructure code: 1,810 lines
- Code duplication: 18% in Nix, 8x in justfile
- Ansible role maturity: 0% Galaxy compliance
- Monitoring coverage: 0/6 systems (0%)
- Backup automation: 0/2 stateful services (0%)
- CI/CD coverage: 0% (all manual deployments)
- Test coverage: 0%

**Target Metrics (Post-Refactoring):**
- Total infrastructure code: ~1,700 lines (-6% through consolidation)
- Code duplication: <5% across all components
- Ansible role maturity: 100% Galaxy compliance (5/5 roles)
- Monitoring coverage: 6/6 systems (100%)
- Backup automation: 2/2 stateful services (100%)
- CI/CD coverage: 100% (automated validation for all changes)
- Test coverage: >80% (Molecule tests, NixOS VM tests, integration tests)

---

## 8. Appendices

### Appendix A: File Structure Overview

```
infra/
├── flake.nix                    # Main flake definition (162 lines)
├── devshell.nix                 # Development environment
├── justfile                     # Task automation (230 lines, 27 recipes)
│
├── hosts/                       # Host configurations (3 systems)
│   ├── xbook/                   # Darwin ARM64
│   ├── xmsi/                    # NixOS x86_64
│   └── srv-01/                  # NixOS x86_64 (config only)
│
├── modules/                     # Nix modules (20 modules, 973 lines)
│   ├── nixos/                   # 6 modules, 172 lines
│   ├── darwin/                  # 3 modules, 137 lines
│   ├── home/                    # 9 modules, 565 lines
│   ├── home/users/              # 2 user configs, 34 lines
│   └── users/                   # 2 system users, 87 lines
│
├── terraform/                   # Hetzner infrastructure (6 files, 250 lines)
│   ├── providers.tf
│   ├── variables.tf
│   ├── network.tf
│   ├── servers.tf
│   ├── outputs.tf
│   └── ssh_keys.tf
│
├── ansible/                     # Configuration management (12 files, 357 lines)
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yaml           # Generated from Terraform
│   │   └── group_vars/          # all.yaml, prod.yaml, dev.yaml
│   ├── playbooks/               # 4 playbooks
│   │   ├── bootstrap.yaml       # 96 lines (needs refactoring)
│   │   ├── deploy.yaml          # 23 lines
│   │   ├── setup-storagebox.yaml
│   │   └── mailcow-backup.yaml  # 59 lines (manual execution)
│   └── roles/                   # 3 roles (0% Galaxy compliance)
│       ├── common/              # 37 lines tasks
│       ├── monitoring/          # Empty skeleton
│       └── storagebox/          # 30 lines tasks, 12 lines defaults
│
├── secrets/                     # SOPS-encrypted secrets (3 files)
│   ├── hetzner.yaml             # Hetzner API token
│   ├── storagebox.yaml          # Storage Box credentials
│   └── authorized_keys          # SSH public keys
│
├── docs/                        # Documentation
│   ├── refactoring/             # Analysis documents (3 completed)
│   │   ├── justfile_analysis.md        # 882 lines
│   │   ├── nix_module_analysis.md      # ~1,012 lines
│   │   ├── ansible_role_analysis.md    # ~1,612 lines
│   │   └── baseline_report.md          # This document
│   └── diagrams/                # Architecture diagrams (C4 models)
│
└── scripts/                     # Utility scripts
    └── create-vm-darwin.sh      # QEMU VM launcher for macOS ARM64
```

### Appendix B: System-Specific Details

**xbook (Darwin ARM64):**
- Hardware: MacBook with ARM64 architecture
- User: plumps
- Managed by: Nix Darwin + Home Manager
- Imported modules: `modules/darwin/desktop.nix`
- Home config: `plumps@xbook`

**xmsi (NixOS x86_64):**
- Hardware: Desktop workstation with MSI hardware profile
- User: mi-skam
- Managed by: NixOS + Home Manager
- Imported modules: `modules/nixos/{desktop,plasma}.nix`
- Home config: `mi-skam@xmsi`

**srv-01 (NixOS x86_64):**
- Hardware: Local server
- User: plumps
- Managed by: NixOS + Home Manager (configuration only, not deployed)
- Home config: `plumps@srv-01`

**mail-1.prod.nbg (Hetzner Cloud):**
- Location: Nuremberg datacenter
- OS: Debian 12
- Instance: CAX21 (ARM64, 4 cores, 8GB RAM)
- Services: Mail server (mailcow)
- Managed by: OpenTofu + Ansible
- Private IP: 10.0.0.x (assigned by Hetzner)
- Backup: Manual (mailcow-backup.yaml playbook)

**syncthing-1.prod.hel (Hetzner Cloud):**
- Location: Helsinki datacenter
- OS: Rocky Linux 9
- Instance: CAX11 (ARM64, 2 cores, 4GB RAM)
- Services: Syncthing file synchronization
- Managed by: OpenTofu + Ansible
- Private IP: 10.0.0.x (assigned by Hetzner)
- Backup: Not configured

**test-1.dev.nbg (Hetzner Cloud):**
- Location: Nuremberg datacenter
- OS: Ubuntu 24.04
- Instance: CAX11 (ARM64, 2 cores, 4GB RAM)
- Services: Test environment
- Managed by: OpenTofu + Ansible
- Private IP: 10.0.0.x (assigned by Hetzner)

### Appendix C: Related Documentation

**Completed Analysis Documents:**
- `docs/refactoring/justfile_analysis.md` - Comprehensive 882-line analysis of justfile structure
- `docs/refactoring/nix_module_analysis.md` - 1,012-line analysis of 20 Nix modules
- `docs/refactoring/ansible_role_analysis.md` - 1,612-line analysis of Ansible roles

**Architecture Documentation:**
- `docs/diagrams/` - C4 component and deployment diagrams
- `CLAUDE.md` - Project overview and operational guidance
- `README.md` - Quick start and usage documentation

**Project Management:**
- `01_Context_and_Drivers.md` - Project vision, objectives, and constraints
- Task manifests for Iterations 1-7 (in project management system)

---

## Conclusion

This baseline report establishes a comprehensive snapshot of the infrastructure management system before refactoring. The system manages **6 heterogeneous systems** across **3 environments** using **1,810 lines of infrastructure code** spanning **4 technology stacks** (Nix, Ansible, Terraform, justfile).

**Key Metrics Summary:**
- **Systems:** 6 (3 local, 2 production, 1 development)
- **Code:** 1,810 total lines (973 Nix, 357 Ansible, 250 Terraform, 230 justfile)
- **Duplication:** 18% in Nix modules, 8x in justfile SOPS extraction
- **Maturity:** 0% Ansible Galaxy compliance, minimal validation/error handling

**Critical Gaps Identified:**
1. No monitoring stack (0/6 systems monitored)
2. No automated backups (0/2 stateful services backed up)
3. No CI/CD pipeline (100% manual deployments)
4. No automated testing (0% test coverage)
5. No drift detection (manual state management only)

**Refactoring Scope Quantified:**
- **Nix:** 4 shared library opportunities, 160 lines of duplication to eliminate
- **Ansible:** 2 new roles to create, 3 existing roles to enhance to 100% Galaxy compliance
- **Justfile:** 8 consolidation opportunities, 5 validation checks to add

**Success Criteria for Post-Refactoring:**
- Code duplication: 18% → <5%
- Ansible role maturity: 0% → 100%
- Monitoring coverage: 0% → 100%
- Backup automation: 0% → 100%
- CI/CD coverage: 0% → 100%
- Test coverage: 0% → >80%

This report provides measurable baselines for all subsequent refactoring iterations (I2-I7), enabling data-driven assessment of refactoring success.

---

**Document Status:** Final
**Last Updated:** 2025-10-28
**Next Review:** After completion of Iteration 3 (Module/Role Refactoring)
**Version History:**
- v1.0 (2025-10-28): Initial baseline report
