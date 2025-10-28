# Justfile Structure Analysis

**Document Version:** 1.0
**Analysis Date:** 2025-10-28
**Source File:** `justfile` (230 lines, 27 recipes)
**Purpose:** Comprehensive audit to inform Iteration 4 refactoring

---

## Executive Summary

The current justfile orchestrates infrastructure management across three primary domains: OpenTofu/Terraform provisioning (9 recipes), Ansible configuration management (6 recipes), and dotfiles deployment (11 recipes), plus 1 utility recipe.

**Key Findings:**

- **Critical Code Duplication:** SOPS Hetzner API token decryption pattern duplicated 8 times (lines 25, 32, 39, 48, 55, 62, 69, 101)
- **Inconsistent Secret Extraction:** Two different grep patterns for the same secret (lines 7 vs 25+)
- **Missing Pre-flight Validations:** No verification of age keys, git staging, Terraform state, or Ansible inventory freshness
- **Minimal Error Handling:** Most recipes lack exit code checking, clear error messages, or rollback mechanisms
- **Implicit Dependencies:** Logical dependencies exist but aren't expressed in recipe declarations
- **Documentation Gaps:** No inline comments explaining complex bash logic or recipe purposes

**Recommended Priority for I4:**

1. Extract SOPS decryption to shared variable/helper (affects 8 recipes)
2. Add pre-flight validation recipes (age key, git status, state file checks)
3. Implement consistent error handling patterns
4. Add recipe-level documentation comments
5. Consolidate dotfiles recipes (50% of file, potentially separate concern)

---

## 1. Recipe Inventory

### 1.1 Complete Recipe Table

| Recipe Name | Parameters | Category | Bash Shebang | Line Numbers | Description |
|------------|------------|----------|--------------|--------------|-------------|
| `default` | None | Utility | No | 10-11 | Lists all available recipes via `just --list` |
| `tf-init` | None | Terraform | No | 18-19 | Initializes OpenTofu/Terraform working directory |
| `tf-plan` | None | Terraform | Yes | 22-26 | Shows infrastructure change preview |
| `tf-apply` | None | Terraform | Yes | 29-33 | Applies infrastructure changes |
| `tf-destroy` | None | Terraform | Yes | 36-42 | Destroys infrastructure with warning message |
| `tf-destroy-target` | `target` (required) | Terraform | Yes | 45-49 | Destroys specific resource by Terraform address |
| `tf-import` | None | Terraform | Yes | 52-56 | Imports existing Hetzner resources via import.sh |
| `tf-output` | None | Terraform | Yes | 59-63 | Displays Terraform output values |
| `ansible-inventory-update` | None | Terraform/Ansible | Yes | 66-71 | Extracts Terraform outputs to Ansible inventory file |
| `ansible-ping` | None | Ansible | No | 78-79 | Tests SSH connectivity to all managed hosts |
| `ansible-deploy` | `playbook` (required) | Ansible | No | 82-83 | Runs specified playbook on all hosts |
| `ansible-deploy-to` | `env`, `playbook` (both required) | Ansible | No | 86-87 | Runs playbook on specific environment (dev/prod) |
| `ansible-inventory` | None | Ansible | No | 90-91 | Lists Ansible inventory in JSON format |
| `ansible-cmd` | `command` (required) | Ansible | No | 94-95 | Executes ad-hoc command on all hosts |
| `ssh` | `server` (optional, default="") | Ansible | Yes | 98-116 | SSH to server by name, or list available servers if no arg |
| `install-all` | None | Dotfiles | No | 123 | Installs Homebrew packages and dotfiles (has dependencies) |
| `install-brew` | None | Dotfiles | No | 126-128 | Installs packages from dotfiles/brew/.Brewfile |
| `install-dotfiles` | None | Dotfiles | Yes | 131-141 | Stows all dotfile packages to target directory |
| `uninstall-dotfiles` | None | Dotfiles | Yes | 144-154 | Unstows all dotfile packages from target directory |
| `ensure-stow` | None | Dotfiles | No | 157-158 | Installs stow via Homebrew if not present |
| `dry-run` | None | Dotfiles | Yes | 161-171 | Simulates stow operations without making changes |
| `install` | `package` (required) | Dotfiles | No | 174-175 | Stows specific dotfile package |
| `uninstall` | `package` (required) | Dotfiles | No | 178-179 | Unstows specific dotfile package |
| `restow` | `package` (optional, default="") | Dotfiles | Yes | 182-197 | Re-stows all packages or specific package |
| `check` | None | Dotfiles | Yes | 200-216 | Checks for stow conflicts before installation |
| `clean` | None | Dotfiles | No | 219-221 | Finds broken symlinks in target directory |
| `test-install` | `tmpdir` (optional, default="/tmp/dotfiles-test") | Dotfiles | Yes | 224-231 | Tests dotfiles installation in temporary directory |

