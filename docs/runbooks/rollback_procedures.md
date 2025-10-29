# Rollback Procedures Runbook

**Purpose**: Emergency rollback procedures for infrastructure failures
**Audience**: System operators responding to deployment failures or system incidents
**Last Updated**: 2025-10-29

---

## Table of Contents

1. [Quick Reference](#1-quick-reference)
2. [When to Use This Runbook](#2-when-to-use-this-runbook)
3. [Rollback Decision Tree](#3-rollback-decision-tree)
4. [Scenario 1: Failed NixOS Deployment](#4-scenario-1-failed-nixos-deployment)
5. [Scenario 2: Failed Terraform Apply](#5-scenario-2-failed-terraform-apply)
6. [Scenario 3: Failed Ansible Deployment](#6-scenario-3-failed-ansible-deployment)
7. [Scenario 4: Data Loss Recovery](#7-scenario-4-data-loss-recovery)
8. [Scenario 5: Complete System Loss](#8-scenario-5-complete-system-loss)
9. [Escalation Procedures](#9-escalation-procedures)
10. [RTO/RPO Summary](#10-rtorpo-summary)

---

## 1. Quick Reference

| Scenario | Quick Command | RTO | RPO |
|----------|--------------|-----|-----|
| NixOS boot failure | Boot previous generation from GRUB | <5 min | 0 |
| NixOS service failure | `sudo nixos-rebuild switch --rollback` | <5 min | 0 |
| Terraform partial apply | `cp terraform/.tfstate.backup terraform/terraform.tfstate && just tf-apply` | <15 min | 0 |
| Ansible service down | `git revert HEAD && just ansible-deploy` | <20 min | 0 |
| Data loss | `restic restore latest` | <4 hours | 1 hour |
| Complete VPS loss | `just tf-apply && restic restore && just ansible-deploy` | 4-8 hours | Varies |

---

## 2. When to Use This Runbook

**Use this runbook immediately when:**

1. ✅ **System Won't Boot**: NixOS/Darwin system fails to start after deployment
2. ✅ **Services Down**: Critical services (mail, Syncthing) stopped working after deployment
3. ✅ **Infrastructure Error**: Terraform apply caused unexpected resource changes or destruction
4. ✅ **Configuration Corruption**: Ansible deployment left system in inconsistent state
5. ✅ **Data Loss**: Accidental deletion, corrupted files, or missing data
6. ✅ **Complete Failure**: VPS deleted, hardware failure, or datacenter incident

**Do NOT use for:**

- ❌ Planned maintenance (use deployment procedures instead)
- ❌ Testing configuration changes (use `--check` mode)
- ❌ Investigating issues without confirmed failure (check logs first)

---

## 3. Rollback Decision Tree

```
Incident Detected
│
├─ System Won't Boot?
│  └─ YES → [Section 4.1: GRUB Rollback]
│
├─ Services Down After Deployment?
│  ├─ NixOS/Darwin? → [Section 4.2: Command Rollback]
│  ├─ Ansible? → [Section 6.1: Service Recovery]
│  └─ Both? → [Section 9: Escalation]
│
├─ Wrong Infrastructure Provisioned?
│  ├─ Partial apply? → [Section 5.1: State Recovery]
│  ├─ Wrong resources? → [Section 5.2: Configuration Revert]
│  └─ Resources destroyed? → [Section 5.3: Resource Recreation]
│
├─ Data Missing or Corrupted?
│  ├─ Recent (<1 hour)? → [Section 7.2: Restic Restore]
│  ├─ Configuration only? → [Section 7.3: Git Restore]
│  └─ Unknown age? → [Section 7.1: Identify Backup]
│
└─ VPS Completely Gone?
   └─ [Section 8: Complete System Loss]
```

---

## 4. Scenario 1: Failed NixOS Deployment

**Applicable Systems**: `xmsi` (x86_64 NixOS), `srv-01` (x86_64 NixOS, future)

**RTO**: <5 minutes
**RPO**: 0 (no data loss, configuration rollback only)

### 4.1 Boot Failure (GRUB Rollback)

**Symptom**: System won't boot after `nixos-rebuild switch`, stuck at boot screen, kernel panic, or systemd failure

**Prerequisites**: Physical or console access to machine (local keyboard or Hetzner console for srv-01)

#### Step 1: Access GRUB Boot Menu

```bash
# Reboot system (if partially running)
sudo reboot

# OR use physical reset button / Hetzner console reset

# At GRUB boot menu (press ESC or SHIFT during boot if not shown):
# You'll see entries like:
#   NixOS - Configuration 47 (2025-10-29)  <- FAILED
#   NixOS - Configuration 46 (2025-10-28)  <- PREVIOUS (working)
#   NixOS - Configuration 45 (2025-10-27)
```

**Time Estimate**: 1-2 minutes to access GRUB

#### Step 2: Select Previous Generation

```bash
# Use arrow keys to select previous generation (one before current)
# Press ENTER to boot

# System boots into previous working configuration
```

**Expected Behavior**: System boots normally into previous generation

**Time Estimate**: 30 seconds boot time

#### Step 3: Make Previous Generation Default

Once system is booted and accessible via SSH/console:

```bash
# Verify current generation (should show you're on older generation)
nixos-rebuild list-generations

# Expected output:
#   46   2025-10-28 14:30:15   (current)
#   47   2025-10-29 09:15:42

# Make current generation the default
sudo nixos-rebuild switch --rollback

# Expected output:
# building the system configuration...
# activating the configuration...
# setting up /etc...
```

**Time Estimate**: 1-2 minutes

#### Step 4: Verify System Functional

```bash
# Check system status
systemctl status

# Expected: "State: running" in green

# Check failed services
systemctl --failed

# Expected: 0 loaded units listed

# Verify key services
systemctl status sshd
systemctl status firewall

# Check system logs for errors
journalctl -p err -b

# Test network connectivity
ping -c 3 1.1.1.1
```

**Time Estimate**: 1 minute

#### Step 5: Document and Investigate

```bash
# Find failed generation logs
journalctl --list-boots

# Review failed deployment logs (boot -1 is previous boot with failed config)
journalctl -b -1 -p err

# Common boot failure causes:
# - Kernel module errors (hardware compatibility)
# - Systemd service dependency cycles
# - Missing disk mounts (fstab errors)
# - Network configuration errors preventing remote access

# Document failure
git commit --allow-empty -m "rollback(nixos): boot failure with config 47 - <root cause>"
```

**Total Time**: 4-5 minutes

### 4.2 Service Failure (Command Rollback)

**Symptom**: System boots but services are failing, degraded performance, or incorrect configuration after `nixos-rebuild switch`

**Prerequisites**: SSH access to system

#### Step 1: Immediate Rollback

```bash
# Rollback to previous generation (instant)
sudo nixos-rebuild switch --rollback

# Expected output:
# building the system configuration...
# activating the configuration...
# setting up /etc...
# reloading the following units: dbus.service
```

**Time Estimate**: 1-2 minutes

#### Step 2: Verify Services Recovered

```bash
# Check all services
systemctl status

# Expected: "State: running"

# Check specific failed services (example: sshd, firewall, nginx)
systemctl status sshd
systemctl status firewall

# Check for failed units
systemctl --failed

# Expected: 0 loaded units listed

# Review logs for errors
journalctl -xe -p err

# Test service functionality
# Example for SSH: ssh localhost 'echo test'
# Example for web: curl http://localhost
```

**Time Estimate**: 1 minute

#### Step 3: Identify Root Cause

```bash
# Compare configurations
nixos-rebuild list-generations

# Expected output:
#   46   2025-10-28 14:30:15   (current)
#   47   2025-10-29 09:15:42   <- ROLLED BACK

# View configuration diff
git log --oneline -5

# Review failed deployment logs
journalctl -u nixos-rebuild -S "10 minutes ago"

# Common service failure causes:
# - Port conflicts (service can't bind to port)
# - Missing dependencies (service starts before required service)
# - Configuration syntax errors (service fails to parse config)
# - Permission errors (service can't access files)
```

**Time Estimate**: 2 minutes

**Total Time**: 4-5 minutes

### 4.3 Configuration Error (Pre-Deployment Detection)

**Symptom**: `nix build` or `nixos-rebuild build` fails with syntax error, evaluation error, or build failure

**Prerequisites**: Development machine with flake access

#### Step 1: Identify Error

```bash
# Build configuration without activating
nix build .#nixosConfigurations.xmsi.config.system.build.toplevel

# Expected: Build error with stack trace

# Common errors:
# - Syntax errors (unclosed brackets, typos)
# - Undefined variables (misspelled option names)
# - Type errors (string provided instead of list)
# - Missing imports (module not found)
```

**Time Estimate**: Immediate (build fails)

#### Step 2: Fix or Revert

```bash
# Option A: Fix error immediately
# Edit configuration file with error
# Re-run build to verify fix

# Option B: Revert to working commit
git log --oneline -5

# Revert last commit
git revert HEAD

# OR reset to previous commit (CAUTION: loses commit)
git reset --hard HEAD~1

# Stage changes
git add .
```

**Time Estimate**: 1-5 minutes depending on fix complexity

#### Step 3: Verify Fix

```bash
# Rebuild to verify
nix build .#nixosConfigurations.xmsi.config.system.build.toplevel

# Expected: Build succeeds

# Run flake check
nix flake check

# Expected: All checks pass
```

**Time Estimate**: 2-3 minutes

**Total Time**: 3-8 minutes (no deployment occurred, no system downtime)

### 4.4 Verification Steps

**After any NixOS rollback, verify:**

1. **Boot Status**:
   ```bash
   # Check uptime (system should be running)
   uptime

   # Check boot time (should be recent if rebooted)
   systemd-analyze
   ```

2. **Service Health**:
   ```bash
   # No failed services
   systemctl --failed | grep -c "0 loaded units"

   # Critical services running
   for service in sshd firewall; do
     systemctl is-active $service || echo "FAILED: $service"
   done
   ```

3. **Network Connectivity**:
   ```bash
   # External connectivity
   ping -c 3 1.1.1.1

   # DNS resolution
   ping -c 3 google.com

   # SSH access (from remote machine)
   ssh user@xmsi 'echo connected'
   ```

4. **Logs Clean**:
   ```bash
   # No critical errors in last 10 minutes
   journalctl -p err -S "10 minutes ago"

   # Expected: Empty or only minor warnings
   ```

5. **Generation Confirmed**:
   ```bash
   # Verify on correct generation
   nixos-rebuild list-generations | grep current

   # Should show generation before failed one
   ```

---

## 5. Scenario 2: Failed Terraform Apply

**Applicable Systems**: Hetzner Cloud VPS (`mail-1.prod.nbg`, `syncthing-1.prod.hel`, `test-1.dev.nbg`)

**RTO**: <15 minutes
**RPO**: 0 (no data loss, infrastructure configuration only)

### 5.1 Partial Apply (State Inconsistency)

**Symptom**: `tofu apply` partially completed, some resources created/modified, then failed with API error or timeout

**Prerequisites**: Access to `terraform/` directory, Hetzner API token

#### Step 1: Assess Damage

```bash
# Navigate to terraform directory
cd terraform/

# Check current state
tofu state list

# Expected: List of resources (some may be in inconsistent state)

# Check for backup
ls -lh terraform.tfstate*

# Expected output:
# -rw-r--r-- 1 user user 15K Oct 29 09:30 terraform.tfstate
# -rw-r--r-- 1 user user 14K Oct 29 09:15 terraform.tfstate.backup

# Verify backup is from before failed apply
head -20 terraform.tfstate.backup | grep serial
```

**Time Estimate**: 1 minute

#### Step 2: Review Terraform Logs

```bash
# Check what was applied before failure
# (Review terminal output from failed apply)

# Common partial apply scenarios:
# - Server created but network attachment failed
# - Network created but route configuration failed
# - SSH key created but server association failed
```

**Time Estimate**: 1-2 minutes

#### Step 3: Decision Point

**Choose based on failure type:**

**Option A: State is corrupt or inconsistent**
- Multiple resources in unknown state
- State file shows errors
- Resources exist in Hetzner but not in state
→ Proceed to Step 4 (State Restore)

**Option B: State is consistent, just incomplete**
- Clear error message (e.g., "API rate limit")
- State accurately reflects what exists
- Can re-run apply safely
→ Skip to Step 6 (Re-apply)

#### Step 4: Restore State Backup

**⚠️ WARNING**: This overwrites current state. Only use if state is corrupt.

```bash
# Backup current state (just in case)
cp terraform.tfstate terraform.tfstate.corrupt

# Restore from backup
cp terraform.tfstate.backup terraform.tfstate

# Verify restoration
tofu state list

# Expected: Should match Hetzner console before failed apply
```

**Time Estimate**: 30 seconds

#### Step 5: Sync State with Reality

```bash
# Refresh state from Hetzner API
tofu refresh

# Expected output:
# Reading...
# hcloud_server.mail-1: Refreshing state...
# hcloud_server.syncthing-1: Refreshing state...
# ...

# Verify state matches Hetzner console
tofu show | grep -A 5 "hcloud_server"

# Check Hetzner console manually
hcloud server list
hcloud network list
```

**Time Estimate**: 2-3 minutes

#### Step 6: Re-apply Configuration

```bash
# Plan to see what will change
just tf-plan

# Expected: Should show only remaining changes from failed apply

# Review plan carefully - should NOT show unexpected changes

# Apply remaining changes
just tf-apply

# Monitor output carefully
# If fails again → [Section 9: Escalation]
```

**Time Estimate**: 5-8 minutes

#### Step 7: Verify Infrastructure

```bash
# List all servers
hcloud server list

# Expected: All 3 servers running (mail-1, syncthing-1, test-1)

# Check network configuration
hcloud network describe homelab

# Verify SSH keys
hcloud ssh-key list

# Test connectivity to all servers
for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
  ssh -o ConnectTimeout=5 root@$server 'hostname' || echo "FAILED: $server"
done
```

**Time Estimate**: 2-3 minutes

**Total Time**: 12-18 minutes (depending on apply time)

### 5.2 Wrong Configuration Applied

**Symptom**: `tofu apply` succeeded but created/modified wrong resources (wrong size, location, or configuration)

**Prerequisites**: Git repository with configuration history, Hetzner API token

#### Step 1: Identify Wrong Changes

```bash
# Check current infrastructure state
hcloud server list -o columns=name,type,datacenter,status

# Compare with expected state
cat terraform/servers.tf

# Example wrong changes:
# - Server type CPX31 instead of CAX21 (x86 instead of ARM64)
# - Server in FSN datacenter instead of NBG
# - Wrong disk size or image
```

**Time Estimate**: 1-2 minutes

#### Step 2: Assess Impact

**Minor configuration change (no data loss)**:
- Server type/size changed
- Network configuration changed
- Firewall rules changed
→ Can revert configuration and re-apply (proceed to Step 3)

**Major change (potential data loss)**:
- Server destroyed and recreated
- Disk detached/deleted
- Network removed
→ [Section 7: Data Loss Recovery] FIRST, then proceed

#### Step 3: Revert Configuration

```bash
# View recent commits
git log --oneline -10 terraform/

# Identify commit with wrong configuration
# Example: "abc1234 feat(terraform): increase mail server size"

# Revert commit
git revert abc1234

# OR reset to previous commit (CAUTION: loses commits)
git reset --hard HEAD~1

# Stage changes
git add terraform/
```

**Time Estimate**: 1-2 minutes

#### Step 4: Plan Reversion

```bash
# Generate plan
just tf-plan

# Review plan carefully:
# - Should show reverting changes (e.g., CPX31 → CAX21)
# - Check for "forces replacement" messages (means recreation)
# - If server recreation: data loss will occur

# ⚠️ IF PLAN SHOWS SERVER RECREATION:
# STOP HERE → Backup data first [Section 7]
```

**Time Estimate**: 2-3 minutes

#### Step 5: Apply Reversion

```bash
# Apply corrected configuration
just tf-apply

# Monitor output:
# - Watch for "forces replacement" (server recreation)
# - Note which resources are modified vs replaced
# - If errors occur → [Section 9: Escalation]
```

**Time Estimate**: 5-8 minutes

#### Step 6: Verify Correct Configuration

```bash
# Check all servers match expected configuration
hcloud server list -o columns=name,type,datacenter,status

# Verify against configuration
cat terraform/servers.tf | grep -A 10 "resource.*hcloud_server"

# Test connectivity
for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
  ssh root@$server 'hostname && cat /etc/os-release | head -3'
done

# Check services still running
just ansible-ping
```

**Time Estimate**: 2-3 minutes

**Total Time**: 11-18 minutes

### 5.3 Resource Destruction

**Symptom**: `tofu apply` destroyed resources (server deleted, network removed, data lost)

**Prerequisites**: Terraform state backup, recent data backups (if available)

**⚠️ CRITICAL**: This scenario involves potential data loss. Follow carefully.

#### Step 1: Stop Immediately

```bash
# If apply is still running, cancel it
# Press Ctrl+C

# DO NOT run additional terraform commands yet
```

**Time Estimate**: Immediate

#### Step 2: Assess Data Loss

```bash
# Check what was destroyed
git diff HEAD~1 terraform/

# Review terraform output for destroy actions
# Look for: "Destroy complete! Resources: X destroyed"

# Check Hetzner console
hcloud server list
hcloud network list

# Identify missing resources:
# - Servers deleted: DATA LOSS likely
# - Networks deleted: No data loss (config only)
# - SSH keys deleted: No data loss (can recreate)
```

**Time Estimate**: 2-3 minutes

#### Step 3: Decision Point

**If servers were destroyed:**
→ [Section 8: Complete System Loss] (server rebuild with data restore)

**If only network/keys destroyed (servers intact):**
→ Continue to Step 4 (restore state and re-create)

#### Step 4: Restore Terraform State

```bash
cd terraform/

# Restore state from backup
cp terraform.tfstate.backup terraform.tfstate

# Verify state has destroyed resources
tofu state list

# Should show resources that were destroyed
```

**Time Estimate**: 1 minute

#### Step 5: Revert Configuration

```bash
# Find commit that caused destruction
git log --oneline -10 terraform/

# Revert destructive commit
git revert <commit-hash>

# OR reset to before destruction
git reset --hard HEAD~1

# Stage changes
git add terraform/
```

**Time Estimate**: 1-2 minutes

#### Step 6: Re-create Destroyed Resources

```bash
# Plan recreation
just tf-plan

# Should show creating destroyed resources

# Apply
just tf-apply

# Monitor: Should recreate networks, keys, etc.
```

**Time Estimate**: 5-10 minutes

#### Step 7: Restore Data (If Servers Recreated)

If servers were destroyed and recreated, data restore is required:

```bash
# Follow [Section 7.2: Restic Restore] for each affected server

# Then follow [Section 6: Ansible Deployment] to reconfigure services
```

**Time Estimate**: 2-4 hours (depending on data volume)

**Total Time**: 15 minutes (infrastructure only) to 4+ hours (with data restore)

### 5.4 Verification Steps

**After any Terraform rollback, verify:**

1. **Infrastructure State Consistent**:
   ```bash
   # Terraform state matches reality
   just tf-plan

   # Expected: "No changes. Your infrastructure matches the configuration."

   # State list matches Hetzner
   tofu state list | wc -l
   hcloud server list | wc -l
   # Counts should match (adjust for headers)
   ```

2. **All Servers Present**:
   ```bash
   # Check expected servers exist
   hcloud server list -o columns=name,status

   # Expected output:
   # NAME                  STATUS
   # mail-1.prod.nbg      running
   # syncthing-1.prod.hel running
   # test-1.dev.nbg       running
   ```

3. **Network Configuration Correct**:
   ```bash
   # Check private network
   hcloud network describe homelab

   # Verify server network interfaces
   for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
     hcloud server describe $server | grep -A 5 "Private Net"
   done
   ```

4. **SSH Access Works**:
   ```bash
   # Test SSH to all servers
   for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
     ssh -o ConnectTimeout=5 root@$server 'hostname' || echo "FAILED: $server"
   done

   # Expected: Each server returns its hostname
   ```

5. **Firewall Rules Applied**:
   ```bash
   # Check firewall configuration
   hcloud firewall list

   # Verify rules
   hcloud firewall describe <firewall-name>
   ```

6. **DNS Resolves Correctly**:
   ```bash
   # Test DNS resolution (if DNS configured)
   host mail-1.prod.nbg
   host syncthing-1.prod.hel

   # Ping public IPs
   hcloud server list -o columns=name,ipv4 | tail -n +2 | while read name ip; do
     ping -c 2 $ip || echo "FAILED: $name ($ip)"
   done
   ```

---

## 6. Scenario 3: Failed Ansible Deployment

**Applicable Systems**: Hetzner Cloud VPS (`mail-1.prod.nbg`, `syncthing-1.prod.hel`, `test-1.dev.nbg`)

**RTO**: <20 minutes
**RPO**: 0 (no data loss, configuration management only)

### 6.1 Service Down After Deployment

**Symptom**: Ansible playbook completed but services stopped, not responding, or returning errors

**Prerequisites**: Git repository, Ansible inventory, SSH access to affected servers

#### Step 1: Identify Failed Services

```bash
# Check which servers/services are affected
just ansible-ping

# Expected failures for affected servers

# SSH to affected server
ssh root@<server-name>

# Check service status
systemctl --failed

# Expected output: List of failed units

# Check specific service
systemctl status <service-name>

# Example:
# systemctl status postfix  # for mail-1
# systemctl status syncthing  # for syncthing-1
```

**Time Estimate**: 2-3 minutes

#### Step 2: Quick Service Restart Attempt

```bash
# Try restarting failed service
sudo systemctl restart <service-name>

# Check status
systemctl status <service-name>

# If service starts successfully:
# - Issue may be transient
# - Verify service functionality
# - Check logs for errors: journalctl -u <service-name> -n 50

# If service fails to start:
# - Configuration error likely
# - Proceed to Step 3 (rollback)
```

**Time Estimate**: 1-2 minutes

#### Step 3: Revert Ansible Configuration

```bash
# Exit server, return to local machine

# View recent Ansible changes
git log --oneline -10 ansible/

# Identify problematic commit
# Example: "def5678 feat(ansible): update mail server config"

# Revert commit
git revert def5678

# OR reset to previous commit
git reset --hard HEAD~1

# Stage changes
git add ansible/
```

**Time Estimate**: 1-2 minutes

#### Step 4: Re-deploy Previous Configuration

```bash
# Deploy to affected server only
just ansible-deploy-env prod --limit mail-1.prod.nbg

# OR deploy to specific host group
just ansible-deploy-env prod --limit mail_servers

# Monitor output:
# - Watch for "changed" vs "ok" tasks
# - Note any task failures
# - Check for "failed=0" at end

# Expected output:
# PLAY RECAP ***************
# mail-1.prod.nbg  : ok=45  changed=8  unreachable=0  failed=0
```

**Time Estimate**: 5-10 minutes

#### Step 5: Verify Service Recovery

```bash
# SSH back to server
ssh root@<server-name>

# Check service running
systemctl status <service-name>

# Expected: "active (running)" in green

# Check logs for errors
journalctl -u <service-name> -n 50

# Test service functionality
# Example for mail:
# echo "test" | mail -s "test" user@example.com

# Example for Syncthing:
# curl http://localhost:8384/
```

**Time Estimate**: 2-3 minutes

#### Step 6: Verify Idempotency

```bash
# Re-run Ansible in check mode
just ansible-deploy-env prod --limit <server-name> --check

# Expected output: changed=0 (all tasks "ok", none "changed")

# If tasks show "changed":
# - Configuration drift exists
# - Re-run without --check to converge
# - Investigate why drift occurred
```

**Time Estimate**: 2-3 minutes

**Total Time**: 13-23 minutes

### 6.2 Configuration Corruption

**Symptom**: Ansible playbook completed but configuration files corrupted, services misconfigured, or system in inconsistent state

**Prerequisites**: Git repository, Ansible inventory, SSH access

#### Step 1: Identify Corrupted Configuration

```bash
# SSH to affected server
ssh root@<server-name>

# Check for syntax errors in configs
# Example for Postfix:
postfix check

# Example for nginx:
nginx -t

# Example for SSH:
sshd -t

# Common corruption signs:
# - Syntax errors in config files
# - Missing required directives
# - File permissions incorrect
# - Symlinks broken
```

**Time Estimate**: 2-3 minutes

#### Step 2: Backup Corrupted Configuration

```bash
# On server: backup current (corrupted) config
sudo cp /etc/<service>/<config-file> /tmp/<config-file>.corrupted

# Example:
sudo cp /etc/postfix/main.cf /tmp/main.cf.corrupted

# This allows comparison later to identify what went wrong
```

**Time Estimate**: 1 minute

#### Step 3: Revert Ansible Roles/Templates

```bash
# On local machine: view recent changes to Ansible roles
git log --oneline -10 ansible/roles/

# Identify commit that corrupted config
git show <commit-hash> ansible/roles/<role-name>/

# Revert specific role changes
git revert <commit-hash>

# OR revert all Ansible changes
git revert HEAD

# Stage changes
git add ansible/
```

**Time Estimate**: 2-3 minutes

#### Step 4: Re-deploy Clean Configuration

```bash
# Deploy to affected server
just ansible-deploy-env prod --limit <server-name>

# Monitor for template rendering:
# - Look for "TASK [<role> : Template <config-file>]"
# - Should show "changed" (overwriting corrupted config)

# Expected output:
# TASK [common : Template sshd_config] ***
# changed: [mail-1.prod.nbg]
```

**Time Estimate**: 5-10 minutes

#### Step 5: Verify Configuration Fixed

```bash
# SSH to server
ssh root@<server-name>

# Validate configuration syntax
postfix check  # or relevant service check command
nginx -t
sshd -t

# Compare with corrupted version
diff /etc/<service>/<config-file> /tmp/<config-file>.corrupted

# Restart service with fixed config
sudo systemctl restart <service-name>

# Check status
systemctl status <service-name>

# Expected: "active (running)"
```

**Time Estimate**: 2-3 minutes

#### Step 6: Verify System Consistency

```bash
# Check file permissions
ls -la /etc/<service>/

# Check for broken symlinks
find /etc/<service>/ -type l -xtype l

# Expected: No output (no broken links)

# Verify all configuration files present
# (Compare with Ansible role file list)
```

**Time Estimate**: 1-2 minutes

**Total Time**: 13-22 minutes

### 6.3 Partial Application

**Symptom**: Ansible playbook failed mid-execution, some tasks completed, others skipped or failed

**Prerequisites**: Ansible output from failed run, SSH access

#### Step 1: Analyze Failure Point

```bash
# Review Ansible output from failed run
# Identify:
# - Which task failed (task name)
# - Which hosts failed vs succeeded
# - Error message

# Example failure output:
# TASK [backup : Install restic] ***
# fatal: [mail-1.prod.nbg]: FAILED! => {"msg": "apt cache update failed"}

# Note task name and error
```

**Time Estimate**: 1-2 minutes

#### Step 2: Check Server State

```bash
# SSH to affected server
ssh root@<server-name>

# Check if partial changes were applied
# Example: If playbook failed during package install

# List recently installed packages
apt list --installed | grep -i <package-name>

# Check for half-configured services
systemctl list-units --state=failed

# Expected: May show services in inconsistent state
```

**Time Estimate**: 2-3 minutes

#### Step 3: Decision Point

**Option A: Safe to re-run (idempotent failure)**
- Network timeout, temporary API error
- Package download failed
- No configuration changes were made yet
→ Proceed to Step 4 (Re-run playbook)

**Option B: Dangerous to re-run (non-idempotent failure)**
- Database migration failed partway
- File modifications in progress
- Service restart caused cascade failure
→ Proceed to Step 5 (Manual cleanup first)

#### Step 4: Re-run Ansible Playbook

```bash
# For idempotent failures: simply re-run
just ansible-deploy-env prod --limit <server-name>

# Ansible will:
# - Skip tasks already in desired state (ok)
# - Complete failed/skipped tasks (changed)
# - Resume from failure point

# Monitor output:
# - Previously completed tasks: "ok"
# - Previously failed task: "changed" (should succeed now)
```

**Time Estimate**: 5-10 minutes

**Skip to Step 6 (Verify)**

#### Step 5: Manual Cleanup (For Non-Idempotent Failures)

```bash
# SSH to server
ssh root@<server-name>

# Example cleanup actions:

# Remove partially installed packages
sudo apt remove --purge <package-name>
sudo apt autoremove

# Restore backed-up config files
sudo cp /etc/<service>/<config-file>.bak /etc/<service>/<config-file>

# Reset service state
sudo systemctl reset-failed <service-name>

# Clean up temp files
sudo rm -rf /tmp/<playbook-temp-files>

# After cleanup: exit and re-run playbook
```

**Time Estimate**: 5-10 minutes (depends on cleanup needed)

```bash
# Re-run playbook after cleanup
just ansible-deploy-env prod --limit <server-name>
```

**Time Estimate**: 5-10 minutes

#### Step 6: Verify Complete Application

```bash
# Check playbook completion
# Expected output:
# PLAY RECAP ***************
# mail-1.prod.nbg  : ok=45  changed=12  unreachable=0  failed=0

# SSH to server
ssh root@<server-name>

# Verify all expected services running
systemctl status <service1> <service2> <service3>

# Check no failed units
systemctl --failed

# Expected: 0 loaded units

# Test idempotency
just ansible-deploy-env prod --limit <server-name> --check

# Expected: changed=0
```

**Time Estimate**: 3-5 minutes

**Total Time**: 16-35 minutes (depending on cleanup needs)

### 6.4 Verification Steps

**After any Ansible rollback, verify:**

1. **Playbook Completes Successfully**:
   ```bash
   # Re-run playbook
   just ansible-deploy-env prod

   # Expected output (for each host):
   # PLAY RECAP ***************
   # mail-1.prod.nbg     : ok=X  changed=0  unreachable=0  failed=0
   # syncthing-1.prod.hel: ok=X  changed=0  unreachable=0  failed=0
   # test-1.dev.nbg      : ok=X  changed=0  unreachable=0  failed=0
   ```

2. **All Services Running**:
   ```bash
   # Check services on each server
   for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
     echo "=== $server ==="
     ssh root@$server "systemctl --failed"
   done

   # Expected: "0 loaded units listed" for each server
   ```

3. **Configuration Valid**:
   ```bash
   # Validate configs on each server
   ssh root@mail-1.prod.nbg "postfix check && echo 'Postfix config OK'"
   ssh root@syncthing-1.prod.hel "systemctl status syncthing --no-pager"
   ```

4. **Idempotency Verified**:
   ```bash
   # Run in check mode (dry-run)
   just ansible-deploy-env prod --check

   # Expected: changed=0 for all hosts
   # If tasks show "changed", configuration drift exists
   ```

5. **Connectivity Test**:
   ```bash
   # Ping all servers
   just ansible-ping

   # Expected: SUCCESS for all hosts
   ```

6. **Service Functionality**:
   ```bash
   # Test actual service functionality
   # Example for mail:
   ssh root@mail-1.prod.nbg "echo 'test' | mail -s 'rollback test' user@example.com"

   # Example for Syncthing:
   ssh root@syncthing-1.prod.hel "curl -s http://localhost:8384/ | grep -i syncthing"
   ```

---

## 7. Scenario 4: Data Loss Recovery

**Applicable Systems**: All systems (NixOS, Darwin, Hetzner VPS)

**RTO**: <4 hours (for data restore from backup)
**RPO**: 1 hour (assuming daily backups, data loss between last backup and incident)

### 7.1 Identify Backup Source

**Symptom**: Data missing, files deleted, database corrupted, or application data lost

**Prerequisites**: Knowledge of what data was lost, when it was last known good

#### Step 1: Determine Data Type

```bash
# Identify what type of data was lost:

# Configuration files (Nix/Terraform/Ansible)?
# → Source: Git repository
# → RPO: Last commit (typically minutes to hours)
# → RTO: <5 minutes

# Application data (mail, databases, user files)?
# → Source: Restic backup to Hetzner Storage Box
# → RPO: Last backup (daily = ~1-24 hours)
# → RTO: 1-4 hours (depends on data volume)

# System state (packages, system config)?
# → Source: Nix generations or system snapshots
# → RPO: Last deployment (hours to days)
# → RTO: <30 minutes

# Development work (uncommitted code)?
# → Source: Local IDE cache, file history, or lost
# → RPO: Last save/commit
# → RTO: May be unrecoverable
```

**Time Estimate**: 2-5 minutes

#### Step 2: Determine Loss Timeline

```bash
# When was data last known good?

# Check file modification times
ls -lt /path/to/lost/data

# Check git history
git log --oneline --since="2 days ago" -- path/to/config

# Check backup history
# (See Step 3 for restic commands)

# Estimate RPO:
# - Last backup: 2025-10-29 03:00
# - Data lost: 2025-10-29 10:00
# - RPO: 7 hours of data loss
```

**Time Estimate**: 2-3 minutes

#### Step 3: Check Backup Availability

```bash
# For configuration (Git):
git log --oneline -20
git reflog  # Shows even reverted commits

# For application data (Restic):
# SSH to affected server
ssh root@<server-name>

# Check restic backup configuration
cat /etc/restic/backup-config

# List available backups
export RESTIC_REPOSITORY="<repository-url>"
export RESTIC_PASSWORD="<password>"
restic snapshots

# Expected output:
# ID        Time                 Host            Tags        Paths
# ----------------------------------------------------------------------
# 4a3b2c1d  2025-10-29 03:00:15  mail-1.prod.nbg backup      /var/mail
# 5d4e3f2a  2025-10-28 03:00:10  mail-1.prod.nbg backup      /var/mail
# 6e5f4g3b  2025-10-27 03:00:05  mail-1.prod.nbg backup      /var/mail

# Note: Restic backup setup is in ansible/roles/backup/
```

**Time Estimate**: 3-5 minutes

#### Step 4: Select Recovery Method

Based on data type and backup availability:

| Data Type | Backup Source | Procedure |
|-----------|--------------|-----------|
| Configuration files | Git history | [Section 7.3: Git Restore](#73-restore-from-git-history) |
| Application data | Restic backup | [Section 7.2: Restic Restore](#72-restore-from-restic-backup) |
| System state | Nix generations | [Section 4: NixOS Rollback](#4-scenario-1-failed-nixos-deployment) |
| Uncommitted code | Lost | Manual recreation (no backup) |

**Time Estimate**: 1 minute (decision)

**Total Time**: 8-14 minutes (assessment phase, before actual restore)

### 7.2 Restore from Restic Backup

**Scenario**: Application data lost (mail, database, user files) on Hetzner VPS

**Prerequisites**: Restic backup exists, SSH access to server, Hetzner Storage Box credentials

**⚠️ WARNING**: This will overwrite current data. Ensure you're restoring to correct location.

#### Step 1: Verify Backup Exists

```bash
# SSH to affected server
ssh root@<server-name>

# Load restic configuration
source /etc/restic/backup-config

# OR manually set variables
export RESTIC_REPOSITORY="sftp:uXXXXXX@uXXXXXX.your-storagebox.de:/backups/<server-name>"
export RESTIC_PASSWORD="<storage-box-password>"

# List snapshots
restic snapshots

# Expected output: List of backup snapshots with dates

# Identify snapshot to restore
# - Most recent: "latest"
# - Specific snapshot: copy ID from list
```

**Time Estimate**: 2-3 minutes

#### Step 2: Prepare Restore Location

```bash
# Stop services using the data (prevents corruption during restore)
sudo systemctl stop <service-name>

# Example for mail server:
sudo systemctl stop postfix
sudo systemctl stop dovecot

# Backup current (possibly corrupted) data
sudo mv /var/mail /var/mail.corrupted-$(date +%Y%m%d-%H%M%S)

# Create restore target directory
sudo mkdir -p /var/mail
```

**Time Estimate**: 1-2 minutes

#### Step 3: Restore Data

```bash
# Restore from latest snapshot
restic restore latest --target /

# OR restore specific snapshot
restic restore 4a3b2c1d --target /

# OR restore specific files/directories
restic restore latest --target / --include /var/mail/user@example.com

# Monitor progress:
# restoring <snapshot 4a3b2c1d> to /
# [0:05] 25.00% 127 files 2.5 GiB, total 508 files 10 GiB
```

**Time Estimate**: 10 minutes to 4 hours (depends on data volume)

**Data Volume Estimates:**
- Mail server (10GB mailboxes): ~30 minutes
- Syncthing files (100GB): ~2 hours
- Small database (<1GB): ~5 minutes

#### Step 4: Verify Data Integrity

```bash
# Check restored files exist
ls -lh /var/mail/

# Check file counts match backup
find /var/mail -type f | wc -l

# Compare with snapshot
restic ls latest --long /var/mail | wc -l

# Check file permissions
ls -la /var/mail/

# Fix permissions if needed
sudo chown -R mail:mail /var/mail
sudo chmod -R 0600 /var/mail/*/
```

**Time Estimate**: 2-5 minutes

#### Step 5: Restart Services

```bash
# Restart services
sudo systemctl start postfix
sudo systemctl start dovecot

# Check status
systemctl status postfix
systemctl status dovecot

# Expected: "active (running)" in green

# Check logs for errors
journalctl -u postfix -n 50
journalctl -u dovecot -n 50
```

**Time Estimate**: 1-2 minutes

#### Step 6: Verify Service Functionality

```bash
# Test service with restored data

# Example for mail server:
# Send test email
echo "Restore test" | mail -s "Test after restore" user@example.com

# Check mail queue
mailq

# Verify mailbox accessible
# (Try connecting with mail client)

# Example for Syncthing:
curl http://localhost:8384/
# Check web interface shows restored files
```

**Time Estimate**: 5-10 minutes

#### Step 7: Document Data Loss

```bash
# Calculate actual data loss (RPO)
# - Last backup: 2025-10-29 03:00
# - Incident: 2025-10-29 10:00
# - Data loss: 7 hours of data

# Document in incident log
echo "Data restore: $(date)" >> /var/log/incident-log.txt
echo "Backup snapshot: <snapshot-id>" >> /var/log/incident-log.txt
echo "RPO: 7 hours" >> /var/log/incident-log.txt

# Notify users if needed (e.g., email loss)
```

**Time Estimate**: 2-5 minutes

**Total Time**: 30 minutes to 4 hours (depending on data volume)

### 7.3 Restore from Git History

**Scenario**: Configuration files lost, deleted, or corrupted

**Prerequisites**: Git repository with configuration history

#### Step 1: Identify Lost Configuration

```bash
# What configuration was lost?

# Check git status
git status

# Expected: May show deleted files or modified files

# Example:
# deleted: ansible/roles/mail/templates/main.cf.j2
# modified: hosts/xmsi/configuration.nix
```

**Time Estimate**: 1 minute

#### Step 2: Find File in Git History

```bash
# Search git history for file
git log --oneline --follow -- path/to/file

# Expected output:
# abc1234 feat(mail): update postfix config
# def5678 fix(mail): correct relay settings
# ghi9012 chore(mail): initial mail server config

# View file content from specific commit
git show abc1234:path/to/file

# OR view diff
git show abc1234
```

**Time Estimate**: 2-3 minutes

#### Step 3: Restore File

```bash
# Restore specific file from commit
git checkout abc1234 -- path/to/file

# OR restore file from last commit (HEAD)
git checkout HEAD -- path/to/file

# OR restore entire directory
git checkout abc1234 -- ansible/roles/mail/

# Stage restored file
git add path/to/file
```

**Time Estimate**: 1 minute

#### Step 4: Verify Restoration

```bash
# Check file restored correctly
cat path/to/file

# Compare with git history
git diff HEAD path/to/file

# Expected: Shows changes (if restored from older commit)

# Verify syntax (if applicable)
# Example for Nix:
nix flake check

# Example for Ansible templates:
# (Validated during deployment)
```

**Time Estimate**: 2-3 minutes

#### Step 5: Deploy Restored Configuration

```bash
# Deploy based on configuration type:

# For NixOS:
just nixos-deploy <hostname>

# For Darwin:
just darwin-deploy <hostname>

# For Ansible:
just ansible-deploy-env prod

# Monitor deployment for errors
```

**Time Estimate**: 5-15 minutes (depending on deployment type)

#### Step 6: Document Restoration

```bash
# Commit restoration
git commit -m "restore(<component>): recover lost configuration from <commit>"

# Example:
git commit -m "restore(mail): recover postfix config from abc1234"

# Push changes
git push
```

**Time Estimate**: 1 minute

**Total Time**: 12-26 minutes

**RPO**: Depends on last commit (typically 0 data loss for committed configs)

---

## 8. Scenario 5: Complete System Loss

**Applicable Systems**: Hetzner Cloud VPS (complete server loss or hardware failure)

**RTO**: 4-8 hours (full rebuild with data restore)
**RPO**: Varies (1 hour to 1 day depending on backup schedule)

### 8.1 VPS Deleted or Hardware Failure

**Symptom**: Server completely inaccessible, Hetzner shows server deleted/destroyed, or console access shows hardware failure

**Prerequisites**: Git repository, Terraform state, Hetzner API access, backup access (Restic)

**⚠️ CRITICAL**: This is a full disaster recovery scenario. Follow carefully.

#### Step 1: Assess Scope of Loss

```bash
# Check Hetzner console
hcloud server list

# Expected: Missing server(s)
# Example output:
# NAME                  STATUS
# mail-1.prod.nbg      - (NOT FOUND)
# syncthing-1.prod.hel running
# test-1.dev.nbg       running

# Check Terraform state
cd terraform/
tofu state list | grep <server-name>

# Determine:
# - Which server(s) lost
# - When last seen (check monitoring, logs)
# - Cause (accidental deletion, hardware failure, datacenter issue)
```

**Time Estimate**: 5-10 minutes

#### Step 2: Verify Backup Availability

```bash
# Check most recent backup
# (From local machine or another server with restic configured)

export RESTIC_REPOSITORY="sftp:uXXXXXX@uXXXXXX.your-storagebox.de:/backups/<server-name>"
export RESTIC_PASSWORD="<storage-box-password>"

restic snapshots

# Expected output:
# ID        Time                 Host            Tags        Paths
# ----------------------------------------------------------------------
# 4a3b2c1d  2025-10-29 03:00:15  mail-1.prod.nbg backup      /var/mail
# 5d4e3f2a  2025-10-28 03:00:10  mail-1.prod.nbg backup      /var/mail

# Note timestamp of latest backup
# Calculate RPO: time between latest backup and loss
```

**Time Estimate**: 3-5 minutes

#### Step 3: Decision Point - Recovery Strategy

**Option A: Full Terraform Recreation (RECOMMENDED)**
- Use Terraform to provision new server
- Deploy configuration via Ansible
- Restore data from backup
→ Proceed to Section 8.2

**Option B: Manual Hetzner Console Recreation**
- Manually create server via Hetzner console
- Import into Terraform state
- Deploy configuration via Ansible
- Restore data from backup
→ More error-prone, only use if Terraform unavailable

**Choose Option A** (proceed to Section 8.2)

### 8.2 Provision New Infrastructure

**Scenario**: Use Terraform to recreate deleted server

**Prerequisites**: Terraform state showing deleted server, Hetzner API access

#### Step 1: Update Terraform State

```bash
cd terraform/

# Check if server still in state
tofu state list | grep <server-name>

# If server still in state (deletion was outside Terraform):
# Remove from state
tofu state rm 'hcloud_server.<server-name>'

# Expected output:
# Removed hcloud_server.<server-name>
```

**Time Estimate**: 1-2 minutes

#### Step 2: Verify Terraform Configuration

```bash
# Check configuration file defines server
cat servers.tf | grep -A 20 '<server-name>'

# Expected: Server resource definition exists

# Plan recreation
just tf-plan

# Expected output:
# Plan: 1 to add, 0 to change, 0 to destroy.
#
# Terraform will perform the following actions:
#   # hcloud_server.mail-1 will be created
#   + resource "hcloud_server" "mail-1" {
#       + name     = "mail-1.prod.nbg"
#       + type     = "cax21"
#       + location = "nbg1"
#       ...
#     }
```

**Time Estimate**: 2-3 minutes

#### Step 3: Provision New Server

```bash
# Apply Terraform configuration
just tf-apply

# Monitor output:
# - Watch for server creation
# - Note new IP address
# - Verify network attachment

# Expected output:
# hcloud_server.mail-1: Creating...
# hcloud_server.mail-1: Creation complete after 45s [id=12345678]
#
# Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
#
# Outputs:
# server_ips = {
#   mail-1.prod.nbg = "65.108.xxx.xxx"
# }
```

**Time Estimate**: 3-5 minutes

#### Step 4: Verify New Server Accessible

```bash
# Get new server IP
just tf-output

# Expected output:
# server_ips = {
#   mail-1.prod.nbg = "65.108.xxx.xxx"
# }

# Test SSH access (may take 1-2 minutes for server to boot)
ssh -o StrictHostKeyChecking=no root@<new-server-ip> 'hostname'

# Expected: Server hostname

# If SSH fails:
# - Wait 1-2 minutes for server boot
# - Check Hetzner console for server status
# - Verify SSH key in Terraform config
```

**Time Estimate**: 2-5 minutes (including boot wait)

#### Step 5: Update DNS (if applicable)

```bash
# If DNS was configured for old server IP, update DNS records
# (This is manual step, depends on DNS provider)

# Example using Hetzner DNS:
# - Log into Hetzner DNS console
# - Update A record for mail-1.prod.nbg to new IP
# - Wait for DNS propagation (5-30 minutes)

# Verify DNS update
host mail-1.prod.nbg

# Expected: New IP address
```

**Time Estimate**: 5-30 minutes (DNS propagation)

**Total Time**: 13-45 minutes (server provisioned, DNS updated)

### 8.3 Restore Data and Configuration

**Scenario**: Deploy configuration and restore data to newly provisioned server

**Prerequisites**: New server accessible via SSH, backup available, Ansible inventory updated

#### Step 1: Update Ansible Inventory

```bash
# Regenerate Ansible inventory from Terraform
just ansible-inventory-update

# Verify inventory
cat ansible/inventory/hosts.yaml

# Expected: New server with new IP

# Test connectivity
just ansible-ping

# Expected: mail-1.prod.nbg should respond (may show CHANGED on first connect due to new SSH host key)
```

**Time Estimate**: 2-3 minutes

#### Step 2: Bootstrap New Server

```bash
# Run bootstrap playbook (sets up base system)
cd ansible/
ansible-playbook playbooks/bootstrap.yaml --limit mail-1.prod.nbg

# Expected output:
# PLAY RECAP ***************
# mail-1.prod.nbg  : ok=25  changed=20  unreachable=0  failed=0

# This installs:
# - Essential packages
# - Security hardening
# - User accounts
# - SSH configuration
# - Firewall rules
```

**Time Estimate**: 10-15 minutes

#### Step 3: Deploy Application Configuration

```bash
# Run full deployment playbook
cd ansible/
ansible-playbook playbooks/deploy.yaml --limit mail-1.prod.nbg

# Expected output:
# PLAY RECAP ***************
# mail-1.prod.nbg  : ok=45  changed=35  unreachable=0  failed=0

# This configures:
# - Application services (Postfix, Dovecot, etc.)
# - Service configurations
# - Monitoring
# - Backup scripts (restic)
```

**Time Estimate**: 15-20 minutes

#### Step 4: Restore Application Data

```bash
# SSH to new server
ssh root@<new-server-ip>

# Stop services before restore
sudo systemctl stop postfix dovecot

# Load restic configuration
source /etc/restic/backup-config

# OR manually configure
export RESTIC_REPOSITORY="sftp:uXXXXXX@uXXXXXX.your-storagebox.de:/backups/mail-1.prod.nbg"
export RESTIC_PASSWORD="<storage-box-password>"

# List snapshots
restic snapshots

# Restore from latest backup
restic restore latest --target /

# Monitor progress (this may take 30 min to 4 hours depending on data volume)
```

**Time Estimate**: 30 minutes to 4 hours (depends on data volume)

**Data Volume Estimates:**
- Mail server (10GB): ~30 minutes
- Large mailboxes (100GB): ~2-3 hours
- Database server (5GB): ~15 minutes

#### Step 5: Verify Data Restored

```bash
# Check restored files
ls -lh /var/mail/

# Check file counts
find /var/mail -type f | wc -l

# Fix permissions if needed
sudo chown -R mail:mail /var/mail
sudo chmod -R 0600 /var/mail/*/

# Restart services
sudo systemctl start postfix dovecot

# Check status
systemctl status postfix dovecot

# Expected: Both "active (running)"
```

**Time Estimate**: 3-5 minutes

**Total Time**: 60-260 minutes (1-4.5 hours, depending on data volume)

### 8.4 Verification Steps

**After complete system rebuild, verify all functionality:**

#### Infrastructure Verification

```bash
# 1. Server exists in Hetzner
hcloud server list | grep <server-name>

# Expected: running status

# 2. Server in Terraform state
cd terraform/
tofu state list | grep <server-name>

# Expected: hcloud_server.<server-name>

# 3. Terraform state consistent
just tf-plan

# Expected: "No changes. Your infrastructure matches the configuration."
```

**Time Estimate**: 2-3 minutes

#### Connectivity Verification

```bash
# 4. SSH access works
ssh root@<server-name> 'hostname && uptime'

# Expected: Hostname and uptime

# 5. Private network connected
ssh root@<server-name> 'ip addr show ens10'

# Expected: 10.0.0.x IP address

# 6. Public network accessible
ping -c 3 <server-public-ip>

# Expected: 0% packet loss

# 7. DNS resolves (if configured)
host <server-name>

# Expected: Correct IP address
```

**Time Estimate**: 2-3 minutes

#### Configuration Verification

```bash
# 8. Ansible configuration deployed
just ansible-ping

# Expected: SUCCESS

# 9. All services running
ssh root@<server-name> 'systemctl --failed'

# Expected: 0 loaded units

# 10. Configuration idempotent
just ansible-deploy-env prod --limit <server-name> --check

# Expected: changed=0
```

**Time Estimate**: 3-5 minutes

#### Service Functionality Verification

```bash
# 11. Test service-specific functionality

# Example for mail server:
ssh root@mail-1.prod.nbg "echo 'test' | mail -s 'rebuild test' user@example.com"
# Check mail delivery

# Example for Syncthing:
ssh root@syncthing-1.prod.hel "curl -s http://localhost:8384/ | grep -i syncthing"
# Check web interface

# 12. Check logs for errors
ssh root@<server-name> 'journalctl -p err -n 50'

# Expected: No critical errors
```

**Time Estimate**: 5-10 minutes

#### Data Integrity Verification

```bash
# 13. Verify data restored
ssh root@<server-name> 'du -sh /var/mail'

# Compare with backup size

# 14. Verify file counts
ssh root@<server-name> 'find /var/mail -type f | wc -l'

# Compare with expected count

# 15. Verify permissions correct
ssh root@<server-name> 'ls -la /var/mail/ | head -10'

# Expected: Correct ownership (mail:mail, etc.)
```

**Time Estimate**: 3-5 minutes

#### Documentation

```bash
# 16. Document recovery
git commit --allow-empty -m "incident: complete rebuild of <server-name>

Cause: <reason for loss>
RTO: <actual recovery time>
RPO: <actual data loss>
Backup used: <snapshot-id>
New IP: <new-server-ip>
"

# 17. Update monitoring/alerts
# (Manual step: update monitoring systems with new IP if needed)

# 18. Notify stakeholders
# (Manual step: notify users of service restoration and any data loss)
```

**Time Estimate**: 5-10 minutes

**Total Verification Time**: 20-36 minutes

**TOTAL RECOVERY TIME (RTO)**: 4-8 hours (including provisioning, deployment, data restore, and verification)

---

## 9. Escalation Procedures

**When to escalate**: Rollback procedures fail, state corruption detected, or manual intervention required

### 9.1 When Rollback Fails

**Symptoms:**
- Rollback command fails with error
- System remains in failed state after rollback
- Services won't start even after rollback
- Multiple rollback attempts don't resolve issue

**Actions:**

#### Step 1: Stop and Assess

```bash
# STOP attempting rollbacks
# Document current state:

# System state
systemctl status
systemctl --failed

# Generation/commit state
nixos-rebuild list-generations  # NixOS
git log --oneline -10  # Configurations
tofu state list  # Infrastructure

# Take screenshots of errors
# Copy error messages to file
journalctl -xe > /tmp/error-log.txt
```

**Time Estimate**: 5-10 minutes

#### Step 2: Isolate System

```bash
# Prevent further damage:

# For production servers:
# - Notify users of outage
# - Enable maintenance mode (if applicable)
# - Redirect traffic to backup (if available)

# For VPS:
ssh root@<server-name> 'systemctl isolate rescue.target'
# This boots into rescue mode

# For NixOS local:
# Boot into previous working generation from GRUB
# Leave system in known-good state
```

**Time Estimate**: 5-10 minutes

#### Step 3: Gather Diagnostics

```bash
# Collect detailed diagnostics:

# System logs
journalctl -xe --no-pager > /tmp/journal-full.log
journalctl -b -p err --no-pager > /tmp/journal-errors.log

# Service states
systemctl list-units --state=failed --no-pager > /tmp/failed-units.log

# Configuration diffs
git diff HEAD~5 > /tmp/config-changes.diff

# Terraform state (if applicable)
cd terraform/
tofu show > /tmp/terraform-state.txt

# Hardware info
lshw -short > /tmp/hardware.txt  # NixOS
system_profiler SPHardwareDataType > /tmp/hardware.txt  # Darwin
```

**Time Estimate**: 10-15 minutes

#### Step 4: Research Issue

```bash
# Search for known issues:

# 1. Check this runbook for similar scenarios
grep -i "<error-message>" docs/runbooks/*.md

# 2. Search NixOS/Terraform/Ansible issue trackers
# NixOS: https://github.com/NixOS/nixpkgs/issues
# Terraform: https://github.com/hashicorp/terraform/issues
# Ansible: https://github.com/ansible/ansible/issues

# 3. Search community forums
# NixOS Discourse: https://discourse.nixos.org/
# Terraform Community: https://discuss.hashicorp.com/c/terraform-core

# 4. Check recent changes
git log --oneline --since="1 week ago"
```

**Time Estimate**: 15-30 minutes

#### Step 5: Attempt Manual Recovery

```bash
# If issue identified, try manual fix:

# Example: Service dependency issue
sudo systemctl edit <service-name>
# Add: After=<required-service>.service

# Example: Permission issue
sudo chown -R <user>:<group> /path/to/files

# Example: Configuration syntax error
sudo vim /etc/<service>/<config-file>
# Fix syntax error manually

# Restart affected services
sudo systemctl restart <service-name>
```

**Time Estimate**: 20-60 minutes (depends on complexity)

#### Step 6: Document and Consider Rebuild

```bash
# If manual recovery fails:

# Document all attempts
echo "Rollback failed: <reason>" >> /tmp/incident-log.txt
echo "Attempted fixes: <list>" >> /tmp/incident-log.txt
echo "Current state: <description>" >> /tmp/incident-log.txt

# Consider full rebuild:
# - For VPS: [Section 8: Complete System Loss]
# - For NixOS: Fresh install from scratch
# - For Darwin: macOS reinstall (last resort)

# Estimate rebuild time:
# - VPS: 4-8 hours
# - NixOS: 2-4 hours
# - Darwin: 4-8 hours (macOS install + config)
```

**Escalation Decision**: If rebuild is acceptable given RTO requirements, proceed with [Section 8](#8-scenario-5-complete-system-loss)

### 9.2 State Corruption Recovery

**Symptoms:**
- Terraform state shows incorrect resources
- Terraform state conflicts with actual infrastructure
- Nix profile corrupted
- Git repository in inconsistent state

#### Terraform State Corruption

```bash
# Symptoms:
# - tofu plan shows destroying/recreating resources that haven't changed
# - State file shows resources that don't exist
# - State file missing resources that do exist

# Recovery:

# Step 1: Backup corrupt state
cd terraform/
cp terraform.tfstate terraform.tfstate.corrupt-$(date +%Y%m%d-%H%M%S)

# Step 2: Restore from backup (if available)
cp terraform.tfstate.backup terraform.tfstate

# Step 3: Refresh state from API
tofu refresh

# Step 4: Verify state matches reality
tofu plan

# Expected: No changes OR only known/expected changes

# Step 5: If state still wrong, manually rebuild state
# Option A: Remove all resources and re-import
tofu state list | xargs -I {} tofu state rm {}
# Then re-import all resources (see terraform/import.sh)

# Option B: Selective re-import
tofu state rm 'hcloud_server.<server-name>'
tofu import 'hcloud_server.<server-name>' <server-id>

# Get server ID from Hetzner:
hcloud server describe <server-name> | grep "^ID"
```

**Time Estimate**: 20-40 minutes

#### Nix Profile Corruption

```bash
# Symptoms:
# - nix-env commands fail
# - Profile symlinks broken
# - Generation switching fails

# Recovery:

# Step 1: Check profile integrity
ls -la ~/.nix-profile/
ls -la /nix/var/nix/profiles/

# Step 2: Rebuild profile
nix-env --rollback  # Try rollback first

# If rollback fails:
# Delete corrupt profile
rm ~/.nix-profile

# Rebuild profile
nix-env -u  # Rebuild from scratch

# For system profiles (NixOS):
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nix-env --switch-generation <number> --profile /nix/var/nix/profiles/system
```

**Time Estimate**: 10-20 minutes

#### Git Repository Corruption

```bash
# Symptoms:
# - git commands fail with "corrupt object"
# - Repository in detached HEAD state
# - Index locked permanently

# Recovery:

# Step 1: Verify corruption
git fsck

# Step 2: Try automatic recovery
git fsck --full

# Step 3: If fsck fails, restore from remote
# Backup local changes
git diff > /tmp/local-changes.patch
git stash

# Re-clone repository
cd ..
mv infra infra.corrupt-$(date +%Y%m%d-%H%M%S)
git clone <repository-url> infra
cd infra

# Apply local changes
git apply /tmp/local-changes.patch

# Step 4: If no remote, restore from backup
# (Local time machine, rsync backup, etc.)
```

**Time Estimate**: 15-30 minutes

### 9.3 Hardware Issues

**Symptoms:**
- System won't boot despite correct configuration
- Kernel panics or hardware errors in logs
- Disk errors (I/O errors, read failures)
- Network hardware not detected

**Actions:**

#### For Local Systems (xbook, xmsi)

```bash
# Step 1: Identify hardware issue
# Check dmesg for hardware errors
dmesg | grep -i error

# Check SMART status (disks)
smartctl -a /dev/sda

# Check memory (memtest)
# Reboot into memtest86+ from GRUB

# Step 2: Document hardware issue
# Take photos of error messages
# Record hardware configuration
lshw -short > /tmp/hardware-info.txt

# Step 3: Hardware-specific recovery
# - Disk failure: Replace disk, restore from backup
# - Memory failure: Replace RAM, rebuild system
# - Network failure: Replace NIC, reconfigure network
```

**Time Estimate**: Varies (hours to days, depends on hardware replacement)

**Escalation**: Contact hardware vendor or local technician

#### For Hetzner VPS

```bash
# Step 1: Check Hetzner status
# Visit: https://status.hetzner.com/
# Check for datacenter issues

# Step 2: Contact Hetzner support
# Log into Hetzner console
# Submit support ticket with:
# - Server name
# - Issue description
# - Error messages
# - When issue started

# Step 3: While waiting for support
# Consider provisioning new VPS:
# [Section 8: Complete System Loss]

# Step 4: If Hetzner confirms hardware failure
# Request server replacement OR
# Provision new server and migrate
```

**Time Estimate**: 1-24 hours (depends on Hetzner support response)

**Escalation**: Hetzner Support (support@hetzner.com)

### 9.4 External Resources

**When you've exhausted all rollback options and need help:**

#### Community Resources

1. **NixOS Community**
   - Discourse: https://discourse.nixos.org/
   - IRC: #nixos on irc.libera.chat
   - Matrix: #nixos:nixos.org
   - Reddit: r/NixOS

2. **Terraform/OpenTofu Community**
   - Discuss: https://discuss.hashicorp.com/c/terraform-core
   - GitHub: https://github.com/opentofu/opentofu/issues
   - Slack: terraform-community.slack.com

3. **Ansible Community**
   - Forum: https://forum.ansible.com/
   - IRC: #ansible on irc.libera.chat
   - GitHub: https://github.com/ansible/ansible/issues

#### Vendor Support

1. **Hetzner Support**
   - Email: support@hetzner.com
   - Console: https://console.hetzner.cloud/
   - Status: https://status.hetzner.com/
   - Docs: https://docs.hetzner.com/

#### Professional Services

If the system is critical and downtime is unacceptable:

1. **NixOS Consulting**
   - Tweag: https://tweag.io/
   - Numtide: https://numtide.com/

2. **DevOps Consulting**
   - Search for local DevOps/SRE consultants
   - Cloud-native consulting firms

**Cost Estimate**: $100-300/hour for emergency consulting

#### Decision Criteria: When to Get External Help

✅ **Get help if:**
- System down >4 hours and no progress
- Data loss risk is high
- Infrastructure corruption widespread
- Security incident suspected
- Issue outside your expertise

❌ **Don't need help if:**
- Issue documented in this runbook
- Rolling back resolves issue
- Issue is cosmetic (no service impact)
- Time to research < time to rebuild

---

## 10. RTO/RPO Summary

**Recovery Time Objective (RTO)**: Maximum acceptable downtime
**Recovery Point Objective (RPO)**: Maximum acceptable data loss

| Scenario | Failure Type | RTO | RPO | Notes |
|----------|--------------|-----|-----|-------|
| **NixOS Deployment** | Boot failure (GRUB rollback) | <5 min | 0 | Physical/console access required |
| | Service failure (command rollback) | <5 min | 0 | SSH access required |
| | Configuration error (pre-deploy) | <5 min | 0 | No deployment occurred, no downtime |
| **Terraform Apply** | Partial apply (state inconsistency) | <15 min | 0 | Assuming `.tfstate.backup` exists |
| | Wrong configuration applied | <15 min | 0 | Config rollback via git |
| | Resource destruction | <15 min | 0 | Infrastructure only, or 4+ hours with data restore |
| **Ansible Deployment** | Service down after deployment | <20 min | 0 | Idempotent re-deployment |
| | Configuration corruption | <20 min | 0 | Template re-deployment |
| | Partial application | <30 min | 0 | Depends on cleanup needed |
| **Data Loss** | Configuration files (git) | <30 min | 0 | Git history always available |
| | Application data (restic) | <4 hours | 1-24 hours | Depends on backup schedule (daily = 1-24hr RPO) |
| **Complete System Loss** | VPS deleted/hardware failure | 4-8 hours | 1-24 hours | Full rebuild: provision + config + data restore |

### RTO/RPO by System

| System | Services | RTO Target | RPO Target | Backup Frequency |
|--------|----------|------------|------------|------------------|
| **xbook** (Darwin) | Development workstation | 1 hour | 0 | Git (continuous), Time Machine (hourly) |
| **xmsi** (NixOS) | Desktop workstation | 1 hour | 0 | Git (continuous), local snapshots |
| **srv-01** (NixOS) | Local server (future) | 4 hours | 1 hour | Git (continuous), restic (daily) |
| **mail-1.prod.nbg** | Mail server (Postfix, Dovecot) | 4 hours | 1 hour | Restic to Storage Box (daily) |
| **syncthing-1.prod.hel** | File sync | 8 hours | 1 day | Syncthing replication (continuous), no backup needed |
| **test-1.dev.nbg** | Test environment | Best effort | 1 day | No backup (ephemeral) |

### Assumptions for RTO/RPO

**RTO Assumptions:**
1. **Administrator available**: Operator available to respond within 15 minutes of alert
2. **Backups exist**: Recent restic backup available for data restore
3. **State files intact**: Terraform state and git history accessible
4. **Network available**: Internet connectivity for API calls and package downloads
5. **Credentials available**: SOPS keys, API tokens, SSH keys accessible

**RPO Assumptions:**
1. **Backup schedule running**: Daily restic backups executing successfully
2. **Git commits frequent**: Configuration changes committed regularly (not sitting in working tree)
3. **No local modifications**: Production systems don't have uncommitted local changes
4. **Backup verification**: Backups tested quarterly and known to be restorable

### Degraded Mode RTO/RPO

If assumptions are violated (backup failed, state corrupted, etc.):

| Degraded Scenario | Impact | Degraded RTO | Degraded RPO |
|-------------------|--------|--------------|--------------|
| No recent backup | Data restore fails | +24 hours | Up to 1 week |
| Terraform state lost | Must manually rebuild state | +2 hours | 0 (infrastructure) |
| Git history lost | Must manually recreate configs | +8 hours | Varies (config) |
| SOPS keys lost | Cannot decrypt secrets | +4 hours | 0 (must recreate secrets) |
| API tokens expired | Cannot provision infrastructure | +1 hour | 0 (renew tokens) |
| Network outage | Cannot download packages | +<outage duration> | 0 |

---

## Appendix A: Common Error Messages

### NixOS Errors

**Error**: `error: getting status of '/nix/store/...': No such file or directory`
**Cause**: Nix store corruption or garbage collection removed needed files
**Rollback**: `nixos-rebuild switch --rollback` or restore from GRUB
**Prevention**: Don't run `nix-collect-garbage -d` on production systems

**Error**: `Failed to start <service-name>.service`
**Cause**: Service configuration error or dependency failure
**Rollback**: `nixos-rebuild switch --rollback`, check `journalctl -u <service-name>`
**Prevention**: Test deployments on test-1.dev.nbg first

**Error**: `error: infinite recursion encountered`
**Cause**: Circular dependency in Nix configuration
**Rollback**: Git revert to previous configuration
**Prevention**: Use `nix flake check` before deploying

### Terraform Errors

**Error**: `Error: Error creating server: invalid server type`
**Cause**: Typo in server type (e.g., "cax21" vs "CAX21")
**Rollback**: Fix configuration, re-run `tofu apply`
**Prevention**: Use variable validation in terraform

**Error**: `Error: Saved plan is stale`
**Cause**: Infrastructure changed between `plan` and `apply`
**Rollback**: Re-run `just tf-plan` and `just tf-apply`
**Prevention**: Run plan and apply close together

**Error**: `Error: state snapshot was created by Terraform v1.x.x, which is newer than current v1.y.y`
**Cause**: Terraform version downgrade
**Rollback**: Use same or newer Terraform version
**Prevention**: Pin Terraform version in devshell

### Ansible Errors

**Error**: `UNREACHABLE! => {"changed": false, "unreachable": true}`
**Cause**: SSH connection failed (wrong IP, firewall, SSH key)
**Rollback**: Check `just ansible-ping`, verify SSH keys
**Prevention**: Test connectivity with `ansible all -m ping` before deployment

**Error**: `fatal: [host]: FAILED! => {"msg": "apt cache update failed"}`
**Cause**: Network issue or repository unavailable
**Rollback**: Re-run playbook (idempotent)
**Prevention**: Use apt mirrors, check network before deployment

**Error**: `{"msg": "AnsibleUndefinedVariable: 'variable' is undefined"}`
**Cause**: Missing variable in inventory or group_vars
**Rollback**: Fix variable definition, re-run playbook
**Prevention**: Use ansible-lint to validate playbooks

---

## Appendix B: Rollback Checklist Templates

### Pre-Rollback Checklist

```
[ ] Identified failure scenario (section ___)
[ ] Documented current state (error messages, logs)
[ ] Verified backups available (if needed)
[ ] Notified stakeholders of incident
[ ] Reviewed rollback procedure
[ ] Estimated RTO/RPO for this scenario
[ ] Ready to execute rollback
```

### NixOS Rollback Checklist

```
[ ] Accessed system (GRUB or SSH)
[ ] Identified previous working generation
[ ] Rolled back to previous generation
[ ] Verified system booted/services running
[ ] Checked logs for errors
[ ] Documented rollback and root cause
[ ] Committed rollback to git (if config reverted)
```

### Terraform Rollback Checklist

```
[ ] Backed up current terraform.tfstate
[ ] Restored terraform.tfstate.backup (if needed)
[ ] Reverted git configuration (if needed)
[ ] Ran just tf-plan to verify changes
[ ] Ran just tf-apply to restore infrastructure
[ ] Verified in Hetzner console
[ ] Tested SSH access to all servers
[ ] Ran just ansible-ping to verify connectivity
```

### Ansible Rollback Checklist

```
[ ] Identified failed service/configuration
[ ] Attempted service restart (quick fix)
[ ] Reverted git configuration
[ ] Re-ran ansible-deploy to affected servers
[ ] Verified services running
[ ] Checked logs for errors
[ ] Verified idempotency (changed=0 on re-run)
[ ] Tested service functionality
```

### Data Restore Checklist

```
[ ] Identified data loss scope and timeline
[ ] Located backup source (restic, git)
[ ] Verified backup exists and is recent
[ ] Stopped services using data
[ ] Backed up current (corrupted) data
[ ] Restored data from backup
[ ] Verified data integrity (file counts, permissions)
[ ] Restarted services
[ ] Tested service functionality
[ ] Documented RPO (actual data loss)
```

### Complete System Rebuild Checklist

```
[ ] Assessed scope of loss (which servers)
[ ] Verified backups available
[ ] Provisioned new infrastructure (Terraform)
[ ] Updated DNS (if applicable)
[ ] Updated Ansible inventory
[ ] Ran bootstrap playbook
[ ] Ran deployment playbook
[ ] Restored application data
[ ] Verified all services running
[ ] Tested service functionality
[ ] Documented RTO/RPO
[ ] Notified stakeholders of restoration
```

---

## Document Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-29 | 1.0 | Initial rollback procedures runbook | Claude (I4.T5) |

---

**End of Rollback Procedures Runbook**

For deployment procedures, see: `docs/runbooks/deployment_procedures.md`
For project documentation, see: `CLAUDE.md`
