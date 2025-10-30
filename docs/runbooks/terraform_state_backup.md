# Terraform State Backup and Recovery Runbook

**Purpose**: Procedures for backing up, recovering, and disaster-recovering OpenTofu/Terraform state files
**Audience**: Infrastructure operators managing Hetzner Cloud via Terraform
**Last Updated**: 2025-10-30

---

## Table of Contents

1. [Overview](#1-overview)
2. [When to Use This Runbook](#2-when-to-use-this-runbook)
3. [Understanding Terraform State](#3-understanding-terraform-state)
4. [Manual Backup Procedures](#4-manual-backup-procedures)
5. [Automated Backup Setup (macOS - Time Machine)](#5-automated-backup-setup-macos---time-machine)
6. [Automated Backup Setup (Linux - rsync + cron)](#6-automated-backup-setup-linux---rsync--cron)
7. [State Recovery Procedures](#7-state-recovery-procedures)
8. [State Disaster Recovery](#8-state-disaster-recovery)
9. [Backup Verification Procedures](#9-backup-verification-procedures)
10. [Backup Schedule Recommendations](#10-backup-schedule-recommendations)
11. [Troubleshooting](#11-troubleshooting)
12. [RTO/RPO Estimates](#12-rtorpo-estimates)
13. [Testing Schedule](#13-testing-schedule)
14. [Cross-References](#14-cross-references)

---

## 1. Overview

### What is Terraform State?

Terraform state (`terraform.tfstate`) is a critical metadata file that maps your infrastructure configuration to real-world resources. It contains:

- **Resource IDs**: Hetzner server IDs, network IDs, SSH key IDs
- **Resource metadata**: IP addresses, server names, network topology
- **Dependencies**: Resource relationships and ordering
- **Configuration tracking**: Current vs. desired state

**Without state, Terraform cannot manage infrastructure** - it won't know which resources already exist, what to create, modify, or destroy.

### Current Storage Approach

This project uses **local state storage** (`terraform/terraform.tfstate`) instead of remote backends (S3, Terraform Cloud):

**Advantages:**
- ✅ Simple - no additional infrastructure
- ✅ No cost - $0/month vs $20-50/month for remote backend
- ✅ Fast - no API calls for state operations
- ✅ Single operator - no state locking concerns

**Disadvantages:**
- ⚠️ Manual backup responsibility
- ⚠️ Risk of state file loss or corruption
- ⚠️ No automatic versioning or history
- ⚠️ Requires local backup procedures

### State Backup Strategy

This runbook provides three layers of protection:

1. **Automatic backup** (`.tfstate.backup`) - Created by Terraform before each apply
2. **Manual backup** - Before major operations
3. **Automated backup** - Daily via Time Machine (macOS) or rsync (Linux)

### State File Security

**CRITICAL**: State files contain sensitive metadata and MUST be protected:

- ✅ Never commit to git (already in `.gitignore`)
- ✅ Encrypt backups or restrict permissions (600)
- ✅ Store in secure locations only
- ✅ Use separate encrypted repository for git backups (optional)

State files contain:
- Public and private IP addresses
- Server names, locations, and sizes
- Network topology (CIDR ranges, subnets)
- SSH key references

---

## 2. When to Use This Runbook

**Use this runbook when:**

- ✅ Performing manual state backup before destructive operations
- ✅ Setting up automated state backups (first-time setup)
- ✅ Recovering from state file loss or corruption
- ✅ Rebuilding state from scratch after complete loss
- ✅ Verifying state backup integrity

**Do NOT use for:**

- ❌ Emergency rollback - Use [rollback_procedures.md Section 5](rollback_procedures.md#5-scenario-2-failed-terraform-apply) instead
- ❌ Infrastructure failures - Use [disaster_recovery.md Section 5](disaster_recovery.md#5-scenario-2-infrastructure-provisioning-error-terraform-failure) instead
- ❌ Normal Terraform operations - Use [CLAUDE.md](../../CLAUDE.md) instead

**Runbook Relationship:**

This runbook focuses on **preventive backup procedures and disaster recovery**:
- **disaster_recovery.md Section 5**: Strategic guidance on when to restore state
- **rollback_procedures.md Section 5**: Emergency restoration from `.tfstate.backup`
- **terraform_state_backup.md** (this runbook): Systematic backup automation and full disaster recovery

---

## 3. Understanding Terraform State

### State File Locations

```bash
# Primary state file (managed by Terraform)
terraform/terraform.tfstate

# Automatic backup (created before each apply)
terraform/terraform.tfstate.backup

# Manual backups (your responsibility)
~/backups/terraform-state-*.tfstate

# Lock file (tracks Terraform initialization)
terraform/.terraform.lock.hcl
```

### Automatic State Backup

Terraform/OpenTofu automatically creates `terraform.tfstate.backup` before each `tofu apply`:

**What it contains:** Previous state before the apply
**When it's created:** Immediately before state changes
**Limitations:**
- Only keeps one backup (latest)
- Ephemeral - overwritten on next apply
- Not suitable for long-term recovery

**Use `.tfstate.backup` for:**
- ✅ Immediate rollback after failed apply
- ✅ Recovering from recent mistakes (<24 hours)

**Do NOT rely on `.tfstate.backup` for:**
- ❌ Long-term disaster recovery
- ❌ Recovery after multiple applies
- ❌ Backup verification testing

### State vs Configuration

**Important distinction:**

| Aspect | Configuration Files | State File |
|--------|-------------------|------------|
| **What** | Desired infrastructure (`.tf` files) | Actual infrastructure mapping |
| **Backup** | Git repository (continuous) | Manual/automated backups |
| **Loss impact** | Can be recreated from git history | Infrastructure becomes unmanaged |
| **Recovery** | `git checkout` | Restore from backup or import |

**Both are needed for complete recovery** - configuration defines what you want, state tracks what you have.

---

## 4. Manual Backup Procedures

### 4.1 Quick Manual Backup

**When to use:** Before any `just tf-apply` operation

```bash
# Simple timestamped copy
cp terraform/terraform.tfstate ~/backups/terraform-state-$(date +%Y%m%d-%H%M%S).tfstate
```

**Time:** <5 seconds
**Storage:** ~10-50 KB per backup

### 4.2 Manual Backup with Verification

**When to use:** Before major infrastructure changes or destructive operations

```bash
# Create backup directory if needed
mkdir -p ~/backups/terraform-state

# Backup with timestamp
BACKUP_FILE=~/backups/terraform-state/terraform-state-$(date +%Y%m%d-%H%M%S).tfstate
cp terraform/terraform.tfstate "$BACKUP_FILE"

# Verify backup created
ls -lh "$BACKUP_FILE"

# Verify backup is valid JSON
jq empty "$BACKUP_FILE" && echo "✓ Backup is valid JSON" || echo "✗ Backup is corrupted"

# Set restrictive permissions
chmod 600 "$BACKUP_FILE"

# Record backup details
echo "Backup created: $BACKUP_FILE"
echo "Original state: $(wc -c < terraform/terraform.tfstate) bytes"
echo "Backup state: $(wc -c < "$BACKUP_FILE") bytes"
```

**Verification steps:**
1. ✅ File created successfully
2. ✅ File size matches original
3. ✅ JSON is valid (not truncated)
4. ✅ Permissions are restrictive (600)

### 4.3 Manual Backup Before Critical Operations

**Critical operations requiring manual backup:**

```bash
# Before resource destruction
just tf-destroy-target <resource>  # First backup manually

# Before major apply operations
cp terraform/terraform.tfstate ~/backups/terraform-state-$(date +%Y%m%d).tfstate
just tf-apply

# Before state manipulation
tofu state rm <resource>  # First backup manually

# Before configuration changes affecting multiple resources
git diff terraform/  # Review changes first
cp terraform/terraform.tfstate ~/backups/terraform-state-$(date +%Y%m%d).tfstate
just tf-apply
```

### 4.4 Encrypted Manual Backup

**When to use:** Storing backups in untrusted locations (cloud storage, external drives)

```bash
# Backup and encrypt with age (project uses age for secrets)
AGE_PUBLIC_KEY="age1..."  # Your age public key
BACKUP_FILE=~/backups/terraform-state/terraform-state-$(date +%Y%m%d).tfstate

cp terraform/terraform.tfstate "$BACKUP_FILE"
age -r "$AGE_PUBLIC_KEY" -o "$BACKUP_FILE.age" "$BACKUP_FILE"
rm "$BACKUP_FILE"  # Remove unencrypted copy

# Verify encrypted backup
ls -lh "$BACKUP_FILE.age"

# Decrypt for verification (optional)
age -d -i ~/.config/sops/age/keys.txt "$BACKUP_FILE.age" > /tmp/verify.tfstate
jq empty /tmp/verify.tfstate && echo "✓ Encrypted backup is valid"
rm /tmp/verify.tfstate
```

**Time:** <10 seconds (encryption adds minimal overhead)

---

## 5. Automated Backup Setup (macOS - Time Machine)

### 5.1 Verify Time Machine Configuration

**Prerequisites:**
- Time Machine enabled and configured
- Backup disk connected or network destination configured

```bash
# Check Time Machine status
tmutil status

# Check if terraform directory is excluded
tmutil isexcluded ~/Share/git/mi-skam/infra/terraform

# Expected output: [Excluded]    no
# If "yes", terraform directory is excluded and won't be backed up
```

### 5.2 Include Terraform Directory in Backups

**Time Machine includes all files by default**, so no configuration is usually needed. However, verify:

```bash
# List Time Machine exclusions
tmutil listlocalsnapshots /
tmutil destinationinfo

# If terraform directory was previously excluded, remove exclusion
# (Requires Full Disk Access for Terminal)
sudo tmutil removeexclusion ~/Share/git/mi-skam/infra/terraform
```

### 5.3 Verify Automated Backups Working

```bash
# Check recent Time Machine backups
tmutil listlocalsnapshots /
tmutil latestbackup

# Verify terraform state is in latest backup
# (Requires browsing to Time Machine backup destination)
# Navigate to: /Volumes/<backup-disk>/Backups.backupdb/<machine>/Latest/...

# Or use tmutil compare (if supported)
tmutil compare /Users/plumps/Share/git/mi-skam/infra/terraform
```

### 5.4 Time Machine Backup Schedule

**Default schedule:** Hourly automatic backups (when backup disk is connected)

**Advantages:**
- ✅ Automatic - no manual intervention
- ✅ Hourly frequency - low RPO (1 hour data loss maximum)
- ✅ Point-in-time recovery - can browse historical backups
- ✅ macOS native - no additional software

**Limitations:**
- ⚠️ Requires backup disk connected (or network destination)
- ⚠️ Only backs up when Mac is powered on
- ⚠️ No backup verification (assumes Time Machine is reliable)

**Recommendation:** Use Time Machine as primary automated backup on macOS, supplement with manual backups before major operations.

---

## 6. Automated Backup Setup (Linux - rsync + cron)

### 6.1 Create Backup Script

Create backup script at `/usr/local/bin/backup-terraform-state.sh`:

```bash
#!/usr/bin/env bash
# Automated Terraform state backup script
# Runs daily via cron, keeps 30 daily backups

set -euo pipefail

# Configuration
STATE_FILE="/home/mi-skam/Share/git/mi-skam/infra/terraform/terraform.tfstate"
BACKUP_DIR="/home/mi-skam/backups/terraform-state"
RETENTION_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: State file not found: $STATE_FILE" >&2
    exit 1
fi

# Create timestamped backup
BACKUP_FILE="$BACKUP_DIR/terraform-state-$(date +%Y%m%d-%H%M%S).tfstate"
cp "$STATE_FILE" "$BACKUP_FILE"

# Verify backup
if ! jq empty "$BACKUP_FILE" 2>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: Backup is not valid JSON: $BACKUP_FILE" >&2
    rm "$BACKUP_FILE"
    exit 1
fi

# Set restrictive permissions
chmod 600 "$BACKUP_FILE"

# Log success
echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS: Backup created: $BACKUP_FILE ($(wc -c < "$BACKUP_FILE") bytes)"

# Clean up old backups (keep only last 30 days)
find "$BACKUP_DIR" -name "terraform-state-*.tfstate" -type f -mtime +$RETENTION_DAYS -delete

# Report backup count
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "terraform-state-*.tfstate" -type f | wc -l)
echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Total backups retained: $BACKUP_COUNT"

exit 0
```

Make script executable:

```bash
sudo chmod +x /usr/local/bin/backup-terraform-state.sh
```

### 6.2 Configure Cron Job

Add cron job for daily execution at 03:00 (after potential Terraform operations):

```bash
# Edit crontab
crontab -e

# Add backup job (runs daily at 03:00)
0 3 * * * /usr/local/bin/backup-terraform-state.sh >> /var/log/terraform-state-backup.log 2>&1
```

**Cron schedule explanation:**
- `0 3 * * *` - Every day at 03:00
- Runs after typical Terraform operations (daytime)
- Logs to `/var/log/terraform-state-backup.log`

### 6.3 Verify Cron Backup Working

```bash
# Test backup script manually
/usr/local/bin/backup-terraform-state.sh

# Check backup created
ls -lh ~/backups/terraform-state/

# Check backup log
tail /var/log/terraform-state-backup.log

# Verify cron job scheduled
crontab -l | grep backup-terraform-state

# Check cron execution (wait for scheduled time)
# After 03:00, check log:
tail /var/log/terraform-state-backup.log
```

### 6.4 Alternative: Rsync to Remote Location

For off-site backups, modify script to use rsync:

```bash
# Add to backup script (after local backup creation)
REMOTE_BACKUP_HOST="user@backup-server.example.com"
REMOTE_BACKUP_DIR="/backups/terraform-state"

# Sync backups to remote server
rsync -avz --delete \
    "$BACKUP_DIR/" \
    "$REMOTE_BACKUP_HOST:$REMOTE_BACKUP_DIR/"

echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: Backups synced to $REMOTE_BACKUP_HOST"
```

**Benefits:**
- ✅ Off-site backup protection
- ✅ Survives local disk failure
- ✅ Automatic synchronization

**Requirements:**
- SSH key authentication configured
- Remote backup server accessible

---

## 7. State Recovery Procedures

### 7.1 Restore from Automatic Backup (Recent Failure)

**When to use:** Terraform apply failed, need to rollback immediately

**Prerequisites:**
- `.tfstate.backup` exists
- Failure occurred <24 hours ago
- No subsequent applies

```bash
cd terraform/

# Verify backup exists
ls -lh terraform.tfstate.backup

# Backup current (potentially corrupted) state
cp terraform.tfstate terraform.tfstate.broken-$(date +%Y%m%d-%H%M%S)

# Restore from automatic backup
cp terraform.tfstate.backup terraform.tfstate

# Verify restoration
export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
tofu plan

# Expected output: Plan shows what needs to be re-applied (if apply was partial)
# Or: "No changes" (if apply didn't complete)
```

**Time:** <5 minutes
**Success criteria:** `tofu plan` succeeds without errors

For detailed procedure, see [rollback_procedures.md Section 5.1](rollback_procedures.md#51-partial-apply-state-inconsistency).

### 7.2 Restore from Manual Backup

**When to use:** Need to restore state from specific point in time

```bash
cd terraform/

# List available backups
ls -lht ~/backups/terraform-state/

# Identify backup to restore (by timestamp)
RESTORE_FROM=~/backups/terraform-state/terraform-state-20251030-140000.tfstate

# Verify backup is valid JSON
jq empty "$RESTORE_FROM" && echo "✓ Backup is valid"

# Backup current state (safety measure)
cp terraform.tfstate terraform.tfstate.before-restore-$(date +%Y%m%d-%H%M%S)

# Restore from manual backup
cp "$RESTORE_FROM" terraform.tfstate

# Verify restoration with plan
export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
tofu plan

# Review plan output carefully
# - If "No changes": State matches actual infrastructure (success)
# - If changes shown: State is from earlier point, infrastructure drifted
```

**Time:** <10 minutes (including verification)

### 7.3 Restore from Time Machine (macOS)

**When to use:** Local backups lost, need to restore from Time Machine

**Prerequisites:**
- Time Machine backup available
- Backup contains terraform directory

```bash
# Option A: Use Time Machine GUI
# 1. Open Finder, navigate to: ~/Share/git/mi-skam/infra/terraform
# 2. Click Time Machine icon in menu bar → "Enter Time Machine"
# 3. Browse to desired backup timestamp
# 4. Select terraform.tfstate
# 5. Click "Restore"

# Option B: Use tmutil command line
cd terraform/

# List available Time Machine snapshots
tmutil listlocalsnapshots /

# Restore from specific snapshot
# (Replace <snapshot-date> with actual snapshot timestamp)
tmutil restore -s <snapshot-date> terraform.tfstate

# Verify restoration
ls -lh terraform.tfstate
jq empty terraform.tfstate && echo "✓ Restored state is valid"

# Verify with Terraform plan
export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
tofu plan
```

**Time:** <15 minutes (including Time Machine navigation)

### 7.4 Restore from Encrypted Backup

**When to use:** Restoring from age-encrypted backup

```bash
cd terraform/

# List encrypted backups
ls -lh ~/backups/terraform-state/*.age

# Decrypt backup
ENCRYPTED_BACKUP=~/backups/terraform-state/terraform-state-20251030.tfstate.age
age -d -i ~/.config/sops/age/keys.txt "$ENCRYPTED_BACKUP" > terraform.tfstate.restored

# Verify decrypted state is valid
jq empty terraform.tfstate.restored && echo "✓ Decrypted state is valid"

# Backup current state
cp terraform.tfstate terraform.tfstate.before-restore-$(date +%Y%m%d-%H%M%S)

# Replace with restored state
mv terraform.tfstate.restored terraform.tfstate

# Verify with Terraform plan
export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
tofu plan
```

**Time:** <10 minutes

### 7.5 Sync State with Actual Infrastructure

After restoring state from backup, synchronize with actual infrastructure:

```bash
cd terraform/

# Refresh state from Hetzner API
export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
tofu refresh

# Plan to see current drift
tofu plan

# Expected outcomes:
# - "No changes": State matches reality (success)
# - Changes shown: Infrastructure drifted since backup, review carefully

# If changes are expected drift, apply to align
just tf-apply

# If changes are unexpected, investigate before applying
```

**Time:** <10 minutes (refresh + plan)

---

## 8. State Disaster Recovery

### 8.1 When to Use Disaster Recovery

**Use disaster recovery import procedures when:**

- ✅ State file completely lost (not in backups)
- ✅ All backups corrupted or inaccessible
- ✅ State file corruption cannot be repaired
- ✅ Rebuilding state from scratch is necessary

**Do NOT use if:**
- ❌ `.tfstate.backup` exists - Use Section 7.1 instead
- ❌ Manual backups available - Use Section 7.2 instead
- ❌ Time Machine/rsync backups available - Use Section 7.3 instead

**Warning:** Disaster recovery via import is time-consuming (1-2 hours) but does NOT cause data loss. Infrastructure continues running; you're just rebuilding Terraform's knowledge of it.

### 8.2 Prerequisites for State Reconstruction

Before starting disaster recovery, verify:

1. ✅ Hetzner API access (SOPS age key available)
2. ✅ Git configuration history intact (terraform/*.tf files)
3. ✅ Actual infrastructure is running (verify in Hetzner console)
4. ✅ You have 1-2 hours for reconstruction

### 8.3 Disaster Recovery Strategy

**Three-phase approach:**

1. **Phase 1: Inventory existing resources** (via Hetzner CLI)
2. **Phase 2: Import resources to state** (via `tofu import`)
3. **Phase 3: Verify state consistency** (via `tofu plan`)

### 8.4 Phase 1: Inventory Existing Resources

**Identify all Hetzner resources to import:**

```bash
# Set Hetzner API token
export HCLOUD_TOKEN="$(sops -d secrets/hetzner.yaml | grep hcloud_token | cut -d: -f2 | xargs)"

# List all servers
hcloud server list

# Expected output:
# ID         NAME                   STATUS    IPV4            IPV6                      DATACENTER
# 58455669   mail-1.prod.nbg        running   x.x.x.x         xxxx::xxxx:xxxx:xxxx      nbg1-dc3
# 59552733   syncthing-1.prod.hel   running   x.x.x.x         xxxx::xxxx:xxxx:xxxx      hel1-dc2
# 111301341  test-1.dev.nbg         running   x.x.x.x         xxxx::xxxx:xxxx:xxxx      nbg1-dc3

# List all networks
hcloud network list

# Expected output:
# ID        NAME      IP RANGE         SERVERS
# 10620750  homelab   10.0.0.0/16      3

# List all SSH keys
hcloud ssh-key list

# Expected output:
# ID        NAME              FINGERPRINT
# xxxxxx    homelab-hetzner   xx:xx:xx:xx:...

# Record all resource IDs - you'll need them for import
```

### 8.5 Phase 2: Import Resources to State

**Use existing import script as reference:**

The project includes `terraform/import.sh` with authoritative import commands. Use as template:

```bash
cd terraform/

# Verify Terraform initialized
tofu init

# Initialize new empty state if needed
# (Only if terraform.tfstate is completely missing)
if [ ! -f terraform.tfstate ]; then
    echo '{"version": 4, "terraform_version": "1.8.0", "resources": []}' > terraform.tfstate
fi

# Import network
tofu import hcloud_network.homelab 10620750

# Import network subnet
tofu import hcloud_network_subnet.homelab_subnet 10620750-10.0.0.0/24

# Import servers
tofu import hcloud_server.mail_prod_nbg 58455669
tofu import hcloud_server.syncthing_prod_hel 59552733
tofu import hcloud_server.test_dev_nbg 111301341

# Note: Resource IDs may differ if resources were recreated
# Use IDs from `hcloud server list` output, not import.sh
```

**Resource address reference:**

| Resource Type | Terraform Address | ID Format | Example |
|--------------|------------------|-----------|---------|
| Server | `hcloud_server.<name>` | Server ID (numeric) | `hcloud_server.mail_prod_nbg 58455669` |
| Network | `hcloud_network.<name>` | Network ID (numeric) | `hcloud_network.homelab 10620750` |
| Network Subnet | `hcloud_network_subnet.<name>` | Network ID + CIDR | `hcloud_network_subnet.homelab_subnet 10620750-10.0.0.0/24` |
| SSH Key | Data source (not imported) | Looked up by name | N/A - uses `data.hcloud_ssh_key.homelab` |

**Resource addresses from configuration:**

```bash
# List resources defined in configuration
grep -r "^resource" terraform/*.tf

# Expected output:
# terraform/network.tf:resource "hcloud_network" "homelab" {
# terraform/network.tf:resource "hcloud_network_subnet" "homelab_subnet" {
# terraform/servers.tf:resource "hcloud_server" "mail_prod_nbg" {
# terraform/servers.tf:resource "hcloud_server" "syncthing_prod_hel" {
# terraform/servers.tf:resource "hcloud_server" "test_dev_nbg" {
```

### 8.6 Finding Current Resource IDs

**If resources were deleted and recreated, import.sh contains outdated IDs.**

Find current IDs:

```bash
# Server IDs
hcloud server list -o noheader -o columns=id,name

# Network IDs
hcloud network list -o noheader -o columns=id,name

# Network subnet IDs (format: <network-id>-<cidr>)
hcloud network describe homelab -o format='{{.ID}}'
# Then use: <network-id>-10.0.0.0/24

# SSH key IDs (data source, no import needed)
hcloud ssh-key list -o noheader -o columns=id,name
```

### 8.7 Import Script for Disaster Recovery

Create import script with current IDs:

```bash
#!/usr/bin/env bash
# Disaster recovery import script
# Updates import.sh with current resource IDs

set -euo pipefail

export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
cd terraform/

echo "🔄 Importing Hetzner resources to Terraform state..."
echo ""

# Get current resource IDs from Hetzner API
NETWORK_ID=$(hcloud network describe homelab -o format='{{.ID}}')
MAIL_ID=$(hcloud server describe mail-1.prod.nbg -o format='{{.ID}}')
SYNCTHING_ID=$(hcloud server describe syncthing-1.prod.hel -o format='{{.ID}}')
TEST_ID=$(hcloud server describe test-1.dev.nbg -o format='{{.ID}}')

echo "Network: $NETWORK_ID"
echo "Mail server: $MAIL_ID"
echo "Syncthing server: $SYNCTHING_ID"
echo "Test server: $TEST_ID"
echo ""

# Import resources
echo "Importing network..."
tofu import hcloud_network.homelab "$NETWORK_ID"

echo "Importing network subnet..."
tofu import hcloud_network_subnet.homelab_subnet "${NETWORK_ID}-10.0.0.0/24"

echo "Importing servers..."
tofu import hcloud_server.mail_prod_nbg "$MAIL_ID"
tofu import hcloud_server.syncthing_prod_hel "$SYNCTHING_ID"
tofu import hcloud_server.test_dev_nbg "$TEST_ID"

echo ""
echo "✅ Import complete! Run 'tofu plan' to verify state matches configuration."
```

**Time:** 15-30 minutes for complete import

### 8.8 Phase 3: Verify State Consistency

After importing all resources, verify state matches configuration:

```bash
cd terraform/

# List imported resources
tofu state list

# Expected output (all resources present):
# hcloud_network.homelab
# hcloud_network_subnet.homelab_subnet
# hcloud_server.mail_prod_nbg
# hcloud_server.syncthing_prod_hel
# hcloud_server.test_dev_nbg

# Plan to verify no changes needed
export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
tofu plan

# Expected output: "No changes. Your infrastructure matches the configuration."

# If changes shown:
# - Review carefully - may indicate configuration drift
# - Common: server images, SSH keys (ignore_changes configured)
# - Unexpected changes: investigate before applying
```

**Success criteria:**
- ✅ All resources in `tofu state list`
- ✅ `tofu plan` shows "No changes" (or only expected ignore_changes)
- ✅ No errors from `tofu plan`

**Time:** 10-15 minutes (verification)

### 8.9 Complete Disaster Recovery Timeline

**Example timeline for full state reconstruction:**

| Phase | Activity | Time | Cumulative |
|-------|----------|------|------------|
| **Preparation** | Verify prerequisites, gather resource IDs | 10 min | 0:10 |
| **Phase 1** | Inventory resources via hcloud CLI | 10 min | 0:20 |
| **Phase 2** | Import all resources to state | 30 min | 0:50 |
| **Phase 3** | Verify state with `tofu plan` | 15 min | 1:05 |
| **Documentation** | Record import commands for future reference | 10 min | 1:15 |

**Total RTO:** 1-2 hours (state reconstruction only, no infrastructure changes)

---

## 9. Backup Verification Procedures

### 9.1 Weekly Backup Verification

**Frequency:** Every Monday
**Time:** <10 minutes

```bash
# Verify automatic backup exists
ls -lh terraform/terraform.tfstate.backup

# Verify backup is valid JSON
jq empty terraform/terraform.tfstate.backup && echo "✓ Automatic backup is valid"

# Verify manual/automated backups exist
ls -lht ~/backups/terraform-state/ | head -5

# Verify recent backups (within 7 days)
find ~/backups/terraform-state -name "*.tfstate" -mtime -7 -ls

# Count total backups
BACKUP_COUNT=$(find ~/backups/terraform-state -name "*.tfstate" | wc -l)
echo "Total backups: $BACKUP_COUNT"
```

### 9.2 Monthly Backup Integrity Check

**Frequency:** First Monday of month
**Time:** <20 minutes

```bash
# Verify all backups are valid JSON
for backup in ~/backups/terraform-state/*.tfstate; do
    if jq empty "$backup" 2>/dev/null; then
        echo "✓ Valid: $backup"
    else
        echo "✗ Corrupted: $backup"
    fi
done

# Check backup file sizes (should be consistent)
ls -lh ~/backups/terraform-state/*.tfstate | awk '{print $5, $9}'

# Verify backup count matches retention policy
# Expected: ~30 backups if daily automated backups enabled
BACKUP_COUNT=$(find ~/backups/terraform-state -name "*.tfstate" | wc -l)
if [ "$BACKUP_COUNT" -lt 7 ]; then
    echo "⚠ Warning: Only $BACKUP_COUNT backups (expected ≥7)"
else
    echo "✓ Backup count: $BACKUP_COUNT"
fi
```

### 9.3 Quarterly Recovery Test

**Frequency:** Every 3 months
**Time:** 1 hour
**System:** Non-production (test verification only)

**Procedure:**

1. **Create test state backup:**
   ```bash
   cp terraform/terraform.tfstate /tmp/terraform.tfstate.test-original
   ```

2. **Restore from backup (dry run):**
   ```bash
   # Select recent backup
   BACKUP_FILE=$(ls -t ~/backups/terraform-state/*.tfstate | head -1)

   # Restore to test location
   cp "$BACKUP_FILE" /tmp/terraform.tfstate.test-restored

   # Verify restored state is valid
   jq empty /tmp/terraform.tfstate.test-restored
   ```

3. **Compare original vs restored:**
   ```bash
   # Compare file sizes
   ls -lh /tmp/terraform.tfstate.test-original /tmp/terraform.tfstate.test-restored

   # Compare content (should differ only by timestamps)
   diff <(jq -S . /tmp/terraform.tfstate.test-original) \
        <(jq -S . /tmp/terraform.tfstate.test-restored)
   ```

4. **Verify plan with restored state (optional):**
   ```bash
   # DO NOT apply, only plan
   cd terraform/
   cp /tmp/terraform.tfstate.test-restored terraform.tfstate

   export TF_VAR_hcloud_token="$(just _get-hcloud-token)"
   tofu plan

   # Restore original state
   cp /tmp/terraform.tfstate.test-original terraform.tfstate
   ```

5. **Document results:**
   - Backup age tested
   - Verification success/failure
   - Any issues encountered

**Success criteria:**
- ✅ Backup restores successfully
- ✅ Restored state is valid JSON
- ✅ `tofu plan` succeeds (if tested)

---

## 10. Backup Schedule Recommendations

### 10.1 Backup Frequency

**Recommended schedule:**

| Backup Type | Frequency | Automation | Retention | Purpose |
|------------|-----------|------------|-----------|---------|
| **Automatic** (`.tfstate.backup`) | Every `tofu apply` | Terraform built-in | 1 (latest only) | Immediate rollback |
| **Manual** (before major changes) | Ad-hoc | Manual | Indefinite | Pre-change safety |
| **Automated** (Time Machine/rsync) | Daily (macOS) or Daily (Linux) | System | 30 days (configurable) | Regular disaster recovery |

### 10.2 When to Backup Manually

**Always backup manually before:**

- ✅ `just tf-destroy` or `just tf-destroy-target`
- ✅ `tofu state rm` or `tofu state mv`
- ✅ Major configuration changes (adding/removing servers)
- ✅ Terraform provider upgrades
- ✅ Any operation with `prevent_destroy` override

**Example:**

```bash
# Before destroying test server
cp terraform/terraform.tfstate ~/backups/terraform-state-before-destroy-test-$(date +%Y%m%d).tfstate
just tf-destroy-target hcloud_server.test_dev_nbg

# Before major apply
cp terraform/terraform.tfstate ~/backups/terraform-state-before-apply-$(date +%Y%m%d).tfstate
just tf-apply
```

### 10.3 Backup Retention Policy

**Recommended retention:**

```bash
# Automated backups (Linux rsync)
RETENTION_DAYS=30  # Keep 30 days of daily backups

# Manual backups (ad-hoc)
# Keep indefinitely, clean up manually when disk space needed

# Time Machine backups (macOS)
# Managed by Time Machine (automatic thinning based on disk space)
```

**Disk space estimate:**

| Backup Type | File Size | 30 backups | 365 backups |
|------------|-----------|------------|-------------|
| State file | ~10-50 KB | ~1.5 MB | ~18 MB |
| Encrypted state | ~15-60 KB | ~2 MB | ~22 MB |

**Recommendation:** State files are small, disk space is not a concern. Retain backups conservatively.

### 10.4 Optional: Git Backup Strategy

**When to use:** Additional off-site backup protection

**Setup:**

1. Create separate **private** git repository for state backups:
   ```bash
   # On backup server or git hosting service
   git init --bare terraform-state-backups.git
   ```

2. Create local git repository for state backups:
   ```bash
   mkdir -p ~/backups/terraform-state-git
   cd ~/backups/terraform-state-git
   git init

   # Add .gitignore for unencrypted state
   echo "*.tfstate" > .gitignore
   echo "!*.tfstate.age" >> .gitignore
   git add .gitignore
   git commit -m "Initial commit"

   # Add remote
   git remote add origin user@backup-server:terraform-state-backups.git
   ```

3. Backup and push after each apply:
   ```bash
   # After successful terraform apply
   cd ~/backups/terraform-state-git

   # Encrypt state
   age -r age1... -o terraform-state-$(date +%Y%m%d-%H%M%S).tfstate.age \
       ~/Share/git/mi-skam/infra/terraform/terraform.tfstate

   # Commit and push
   git add terraform-state-$(date +%Y%m%d-%H%M%S).tfstate.age
   git commit -m "Backup terraform state $(date +%Y%m%d-%H%M%S)"
   git push origin main
   ```

**Warnings:**
- ⚠️ **NEVER commit unencrypted state to git**
- ⚠️ **Use separate private repository** (not main infra repo)
- ⚠️ **Encrypt with age before committing**
- ⚠️ **Verify .gitignore prevents unencrypted commits**

**Benefits:**
- ✅ Off-site backup protection
- ✅ Git history for state versions
- ✅ Can restore from any commit

**Complexity:** High - only recommended for critical production environments

---

## 11. Troubleshooting

### 11.1 Backup File is Empty or Corrupted

**Symptoms:**
```bash
jq empty ~/backups/terraform-state/terraform-state-20251030.tfstate
# Output: parse error: Invalid numeric literal at line 1, column 1
```

**Diagnosis:**
```bash
# Check file size
ls -lh ~/backups/terraform-state/terraform-state-20251030.tfstate
# If 0 bytes: Backup failed to copy

# Check file contents
head ~/backups/terraform-state/terraform-state-20251030.tfstate
# If empty or truncated: Backup script error
```

**Solution:**
```bash
# Delete corrupted backup
rm ~/backups/terraform-state/terraform-state-20251030.tfstate

# Create new backup from current state
cp terraform/terraform.tfstate ~/backups/terraform-state/terraform-state-$(date +%Y%m%d-%H%M%S).tfstate

# Verify new backup
jq empty ~/backups/terraform-state/terraform-state-$(date +%Y%m%d-%H%M%S).tfstate
```

### 11.2 State Restore Shows Unexpected Changes

**Symptoms:**
```bash
tofu plan
# Output: Plan shows many unexpected changes (servers to be destroyed, recreated)
```

**Diagnosis:**
```bash
# Verify restored state is from correct timestamp
jq .serial terraform/terraform.tfstate
# Compare serial number with expected backup

# Check if infrastructure drifted
hcloud server list
# Verify servers exist and match configuration
```

**Solutions:**

**Option A: Drift is expected (state is old):**
```bash
# Refresh state to sync with reality
tofu refresh

# Re-plan to see current state
tofu plan
# Changes should be minimal now
```

**Option B: Wrong backup restored:**
```bash
# Restore from more recent backup
cp ~/backups/terraform-state/terraform-state-<newer-date>.tfstate terraform/terraform.tfstate

# Verify plan
tofu plan
```

**Option C: Configuration changed (not drift):**
```bash
# Check git history for configuration changes
git log --oneline -10 terraform/

# If configuration should match backup, revert config
git checkout <commit-hash> -- terraform/

# Re-plan
tofu plan
```

### 11.3 Import Fails with "Resource Already Exists"

**Symptoms:**
```bash
tofu import hcloud_server.mail_prod_nbg 58455669
# Output: Error: Resource already managed by Terraform
```

**Diagnosis:**
```bash
# Check if resource already in state
tofu state list | grep mail_prod_nbg
# Output: hcloud_server.mail_prod_nbg (already exists)
```

**Solution:**
```bash
# Resource already imported, no action needed
# Verify state matches reality
tofu plan
# Should show "No changes"

# If import is needed for different resource:
# - Remove old resource first: tofu state rm hcloud_server.mail_prod_nbg
# - Then import: tofu import hcloud_server.mail_prod_nbg <new-id>
```

### 11.4 Time Machine Backup Doesn't Include Terraform Directory

**Symptoms:**
```bash
tmutil isexcluded ~/Share/git/mi-skam/infra/terraform
# Output: [Excluded]    yes
```

**Diagnosis:**
```bash
# Check why excluded
tmutil listbackups
# Browse to backup destination, check if terraform directory missing
```

**Solution:**
```bash
# Remove exclusion
sudo tmutil removeexclusion ~/Share/git/mi-skam/infra/terraform

# Verify exclusion removed
tmutil isexcluded ~/Share/git/mi-skam/infra/terraform
# Output: [Excluded]    no

# Trigger manual backup to verify
tmutil startbackup

# Wait for backup to complete, verify terraform directory included
```

### 11.5 Automated Backup Script Not Running (Linux)

**Symptoms:**
```bash
# No recent backups
ls -lt ~/backups/terraform-state/ | head -5
# Last backup is >24 hours old

# Cron job not executing
tail /var/log/terraform-state-backup.log
# No recent log entries
```

**Diagnosis:**
```bash
# Check cron job exists
crontab -l | grep backup-terraform-state
# If empty: Cron job not configured

# Check cron service running
systemctl status cron

# Check script permissions
ls -l /usr/local/bin/backup-terraform-state.sh
# Should be executable (755 or 700)
```

**Solutions:**

**Cron job missing:**
```bash
crontab -e
# Add: 0 3 * * * /usr/local/bin/backup-terraform-state.sh >> /var/log/terraform-state-backup.log 2>&1
```

**Script not executable:**
```bash
sudo chmod +x /usr/local/bin/backup-terraform-state.sh
```

**Cron service not running:**
```bash
sudo systemctl start cron
sudo systemctl enable cron
```

**Test script manually:**
```bash
/usr/local/bin/backup-terraform-state.sh
# Check for errors in output
```

---

## 12. RTO/RPO Estimates

### 12.1 Recovery Time Objective (RTO)

**Time to restore Terraform state from backups:**

| Scenario | RTO | Notes |
|----------|-----|-------|
| Restore from `.tfstate.backup` | **<5 min** | Simple copy, immediate verification |
| Restore from manual backup | **<10 min** | Copy + verification |
| Restore from Time Machine (macOS) | **<15 min** | Navigate Time Machine + restore |
| Restore from rsync backup (Linux) | **<10 min** | Copy from backup location |
| Disaster recovery (import from scratch) | **<2 hours** | Find resource IDs, import all resources |

**RTO Breakdown (Manual Backup Restore):**
- Identify backup to restore: 2 minutes
- Copy backup to terraform.tfstate: 5 seconds
- Verify with `tofu plan`: 3 minutes
- Document restoration: 2 minutes
- **Total:** <10 minutes

**RTO Breakdown (Disaster Recovery Import):**
- Inventory resources via hcloud CLI: 10 minutes
- Import all resources to state: 30 minutes
- Verify with `tofu plan`: 15 minutes
- Document import commands: 10 minutes
- **Total:** 1-2 hours

### 12.2 Recovery Point Objective (RPO)

**Maximum data loss (time since last backup):**

| Backup Method | RPO | Notes |
|--------------|-----|-------|
| Automatic (`.tfstate.backup`) | **0** | Created immediately before each apply |
| Manual backup | **Varies** | Depends on when last manual backup was created |
| Time Machine (macOS) | **1 hour** | Hourly automatic backups |
| Rsync (Linux) | **24 hours** | Daily cron job at 03:00 |
| Git backup (optional) | **0** | Pushed after each apply |

**RPO Scenarios:**

**Best case:** State file lost immediately after `tofu apply`
- `.tfstate.backup` is current
- RPO: 0 (no data loss)

**Typical case:** State file lost during normal operations
- Time Machine backup is 1-2 hours old (macOS)
- Rsync backup is <24 hours old (Linux)
- RPO: 1-24 hours

**Worst case:** State file lost, all backups corrupted
- Must rebuild state via import
- RPO: 0 (configuration loss, but infrastructure intact)
- Time: 1-2 hours (reconstruction via import)

**Important:** State file loss does NOT cause infrastructure data loss. Servers continue running. You're only losing Terraform's mapping to resources, which can be rebuilt via import.

### 12.3 Comparison: State Loss vs Infrastructure Loss

| Aspect | State File Loss | Infrastructure Loss |
|--------|----------------|---------------------|
| **Impact** | Cannot manage infrastructure via Terraform | Services down, data potentially lost |
| **RTO** | <2 hours (import) | <8 hours (full rebuild) |
| **RPO** | 0 (config only, no data loss) | 1-24 hours (backup age) |
| **Recovery** | Import resources to state | Provision + deploy + restore data |
| **Criticality** | Medium (inconvenient, not service-impacting) | High (service outage) |

For infrastructure loss recovery, see [disaster_recovery.md Section 8](disaster_recovery.md#8-scenario-5-complete-vps-loss-datacenter-failure).

---

## 13. Testing Schedule

### 13.1 Weekly Verification (Every Monday)

**Time:** <10 minutes

- [ ] Verify automatic backup exists and is valid
- [ ] Check manual/automated backups from past 7 days
- [ ] Count total backups, verify retention policy working

### 13.2 Monthly Integrity Check (First Monday)

**Time:** <20 minutes

- [ ] Verify all backups are valid JSON (not corrupted)
- [ ] Check backup file sizes are consistent
- [ ] Review backup count matches retention policy
- [ ] Verify automated backup script running (Linux cron logs)

### 13.3 Quarterly Recovery Test (Every 3 Months)

**Time:** 1 hour
**Next test date:** [Record date here]

- [ ] Restore from backup to test location (dry run)
- [ ] Verify restored state is valid JSON
- [ ] Compare restored state to original
- [ ] Run `tofu plan` with restored state (optional)
- [ ] Document results and any issues

### 13.4 Annual Disaster Recovery Test (Once per Year)

**Time:** 2-3 hours
**Next test date:** [Record date here]

- [ ] Simulate complete state loss
- [ ] Rebuild state via import (use test environment or dry run)
- [ ] Verify all resources imported successfully
- [ ] Run `tofu plan` to verify "No changes"
- [ ] Document import commands for reference
- [ ] Update this runbook with lessons learned

---

## 14. Cross-References

### Related Runbooks

- **Infrastructure failures**: [disaster_recovery.md Section 5](disaster_recovery.md#5-scenario-2-infrastructure-provisioning-error-terraform-failure) - Strategic guidance for Terraform failures
- **Emergency rollback**: [rollback_procedures.md Section 5](rollback_procedures.md#5-scenario-2-failed-terraform-apply) - Tactical rollback from failed apply
- **Complete VPS loss**: [disaster_recovery.md Section 8](disaster_recovery.md#8-scenario-5-complete-vps-loss-datacenter-failure) - Full infrastructure rebuild
- **Project overview**: [CLAUDE.md](../../CLAUDE.md) - Infrastructure overview and commands

### External Documentation

- **OpenTofu state management**: https://opentofu.org/docs/language/state/
- **Terraform state locking**: https://opentofu.org/docs/language/state/locking/
- **Hetzner Cloud API**: https://docs.hetzner.com/cloud/
- **Restic backup**: https://restic.readthedocs.io/ (for application data backups)

### Key Files

- **State file**: `terraform/terraform.tfstate` (NEVER commit to git)
- **Automatic backup**: `terraform/terraform.tfstate.backup` (ephemeral)
- **Import script**: `terraform/import.sh` (reference for disaster recovery)
- **Justfile validation**: `justfile` lines 125-138 (`_validate-terraform-state` helper)
- **Drift detection**: `terraform/drift-detection.sh` (verify state consistency)

---

**End of Terraform State Backup and Recovery Runbook**

**Document Revision History:**

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-30 | 1.0 | Initial Terraform state backup runbook (I5.T6) | Claude |

---

**For questions or runbook updates**: Submit issue to project repository