**Statistics:**

- Total recipes: 27
- Recipes with bash shebangs: 14 (52%)
- Recipes with parameters: 9 (33%)
- Recipes with required parameters: 6 (22%)
- Recipes with optional parameters: 3 (11%)

### 1.2 Variables

| Variable Name | Type | Definition Line | Usage Pattern | Notes |
|--------------|------|-----------------|---------------|-------|
| `target` | Environment variable with default | 4 | Used in 10 dotfiles recipes | Defaults to `~`, allows override via `STOW_TARGET` |
| `hcloud_token` | Command substitution | 7 | **UNUSED** - defined but never referenced | Uses grep pattern `hcloud_token`, differs from inline pattern `hcloud:` |

**Critical Issue:** The `hcloud_token` variable at line 7 is defined but never used. All recipes that need the token re-execute the SOPS command inline with a **different grep pattern** (`hcloud:` instead of `hcloud_token`), creating pattern inconsistency.

---

## 2. Recipe Dependencies

### 2.1 Explicit Dependencies

Only **one** recipe declares explicit dependencies:

| Recipe | Depends On | Line | Type |
|--------|-----------|------|------|
| `install-all` | `install-brew`, `install-dotfiles` | 123 | Sequential execution via just dependency chain |

### 2.2 Implicit Dependencies (Not Declared)

These logical dependencies exist but are not enforced in the justfile:

| Recipe | Should Depend On | Reason |
|--------|------------------|--------|
| `tf-plan`, `tf-apply`, `tf-destroy`, `tf-import` | `tf-init` | Terraform requires initialization before operations |
| `ansible-deploy`, `ansible-deploy-to`, `ansible-ping` | `ansible-inventory-update` | Ansible inventory should be current before deployments |
| `install-dotfiles` | `ensure-stow` | Requires stow to be installed (currently called inline) |
| All Terraform recipes | SOPS age key verification | Cannot decrypt secrets without valid age key |
| All recipes using `cd terraform` | Terraform directory existence | Would fail silently if directory missing |

### 2.3 Data Dependencies

| Recipe | Requires Data From | File/Resource | Validation Present |
|--------|-------------------|---------------|-------------------|
| All Terraform recipes (8) | SOPS age private key | `/etc/sops/age/keys.txt` or `~/.config/sops/age/keys.txt` | No |
| All Terraform recipes (8) | Hetzner API token | `secrets/hetzner.yaml` | No (uses `|| echo ""` fallback) |
| `ansible-inventory-update` | Terraform state | `terraform/terraform.tfstate` | No |
| Ansible recipes | Ansible inventory | `ansible/inventory/hosts.yaml` | No |
| `ssh` | Terraform outputs | `terraform/terraform.tfstate` | No |
| `ssh` | SSH private key | `~/.ssh/homelab/hetzner` | No |
| Dotfiles recipes | Dotfiles directory | `dotfiles/` | No |
| `install-brew` | Brewfile | `dotfiles/brew/.Brewfile` | No |

**Critical Gap:** None of these data dependencies have pre-flight validation. Recipes will fail mid-execution with cryptic error messages rather than clear validation failures.

---

## 3. Consolidation Opportunities

### 3.1 SOPS Token Extraction Duplication (HIGH PRIORITY)

**Impact:** 8 recipes, 8 identical command executions

**Current Pattern (lines 25, 32, 39, 48, 55, 62, 69, 101):**
```bash
export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
```

**Affected Recipes:**
1. `tf-plan` (line 25)
2. `tf-apply` (line 32)
3. `tf-destroy` (line 39)
4. `tf-destroy-target` (line 48)
5. `tf-import` (line 55)
6. `tf-output` (line 62)
7. `ansible-inventory-update` (line 69)
8. `ssh` (line 101)

**Problem Analysis:**

1. **Unused Variable:** Line 7 defines `hcloud_token` but it's never used
2. **Pattern Inconsistency:** Line 7 uses grep pattern `hcloud_token`, lines 25+ use `hcloud:` (different field name)
3. **No Error Handling:** SOPS failures are silently ignored (no `|| echo ""` in inline versions)
4. **Performance:** SOPS decryption executes 8 times in rapid succession if multiple recipes run
5. **Maintenance:** Changing secret format requires 8 updates

**Recommended Solution:**

```just
# Option 1: Fix and use existing variable
hcloud_token := `sops -d secrets/hetzner.yaml 2>/dev/null | grep 'hcloud:' | cut -d: -f2 | xargs`

# Option 2: Create helper recipe (preferred for validation)
[private]
@_export-hcloud-token:
    #!/usr/bin/env bash
    if [ ! -f ~/.config/sops/age/keys.txt ] && [ ! -f /etc/sops/age/keys.txt ]; then
        echo "Error: SOPS age key not found"
        exit 1
    fi
    TOKEN=$(sops -d secrets/hetzner.yaml 2>/dev/null | grep 'hcloud:' | cut -d: -f2 | xargs)
    if [ -z "$TOKEN" ]; then
        echo "Error: Failed to extract Hetzner API token from secrets/hetzner.yaml"
        exit 1
    fi
    export TF_VAR_hcloud_token="$TOKEN"
```

Then recipes become:
```just
@tf-plan: _export-hcloud-token
    cd terraform && tofu plan
```

**Estimated Reduction:** 8 lines × 1 command = ~8 lines eliminated, plus improved error handling

### 3.2 Terraform Directory Navigation Pattern

**Impact:** 10 recipes start with `cd terraform`

**Current Pattern:**
```just
@tf-plan:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
    tofu plan
```

**Problem:**
- Relative path to secrets (`../secrets/`) required due to directory change
- No validation that `terraform/` directory exists
- Inconsistent patterns (some recipes use `cd terraform &&`, others use bash blocks)

**Recommended Solution:**

```just
# Set working directory as variable
terraform_dir := "terraform"

# Recipes can use:
@tf-plan:
    cd {{terraform_dir}} && tofu plan
```

Or use just's built-in working directory feature (requires just 1.9+):
```just
@tf-plan:
    [working-directory: terraform]
    tofu plan
```

**Note:** This requires addressing SOPS consolidation first (recommendation 3.1)

### 3.3 Dotfiles Loop Pattern Duplication

**Impact:** 5 recipes use identical bash loop structure

**Current Pattern (lines 135-141, 148-154, 165-171, 187-193):**
```bash
for dir in */; do
    if [ -d "$dir" ]; then
        package="${dir%/}"
        echo "  → Processing $package..."
        stow <flags> -t {{target}} "$package"
    fi
done
```

**Affected Recipes:**
1. `install-dotfiles` (lines 135-141)
2. `uninstall-dotfiles` (lines 148-154)
3. `dry-run` (lines 165-171)
4. `restow` (lines 187-193)
5. `check` (lines 205-216)

**Recommended Solution:**

Create private helper recipe:
```just
# Apply stow operation to all packages
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
```

Then recipes become:
```just
@install-dotfiles: ensure-stow
    echo "Stowing dotfiles to {{target}}..."
    just _stow-all "-v -R"

@uninstall-dotfiles:
    echo "Unstowing dotfiles from {{target}}..."
    just _stow-all "-v -D"
```

**Estimated Reduction:** ~40 lines of duplicated bash loop logic

### 3.4 Ansible Directory Navigation

**Impact:** 5 recipes start with `cd ansible`

**Similar Issue to 3.2:** Repeated directory navigation without validation

**Recommended Solution:**
```just
ansible_dir := "ansible"

# Or use working-directory attribute
@ansible-ping:
    [working-directory: ansible]
    ansible all -m ping
```

### 3.5 Dotfiles Recipe Separation

**Impact:** 11 recipes (48% of total) devoted to dotfiles, separate from infrastructure concern

**Analysis:**

The dotfiles recipes (lines 119-231, 112 lines) are:
- Unrelated to infrastructure provisioning (Terraform/Ansible)
- Have their own dependency chain (`install-all` → `install-brew` + `install-dotfiles`)
- Use different tooling (stow, Homebrew vs OpenTofu, Ansible)
- Operate on different target (local workstation vs remote servers)

**Recommended Solution:**

Create separate `dotfiles.justfile` and import it:
```just
# In main justfile
import? 'dotfiles.justfile'

# Or use just modules (just 1.20+)
mod dotfiles 'dotfiles.justfile'
```

**Benefits:**
- Clearer separation of concerns
- Easier to maintain dotfiles recipes independently
- Reduces cognitive load when working on infrastructure automation
- Main justfile focuses on infrastructure (Terraform + Ansible)

---

## 4. Missing Validation Steps

### 4.1 SOPS Age Key Verification (CRITICAL)

**Severity:** HIGH
**Affects:** 8 recipes (all Terraform operations)

**Current Behavior:** SOPS decryption fails with cryptic error if age key missing:
```
Error: error getting data key: 0 successful groups required, got 0
```

**Recommended Validation:**
```just
# Validate SOPS age key exists before operations
[private]
@_validate-age-key:
    #!/usr/bin/env bash
    if [ ! -f ~/.config/sops/age/keys.txt ] && [ ! -f /etc/sops/age/keys.txt ]; then
        echo "❌ Error: SOPS age private key not found"
        echo "Expected locations:"
        echo "  - ~/.config/sops/age/keys.txt"
        echo "  - /etc/sops/age/keys.txt"
        echo ""
        echo "Documentation: docs/01_Plan_Overview_and_Setup.md#secrets-management"
        exit 1
    fi
    echo "✓ SOPS age key found"
```

Add as dependency to all Terraform recipes:
```just
@tf-plan: _validate-age-key
    # ... recipe content
```

### 4.2 Git Staging Verification (CRITICAL for Nix)

**Severity:** HIGH
**Affects:** NixOS/Darwin system deployments (not in justfile but mentioned in CLAUDE.md)

**Issue from CLAUDE.md:** "If Nix Flakes sees that it's dealing with files in a git repository, those files and hence the changes need to be on the git index to be picked up!"

**Recommended Validation:**
```just
# Verify git working tree is clean or staged
[private]
@_validate-git-staged:
    #!/usr/bin/env bash
    if git diff --quiet && git diff --cached --quiet; then
        echo "✓ Git working tree clean"
    elif git diff --cached --quiet; then
        echo "❌ Error: Unstaged changes detected"
        echo "Nix flakes require changes to be staged with 'git add'"
        echo ""
        git status --short
        exit 1
    else
        echo "✓ Changes staged for commit"
    fi
```

### 4.3 Terraform State File Existence

**Severity:** MEDIUM
**Affects:** `tf-plan`, `tf-apply`, `tf-destroy`, `tf-output`, `ansible-inventory-update`, `ssh`

**Current Behavior:** Recipes fail with "No state file" error if running before `tf-init` or after state deletion

**Recommended Validation:**
```just
# Verify Terraform is initialized and has state
[private]
@_validate-terraform-state:
    #!/usr/bin/env bash
    if [ ! -f terraform/.terraform.lock.hcl ]; then
        echo "❌ Error: Terraform not initialized"
        echo "Run: just tf-init"
        exit 1
    fi
    if [ ! -f terraform/terraform.tfstate ]; then
        echo "⚠ Warning: No Terraform state file found"
        echo "This is normal for first run"
    else
        echo "✓ Terraform state exists"
    fi
```

### 4.4 Ansible Inventory Freshness Check

**Severity:** MEDIUM
**Affects:** `ansible-deploy`, `ansible-deploy-to`, `ansible-ping`, `ansible-cmd`

**Current Behavior:** Ansible uses potentially stale inventory if Terraform outputs changed

**Recommended Validation:**
```just
# Check if Ansible inventory is older than Terraform state
[private]
@_validate-ansible-inventory:
    #!/usr/bin/env bash
    INVENTORY="ansible/inventory/hosts.yaml"
    STATE="terraform/terraform.tfstate"

    if [ ! -f "$INVENTORY" ]; then
        echo "❌ Error: Ansible inventory not found"
        echo "Run: just ansible-inventory-update"
        exit 1
    fi

    if [ -f "$STATE" ]; then
        if [ "$STATE" -nt "$INVENTORY" ]; then
            echo "⚠ Warning: Terraform state is newer than Ansible inventory"
            echo "Recommend running: just ansible-inventory-update"
        else
            echo "✓ Ansible inventory is current"
        fi
    fi
```

### 4.5 SSH Key Existence Verification

**Severity:** LOW
**Affects:** `ssh` recipe (line 116)

**Current Behavior:** SSH command fails with "Identity file not found" if key missing

**Recommended Validation:**
```just
# Verify SSH key exists before attempting connection
[private]
@_validate-ssh-key:
    #!/usr/bin/env bash
    KEY="~/.ssh/homelab/hetzner"
    if [ ! -f "$KEY" ]; then
        echo "❌ Error: SSH key not found: $KEY"
        echo "Generate with: ssh-keygen -t ed25519 -f $KEY"
        exit 1
    fi
    echo "✓ SSH key exists"
```

### 4.6 Destructive Operation Confirmation

**Severity:** MEDIUM
**Affects:** `tf-destroy`, `uninstall-dotfiles`, `tf-destroy-target`

**Current State:** Only `tf-destroy` has a warning (lines 40-41), but no interactive confirmation

**Recommended Pattern:**
```just
# Destroy infrastructure with confirmation
@tf-destroy:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"

    echo "⚠️  WARNING: This will destroy infrastructure!"
    echo "Protected servers (prevent_destroy=true) will be skipped."
    echo ""
    read -p "Type 'yes' to confirm: " confirmation

    if [ "$confirmation" != "yes" ]; then
        echo "❌ Destroy cancelled"
        exit 1
    fi

    tofu destroy
```

### 4.7 Terraform Plan Before Apply

**Severity:** MEDIUM
**Affects:** `tf-apply`, `tf-destroy`

**Current Behavior:** No preview shown before applying changes

**Recommended Pattern:**
```just
# Apply infrastructure changes with plan preview
@tf-apply:
    #!/usr/bin/env bash
    cd terraform
    export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"

    echo "=== Terraform Plan Preview ==="
    tofu plan
    echo ""
    read -p "Apply these changes? (yes/no): " confirmation

    if [ "$confirmation" != "yes" ]; then
        echo "❌ Apply cancelled"
        exit 1
    fi

    tofu apply
```

### 4.8 Required Directory Existence

**Severity:** LOW
**Affects:** All recipes using `cd <dir>`

**Recommended Validation:**
```just
# Validate required directories exist
[private]
@_validate-directories:
    #!/usr/bin/env bash
    for dir in terraform ansible dotfiles; do
        if [ ! -d "$dir" ]; then
            echo "❌ Error: Required directory not found: $dir"
            exit 1
        fi
    done
    echo "✓ All required directories exist"
```

---

## 5. Error Handling Improvements

### 5.1 Exit on Error (set -e)

**Current State:** Only 3 bash recipes use explicit error handling

**Recommendation:** Add `set -euo pipefail` to all bash shebangs:
```just
@recipe:
    #!/usr/bin/env bash
    set -euo pipefail  # Exit on error, undefined variables, pipe failures
    # ... recipe commands
```

**Impact:** Recipes will fail fast on first error instead of continuing with potentially corrupted state

### 5.2 SOPS Decryption Error Handling

**Current Issue:** Line 7 uses `|| echo ""` which silently fails, lines 25+ don't handle errors at all

**Recommended Pattern:**
```bash
TOKEN=$(sops -d secrets/hetzner.yaml 2>&1 | grep 'hcloud:' | cut -d: -f2 | xargs)
if [ -z "$TOKEN" ]; then
    echo "❌ Error: Failed to decrypt Hetzner API token"
    echo "Check SOPS age key is configured correctly"
    exit 1
fi
export TF_VAR_hcloud_token="$TOKEN"
```

### 5.3 Command Existence Verification

**Current State:** Only `ensure-stow` checks if command exists (line 158)

**Recommendation:** Add command checks for critical tools:
```just
[private]
@_validate-tools:
    #!/usr/bin/env bash
    missing_tools=()
    for tool in tofu ansible stow sops jq; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "❌ Error: Missing required tools: ${missing_tools[*]}"
        echo "Enter development shell: nix develop"
        exit 1
    fi
    echo "✓ All required tools available"
```

### 5.4 Terraform Operation Exit Codes

**Current Issue:** No checking if `tofu` commands succeed

**Recommended Pattern:**
```bash
if ! tofu plan; then
    echo "❌ Terraform plan failed"
    exit 1
fi
```

### 5.5 Ansible Connectivity Failures

**Current Issue:** `ansible-deploy` doesn't verify connectivity before deployment

**Recommended Pattern:**
```just
@ansible-deploy playbook: _validate-ansible-inventory
    #!/usr/bin/env bash
    cd ansible

    echo "=== Testing connectivity ==="
    if ! ansible all -m ping; then
        echo "❌ Error: Cannot reach all hosts"
        echo "Fix connectivity issues before deploying"
        exit 1
    fi

    echo "=== Running playbook: {{playbook}} ==="
    ansible-playbook playbooks/{{playbook}}.yaml
```

---

## 6. Code Quality Issues

### 6.1 Pattern Inconsistencies

| Issue | Location | Problem | Recommendation |
|-------|----------|---------|----------------|
| Grep pattern mismatch | Lines 7 vs 25+ | `hcloud_token` vs `hcloud:` | Standardize on `hcloud:` pattern |
| Directory navigation | Mixed `cd dir &&` and bash blocks | Inconsistent style | Use bash blocks for complex recipes, inline for simple |
| Error suppression | Line 7: `2>/dev/null ... || echo ""` | Silent failures | Remove fallback, fail explicitly |
| Command prefix | Mixed `@` prefix usage | Some recipes echo, some don't | Use `@` for quiet recipes, omit for verbose |
| Parameter defaults | Line 98: `server=""`, line 224: `tmpdir="/tmp/..."` | Against "fail early" principle from CLAUDE.md | Remove defaults per coding standards |

### 6.2 Documentation Gaps

**Current State:** Only section headers (lines 13, 73, 119), no recipe-level comments

**Recommended Format:**
```just
# ============================================================================
# Terraform / OpenTofu Commands
# ============================================================================

# Initialize OpenTofu/Terraform
#
# Creates .terraform directory and downloads providers.
# Must be run before any other Terraform operations.
# Safe to run multiple times (idempotent).
@tf-init:
    cd terraform && tofu init
```

### 6.3 Magic Values

**Identified Constants That Should Be Variables:**

| Magic Value | Location | Recommendation |
|-------------|----------|----------------|
| `~/.ssh/homelab/hetzner` | Line 116 | `ssh_key := "~/.ssh/homelab/hetzner"` |
| `/tmp/dotfiles-test` | Line 224 | Should NOT have default per coding standards |
| `dotfiles/brew/.Brewfile` | Line 128 | `brewfile := "dotfiles/brew/.Brewfile"` |
| `../secrets/hetzner.yaml` | Lines 25+ | `secrets_file := "secrets/hetzner.yaml"` |

### 6.4 Unused Code

**Line 7:** Variable `hcloud_token` defined but never used (see 3.1)

**Recommendation:** Either use it consistently or remove it to avoid confusion

---

## 7. Recommendations for Iteration 4 Refactoring

### Priority 1: Critical (Must Fix)

1. **Extract SOPS Token Decryption** (Section 3.1)
   - Consolidate 8 duplicate SOPS commands
   - Add validation for age key existence
   - Add error handling for decryption failures
   - **Estimated effort:** 2-3 hours
   - **Lines saved:** ~8-10

2. **Add Pre-flight Validation Recipes** (Section 4)
   - `_validate-age-key`: Check SOPS age key exists
   - `_validate-terraform-state`: Verify Terraform initialization
   - `_validate-ansible-inventory`: Check inventory freshness
   - **Estimated effort:** 3-4 hours
   - **Lines added:** ~40-50 (but prevents runtime failures)

3. **Fix Pattern Inconsistency** (Section 6.1)
   - Standardize on `hcloud:` grep pattern
   - Remove unused `hcloud_token` variable at line 7
   - **Estimated effort:** 30 minutes
   - **Lines changed:** 2

### Priority 2: Important (Should Fix)

4. **Consolidate Dotfiles Loop Pattern** (Section 3.3)
   - Extract common bash loop to `_stow-all` helper
   - Reduce 40+ lines of duplication
   - **Estimated effort:** 2 hours
   - **Lines saved:** ~35-40

5. **Add Error Handling** (Section 5)
   - Add `set -euo pipefail` to all bash recipes
   - Validate command exit codes
   - Improve error messages
   - **Estimated effort:** 2-3 hours
   - **Lines changed:** ~15 recipes

6. **Improve Documentation** (Section 6.2)
   - Add comments to all recipes
   - Document parameters and expected behavior
   - **Estimated effort:** 1-2 hours
   - **Lines added:** ~30-40

### Priority 3: Nice to Have

7. **Separate Dotfiles Recipes** (Section 3.5)
   - Create `dotfiles.justfile`
   - Import into main justfile
   - **Estimated effort:** 1 hour
   - **Lines moved:** 112 lines

8. **Extract Directory Navigation** (Sections 3.2, 3.4)
   - Use `working-directory` attribute (requires just 1.9+)
   - Or create directory variables
   - **Estimated effort:** 1 hour
   - **Lines changed:** ~15 recipes

9. **Add Interactive Confirmations** (Section 4.6)
   - Confirm destructive operations
   - Show plan preview before apply
   - **Estimated effort:** 1-2 hours
   - **Lines added:** ~10-15

### Refactoring Sequence

**Recommended order to minimize conflicts:**

1. Add validation recipes (independent additions)
2. Fix SOPS pattern inconsistency (single-point change)
3. Extract SOPS decryption (affects 8 recipes)
4. Add error handling (affects all bash recipes)
5. Consolidate dotfiles loops (affects 5 recipes)
6. Improve documentation (no functional changes)
7. Separate dotfiles (structural reorganization)
8. Extract directory navigation (final cleanup)

### Post-Refactoring Metrics

**Expected Improvements:**

| Metric | Current | Target | Change |
|--------|---------|--------|--------|
| Total lines | 230 | ~200 | -13% |
| Duplicate SOPS commands | 8 | 0 | -100% |
| Recipes with error handling | 3 | 14 | +367% |
| Documented recipes | 0 | 28 | +100% |
| Validation checks | 0 | 5 | +∞ |
| Recipe failures with clear errors | ~20% | ~90% | +350% |

---

## 8. Technical Debt Assessment

### High Technical Debt

1. **SOPS Duplication:** 8x repeated commands across critical infrastructure recipes
2. **No Validation:** Zero pre-flight checks before operations
3. **Pattern Inconsistency:** Two different grep patterns for same secret
4. **Silent Failures:** Errors suppressed with `|| echo ""` pattern

### Medium Technical Debt

1. **Dotfiles Coupling:** 50% of justfile devoted to unrelated concern
2. **Magic Values:** Hardcoded paths and constants throughout
3. **Implicit Dependencies:** Logical dependencies not expressed in recipe declarations
4. **Documentation:** No inline comments explaining complex logic

### Low Technical Debt

1. **Directory Navigation:** Repeated `cd` commands (minor duplication)
2. **Parameter Defaults:** Against coding standards but functional
3. **Unused Variable:** Line 7 variable defined but not used

### Risk Assessment

**High Risk (Immediate Action Required):**

- **Secret Extraction Failures:** No validation if SOPS decryption succeeds → infrastructure operations fail with cryptic errors
- **Missing Age Key:** Users can run Terraform recipes without age key → confusing error messages
- **Stale Inventory:** Ansible deployments may target wrong/outdated servers

**Medium Risk (Address Soon):**

- **No Rollback:** Failed deployments leave system in unknown state
- **Silent Failures:** `|| echo ""` pattern masks real errors
- **Terraform State:** No validation if state file exists/valid

**Low Risk (Address Eventually):**

- **Code Duplication:** Maintenance burden but not blocking
- **Documentation:** Onboarding friction but discoverable

---

## Appendix A: Recipe Call Graph Analysis

See `docs/diagrams/justfile_dependencies_current.mmd` for visual representation.

### Direct Dependencies (Declared)

- `install-all` → `install-brew`, `install-dotfiles`
- `install-dotfiles` → `ensure-stow`

### Implicit Call Chain

1. **Terraform Workflow:**
   ```
   User → tf-init → tf-plan → tf-apply → ansible-inventory-update → ansible-deploy
   ```

2. **Dotfiles Workflow:**
   ```
   User → install-all → install-brew, install-dotfiles → ensure-stow
   ```

3. **Ansible Workflow:**
   ```
   User → ansible-inventory-update → ansible-deploy → (managed servers)
   ```

### External Tool Invocations

| Recipe | External Tools Called | Dependencies |
|--------|----------------------|--------------|
| Terraform recipes (8) | `sops`, `tofu`, `jq` | SOPS age key, Terraform state |
| Ansible recipes (6) | `ansible`, `ansible-playbook` | Ansible inventory, SSH keys |
| Dotfiles recipes (11) | `stow`, `brew`, `find` | Stow installation, dotfiles directory |
| `ssh` | `ssh`, `jq`, `tofu` | SSH key, Terraform outputs |

---

## Appendix B: Line-by-Line Issue Tracking

| Line(s) | Issue Type | Severity | Description | Recommendation |
|---------|-----------|----------|-------------|----------------|
| 7 | Unused Code | Low | Variable `hcloud_token` defined but never referenced | Remove or use consistently |
| 7 | Pattern Inconsistency | Medium | Grep pattern `hcloud_token` differs from inline pattern `hcloud:` | Standardize on `hcloud:` |
| 7 | Silent Failure | High | `|| echo ""` suppresses SOPS errors | Remove fallback, fail explicitly |
| 25, 32, 39, 48, 55, 62, 69, 101 | Code Duplication | Critical | Identical SOPS command duplicated 8 times | Extract to helper recipe or variable |
| 18-71 | Missing Validation | High | No age key check before SOPS operations | Add `_validate-age-key` dependency |
| 22-71 | Missing Validation | Medium | No Terraform state verification | Add `_validate-terraform-state` dependency |
| 78-116 | Missing Validation | Medium | No inventory freshness check | Add `_validate-ansible-inventory` dependency |
| 82-87 | Missing Validation | Medium | No connectivity check before deployment | Add `ansible-ping` check in recipe |
| 98 | Coding Standards | Low | Parameter default `server=""` violates fail-early principle | Remove default |
| 116 | Missing Validation | Low | No SSH key existence check | Add `_validate-ssh-key` dependency |
| 135-141, 148-154, 165-171, 187-193 | Code Duplication | Medium | Identical bash loop pattern in 4 recipes | Extract to `_stow-all` helper |
| 224 | Coding Standards | Low | Parameter default `tmpdir="/tmp/..."` violates fail-early principle | Remove default |

---

**End of Analysis Document**

**Next Steps:**
1. Review this analysis with stakeholders
2. Prioritize recommendations based on project constraints
3. Create detailed implementation plan for Iteration 4
4. Execute refactoring in recommended sequence
5. Validate with integration tests after each major change
