# Disaster Recovery Runbook

**Purpose**: Strategic guidance for detecting, responding to, and recovering from infrastructure failures
**Audience**: System operators responding to critical incidents requiring disaster recovery
**Last Updated**: 2025-10-30

---

## Table of Contents

1. [Quick Reference](#1-quick-reference)
2. [When to Use This Runbook](#2-when-to-use-this-runbook)
3. [Disaster Recovery Decision Tree](#3-disaster-recovery-decision-tree)
4. [Scenario 1: Configuration Error (Bad Nix Build)](#4-scenario-1-configuration-error-bad-nix-build)
5. [Scenario 2: Infrastructure Provisioning Error (Terraform Failure)](#5-scenario-2-infrastructure-provisioning-error-terraform-failure)
6. [Scenario 3: Service Failure (VPS Application Crash)](#6-scenario-3-service-failure-vps-application-crash)
7. [Scenario 4: Data Loss (Accidental Deletion)](#7-scenario-4-data-loss-accidental-deletion)
8. [Scenario 5: Complete VPS Loss (Datacenter Failure)](#8-scenario-5-complete-vps-loss-datacenter-failure)
9. [RTO/RPO Summary](#9-rtorpo-summary)
10. [Disaster Recovery Testing](#10-disaster-recovery-testing)
11. [Escalation and External Resources](#11-escalation-and-external-resources)
12. [Document Revision History](#12-document-revision-history)

---

## 1. Quick Reference

| Failure Type | Detection Method | Primary Runbook Section | RTO | RPO |
|--------------|------------------|------------------------|-----|-----|
| Configuration error (Nix build failure) | Build command exits non-zero, error messages in output | [Section 4](#4-scenario-1-configuration-error-bad-nix-build) | <5 min | 0 |
| Infrastructure error (Terraform failure) | `tofu apply` fails, state inconsistency | [Section 5](#5-scenario-2-infrastructure-provisioning-error-terraform-failure) | <30 min | 0 |
| Service failure (app crash) | Service down, no HTTP response, systemd failed state | [Section 6](#6-scenario-3-service-failure-vps-application-crash) | <5 min auto, <20 min manual | 0 |
| Data loss (deleted files) | User report, missing files, empty directories | [Section 7](#7-scenario-4-data-loss-accidental-deletion) | <4 hours | 1 hour |
| Complete VPS loss (datacenter) | No SSH access, Hetzner console shows offline/deleted | [Section 8](#8-scenario-5-complete-vps-loss-datacenter-failure) | <8 hours | 1-24 hours |

**Critical Cross-References:**
- **Detailed rollback procedures**: [rollback_procedures.md](rollback_procedures.md)
- **Backup restoration procedures**: [backup_verification.md](backup_verification.md)
- **Normal deployment procedures**: [deployment_procedures.md](deployment_procedures.md)

---

## 2. When to Use This Runbook

**Use this disaster recovery runbook when:**

1. ✅ **Critical system failure** - Service outage affecting production systems
2. ✅ **Data loss incident** - Files deleted, corrupted, or inaccessible
3. ✅ **Infrastructure destruction** - VPS deleted, datacenter offline, hardware failure
4. ✅ **Multiple system failures** - Cascading failures across systems
5. ✅ **Unknown failure cause** - Need systematic approach to identify problem type
6. ✅ **Emergency response planning** - Preparing for or testing disaster recovery

**Do NOT use for:**

- ❌ **Failed deployments** - Use [rollback_procedures.md](rollback_procedures.md) for tactical rollback
- ❌ **Routine maintenance** - Use [deployment_procedures.md](deployment_procedures.md)
- ❌ **Performance issues** - Investigate with monitoring and logs first
- ❌ **Security incidents** - Follow security incident response procedures (separate playbook)

**Relationship to Other Runbooks:**

This disaster recovery runbook provides **strategic guidance** and **decision-making frameworks**. For detailed technical procedures with exact commands, cross-reference:

- **[rollback_procedures.md](rollback_procedures.md)**: Detailed step-by-step commands for rolling back failed deployments
- **[backup_verification.md](backup_verification.md)**: Detailed procedures for backup restoration and verification
- **[deployment_procedures.md](deployment_procedures.md)**: Normal deployment procedures for rebuilding systems

---

## 3. Disaster Recovery Decision Tree

```
INCIDENT DETECTED
│
├─ Can you SSH to the system?
│  │
│  ├─ NO → Is system visible in Hetzner Console?
│  │  ├─ NO → [Section 8: Complete VPS Loss]
│  │  └─ YES → Check power state, try console access
│  │
│  └─ YES → Continue investigation ↓
│
├─ What symptoms are visible?
│  │
│  ├─ Build/deployment command failed?
│  │  ├─ NixOS/Darwin build error → [Section 4: Configuration Error]
│  │  ├─ Terraform apply error → [Section 5: Infrastructure Error]
│  │  └─ Ansible playbook error → [Section 6: Service Failure]
│  │
│  ├─ Service not responding?
│  │  ├─ systemd status: failed → [Section 6: Service Failure]
│  │  ├─ systemd status: active → Check application logs
│  │  └─ systemd service missing → [Section 4: Configuration Error]
│  │
│  ├─ Files missing or corrupted?
│  │  ├─ Recent change (<1 hour) → [Section 7: Data Loss]
│  │  ├─ Configuration files → Check git history first
│  │  └─ Application data → [Section 7: Data Loss]
│  │
│  └─ Multiple systems affected?
│     ├─ All systems → Check network, Hetzner status
│     ├─ VPS only → Likely infrastructure issue
│     └─ Service-specific → Application issue
│
└─ When in doubt: Start with [Section 4] and follow escalation path

ESCALATION TRIGGERS:
- Recovery procedure not working after 2 attempts
- Failure cause unclear after 30 minutes investigation
- Data loss exceeds RPO tolerance (>24 hours)
- Multiple cascading failures
→ See [Section 11: Escalation]
```

---

## 4. Scenario 1: Configuration Error (Bad Nix Build)

### Overview

**Failure Type**: NixOS/Darwin configuration fails to build or deploy, preventing system updates or causing boot failures.

**Affected Systems**:
- `xmsi` (NixOS desktop)
- `xbook` (Darwin/macOS)
- `srv-01` (NixOS server, future)

**Recovery Strategy**: Detect build failure before deployment, rollback to previous working generation, or fix configuration error.

---

### Detection Methods

**Pre-Deployment Detection (Preferred)**:
```bash
# Error during build phase (before activation)
sudo nixos-rebuild build --flake .#xmsi
# Exit code: non-zero
# Output: error: builder for '...' failed with exit code 1

nix flake check
# Exit code: non-zero
# Output: error: attribute '...' missing
```

**Post-Deployment Detection**:
```bash
# System boots but services fail
systemctl --failed
# Output: Shows failed systemd services

# System won't boot
# Symptom: Stuck at boot screen, kernel panic, emergency mode
# Detection: Physical access or console shows boot failure
```

**Common Error Messages**:
- `error: attribute 'XYZ' missing` - Undefined variable or typo
- `error: infinite recursion encountered` - Circular dependency in modules
- `error: builder for '/nix/store/...' failed` - Package build failure
- `error: access to '...' is forbidden` - Unfree package without allowUnfree
- Boot failure symptoms: Black screen, systemd emergency mode, GRUB error

---

### Recovery Steps

**Step 1: Determine Failure Stage**

```bash
# Check if system is bootable
ssh user@system  # If this works, system booted successfully

# Check which services failed
systemctl --failed

# Check system generation
nixos-rebuild list-generations  # NixOS
darwin-rebuild --list-generations  # Darwin
```

**Step 2: Choose Recovery Method**

| Failure Stage | Recovery Method | Time | Reference |
|--------------|----------------|------|-----------|
| Build failed (pre-deployment) | Fix configuration error | <5 min | Current section |
| System won't boot | GRUB rollback to previous generation | <5 min | [rollback_procedures.md#41](rollback_procedures.md#41-boot-failure-grub-rollback) |
| System boots, services failed | Command-line rollback | <5 min | [rollback_procedures.md#42](rollback_procedures.md#42-service-failure-command-rollback) |
| Unknown good state | Restore from git history | <10 min | [rollback_procedures.md#43](rollback_procedures.md#43-configuration-error-pre-deployment-detection) |

**Step 3: Execute Recovery**

**Option A: Fix Configuration Error (Pre-Deployment)**

If build failed before deployment, fix the error in configuration:

```bash
# Review error message
sudo nixos-rebuild build --flake .#xmsi 2>&1 | less

# Common fixes:
# - Fix typo in configuration.nix or module
# - Add missing allowUnfree = true
# - Remove circular module imports
# - Update flake.lock if dependency issue

# Verify fix
nix flake check
sudo nixos-rebuild build --flake .#xmsi

# Deploy when build succeeds
sudo nixos-rebuild switch --flake .#xmsi
```

**Option B: Rollback to Previous Generation (Post-Deployment)**

If system booted but has issues:

```bash
# NixOS: Rollback via command
sudo nixos-rebuild switch --rollback

# Darwin: Rollback via command
darwin-rebuild switch --rollback

# Verify services recovered
systemctl --failed  # Should show no failed services
```

**Option C: Boot Previous Generation (Won't Boot)**

If system won't boot, use GRUB menu (requires physical/console access):

1. Reboot system
2. At GRUB menu, select previous generation
3. System boots to last working configuration
4. Investigate and fix configuration error
5. Re-deploy when fixed

For detailed GRUB rollback procedure, see [rollback_procedures.md#41](rollback_procedures.md#41-boot-failure-grub-rollback).

---

### Verification Procedures

**After Recovery**:

1. **Verify system boots**:
   ```bash
   ssh user@system  # Successful SSH connection
   uptime  # System uptime confirms boot
   ```

2. **Verify services running**:
   ```bash
   systemctl --failed  # No failed services
   systemctl status critical-service.service  # Check critical services individually
   ```

3. **Verify configuration generation**:
   ```bash
   nixos-rebuild list-generations  # Current generation marked
   ls -l /run/current-system  # Points to correct generation
   ```

4. **Test application functionality**:
   ```bash
   # Example for mail server
   curl http://localhost:80  # Web interface responds
   systemctl status postfix dovecot  # Mail services active
   ```

---

### RTO/RPO Estimates

| Scenario | RTO | RPO | Notes |
|----------|-----|-----|-------|
| Build failed (pre-deployment) | <5 min | 0 | No deployment occurred, fix error and rebuild |
| System boots, services failed | <5 min | 0 | Command rollback to previous generation |
| System won't boot | <5 min | 0 | GRUB rollback, requires physical/console access |

**RTO Breakdown**:
- Detection: <1 minute (immediate error message or boot failure)
- Decision: <1 minute (choose rollback vs fix)
- Execution: 2-3 minutes (rollback or rebuild)
- Verification: <1 minute (check services)

**RPO**: Zero data loss - configuration changes are atomic, application data unaffected.

---

### Escalation Criteria

**Escalate when**:

1. ✅ **Rollback fails**: `nixos-rebuild switch --rollback` fails
2. ✅ **No known good generation**: All recent generations have same error
3. ✅ **Boot failure persists**: GRUB rollback doesn't resolve boot issue
4. ✅ **Hardware failure suspected**: Boot failure with hardware error messages
5. ✅ **Flake lock corrupted**: `nix flake check` fails on all branches

**Escalation Actions**:
- Review git history for last known good configuration
- Boot from NixOS installation media for recovery
- Consider data backup before destructive recovery
- See [Section 11: Escalation](#11-escalation-and-external-resources)

---

## 5. Scenario 2: Infrastructure Provisioning Error (Terraform Failure)

### Overview

**Failure Type**: OpenTofu/Terraform fails during `apply`, causing partial infrastructure changes, state inconsistency, or resource destruction.

**Affected Infrastructure**:
- Hetzner Cloud VPS (mail-1, syncthing-1, test-1)
- Private network (homelab)
- SSH keys
- Terraform state file

**Recovery Strategy**: Restore Terraform state from backup, revert configuration changes, or recreate destroyed resources.

---

### Detection Methods

**During Terraform Apply**:
```bash
just tf-apply
# Output: Error messages during apply

# Common error patterns:
# - Error: Error creating server: invalid server type
# - Error: Error deleting network: network still in use
# - Error: context deadline exceeded (API timeout)
# - Error: authentication failed (invalid token)
```

**Symptoms of Terraform Failure**:

1. **Partial Apply**: Some resources created, others failed
   ```bash
   just tf-plan
   # Output: Shows unexpected changes (plan not empty after apply)
   ```

2. **State Inconsistency**: Terraform state doesn't match reality
   ```bash
   tofu state list  # Shows resources that don't exist
   hcloud server list  # Shows servers not in state
   ```

3. **Resource Destruction**: Resources deleted unexpectedly
   ```bash
   hcloud server list
   # Output: Missing expected servers (mail-1, syncthing-1, etc.)
   ```

**Post-Failure Detection**:
```bash
# VPS no longer accessible
ssh root@mail-1.prod.nbg  # Connection refused or timeout

# Hetzner console shows missing resources
hcloud server list
hcloud network list
```

---

### Recovery Steps

**Step 1: Assess Damage**

```bash
# Check current Terraform state
cd terraform/
tofu state list

# Compare with Hetzner actual resources
hcloud server list
hcloud network list
hcloud ssh-key list

# Identify discrepancies:
# - Resources in state but not in Hetzner (deletion)
# - Resources in Hetzner but not in state (orphaned)
# - Resources with wrong configuration
```

**Step 2: Determine Recovery Method**

| Failure Type | Recovery Method | Time | Reference |
|--------------|----------------|------|-----------|
| Partial apply (state inconsistent) | Restore state from backup | <15 min | [rollback_procedures.md#51](rollback_procedures.md#51-partial-apply-state-inconsistency) |
| Wrong configuration applied | Revert git config, re-apply | <15 min | [rollback_procedures.md#52](rollback_procedures.md#52-wrong-configuration-applied) |
| Resources destroyed (no data) | Recreate via Terraform | <15 min | [rollback_procedures.md#53](rollback_procedures.md#53-accidental-resource-destruction) |
| Resources destroyed (with data) | Recreate + restore backup | <4 hours | [Section 8](#8-scenario-5-complete-vps-loss-datacenter-failure) |

**Step 3: Execute Recovery**

**Option A: Restore Terraform State (Partial Apply)**

If `tofu apply` failed mid-execution, restore state backup:

```bash
cd terraform/

# Backup current (corrupted) state
cp terraform.tfstate terraform.tfstate.broken

# Restore previous state
cp terraform.tfstate.backup terraform.tfstate

# Verify state restored
tofu state list

# Plan should show what needs to be re-applied
just tf-plan

# Re-apply to reach desired state
just tf-apply
```

For detailed state restoration procedure, see [rollback_procedures.md#51](rollback_procedures.md#51-partial-apply-state-inconsistency).

**Option B: Revert Configuration (Wrong Config)**

If wrong configuration was applied successfully:

```bash
# Review what was applied
git log --oneline -5
git diff HEAD~1 terraform/

# Revert to previous configuration
cd terraform/
git revert HEAD  # Creates revert commit
# Or: git checkout HEAD~1 -- .  # Discard changes

# Plan to see what will change
just tf-plan

# Apply reverted configuration
just tf-apply

# Verify in Hetzner
hcloud server list
```

For detailed configuration revert procedure, see [rollback_procedures.md#52](rollback_procedures.md#52-wrong-configuration-applied).

**Option C: Recreate Destroyed Resources (Infrastructure Only)**

If resources were deleted but can be recreated without data loss:

```bash
# Remove destroyed resources from state
tofu state rm 'hcloud_server.mail-1'

# Re-add resource to configuration if removed
# (ensure resource block exists in servers.tf)

# Apply to recreate
just tf-apply

# Verify resource created
hcloud server describe mail-1.prod.nbg

# Update Ansible inventory
just ansible-inventory-update

# Re-deploy configuration via Ansible
just ansible-deploy
```

For detailed resource recreation procedure, see [rollback_procedures.md#53](rollback_procedures.md#53-accidental-resource-destruction).

**Option D: Recreate + Restore Data (Resource with Application Data)**

If resource was destroyed and had application data (mail, databases):

1. Recreate infrastructure via Terraform (Option C above)
2. Re-deploy configuration via Ansible
3. Restore data from backup (see [Section 7](#7-scenario-4-data-loss-accidental-deletion))

Total time: <4 hours (infrastructure <30 min + data restore <4 hours)

For complete rebuild procedure, see [Section 8](#8-scenario-5-complete-vps-loss-datacenter-failure).

---

### Verification Procedures

**After Recovery**:

1. **Verify Terraform state consistency**:
   ```bash
   just tf-plan
   # Output: "No changes. Your infrastructure matches the configuration."
   ```

2. **Verify resources in Hetzner**:
   ```bash
   hcloud server list  # All expected servers present
   hcloud network list  # Private network exists
   ssh root@mail-1.prod.nbg  # SSH access works
   ```

3. **Verify Ansible connectivity**:
   ```bash
   just ansible-ping  # All servers respond
   ```

4. **Verify services running** (if resources were recreated):
   ```bash
   ssh root@mail-1.prod.nbg 'systemctl status postfix dovecot'
   curl http://mail-1.prod.nbg  # Application responds
   ```

5. **Document state backup**:
   ```bash
   ls -lh terraform/terraform.tfstate.backup
   # Ensure backup exists for future recovery
   ```

---

### RTO/RPO Estimates

| Scenario | RTO | RPO | Notes |
|----------|-----|-----|-------|
| Partial apply (state restore) | <15 min | 0 | State backup exists, no resources destroyed |
| Wrong configuration | <15 min | 0 | Config rollback via git |
| Resource destruction (infra only) | <30 min | 0 | Recreate resources, no data involved |
| Resource destruction (with data) | <4 hours | 1-24 hours | Recreate + restore backup |

**RTO Breakdown (State Restore)**:
- Detection: <2 minutes (immediate error during apply)
- Assessment: 3-5 minutes (compare state to reality)
- State restore: 2-3 minutes (copy backup, verify)
- Re-apply: 5-10 minutes (tofu apply execution time)
- Verification: 2-5 minutes (check Hetzner, test SSH)

**RPO**:
- Configuration: Zero (git history)
- Infrastructure: Zero (stateless, can be recreated)
- Application data: Depends on backup age (1-24 hours for daily backups)

---

### Escalation Criteria

**Escalate when**:

1. ✅ **State backup missing**: No `terraform.tfstate.backup` file exists
2. ✅ **State backup also corrupted**: Backup state also inconsistent
3. ✅ **API access lost**: Hetzner API token invalid or expired
4. ✅ **Multiple resources destroyed**: Cascading destruction across environments
5. ✅ **Terraform bug suspected**: Unexpected behavior not explained by configuration

**Escalation Actions**:
- Restore state from git history (if committed, not recommended but possible)
- Manually recreate resources and import to state (`tofu import`)
- Contact Hetzner support for resource recovery (if within deletion grace period)
- See [Section 11: Escalation](#11-escalation-and-external-resources)

---

## 6. Scenario 3: Service Failure (VPS Application Crash)

### Overview

**Failure Type**: Application or system service crashes, hangs, or becomes unresponsive on production VPS.

**Affected Systems**:
- `mail-1.prod.nbg` - Postfix, Dovecot, mailcow containers
- `syncthing-1.prod.hel` - Syncthing service
- `test-1.dev.nbg` - Test applications

**Recovery Strategy**: Automatic restart via systemd, manual service restart, configuration rollback if caused by deployment, or application-level recovery.

---

### Detection Methods

**Current Detection Methods** (Manual, before monitoring deployed):

1. **Service endpoint not responding**:
   ```bash
   # HTTP service check
   curl -I http://mail-1.prod.nbg
   # Output: Connection refused / Timeout

   # Mail service check
   telnet mail-1.prod.nbg 25  # SMTP
   telnet mail-1.prod.nbg 143  # IMAP
   # Output: Connection refused
   ```

2. **Systemd service status check**:
   ```bash
   ssh root@mail-1.prod.nbg 'systemctl --failed'
   # Output: Shows failed services

   ssh root@mail-1.prod.nbg 'systemctl status postfix'
   # Output: ● postfix.service - Postfix Mail Transport Agent
   #         Loaded: loaded
   #         Active: failed (Result: exit-code)
   ```

3. **User reports**:
   - Email delivery failures
   - Cannot connect to service
   - Application error messages

4. **Log monitoring**:
   ```bash
   ssh root@mail-1.prod.nbg 'journalctl -u postfix -n 50 --no-pager'
   # Look for error messages, crashes, OOM kills
   ```

**Future Detection Methods** (After Iteration 7 monitoring deployment):

- Prometheus alerting on service down
- HTTP endpoint monitoring alerts
- systemd service state monitoring
- Log aggregation with error alerts
- Automated health checks

---

### Recovery Steps

**Step 1: Identify Failure Type**

```bash
# Check service status
ssh root@mail-1.prod.nbg 'systemctl status <service>'

# Possible states:
# - failed (Result: exit-code) → Service crashed, attempt restart
# - failed (Result: signal) → Service killed (OOM, SIGKILL)
# - active (running) but not responding → Hung, may need force restart
# - inactive (dead) → Service stopped, needs start
```

**Step 2: Check Recent Changes**

```bash
# Was this after a deployment?
git log --oneline -5  # Check recent Ansible changes

# Check systemd service recent restarts
ssh root@mail-1.prod.nbg 'systemctl status <service> | grep "Active:"'
# If timestamp matches recent deployment, likely config issue
```

**Step 3: Determine Recovery Method**

| Failure Pattern | Recovery Method | Time | Reference |
|----------------|----------------|------|-----------|
| Service crashed (first occurrence) | Automatic systemd restart | <5 min | Current section - automatic |
| Service crashed (automatic restart failed) | Manual service restart | <5 min | Current section - manual |
| Service crash after deployment | Rollback Ansible deployment | <20 min | [rollback_procedures.md#61](rollback_procedures.md#61-service-down-after-deployment) |
| Service hangs (not crashed) | Force restart, investigate | <10 min | Current section - manual |
| OOM kill (out of memory) | Restart, increase resources | <10 min | Requires Terraform change |
| Config corruption | Re-deploy configuration | <20 min | [rollback_procedures.md#62](rollback_procedures.md#62-configuration-corruption) |

**Step 4: Execute Recovery**

**Option A: Automatic Restart (systemd)**

Most services are configured with systemd automatic restart:

```bash
# Check systemd restart configuration
ssh root@mail-1.prod.nbg 'systemctl show <service> | grep Restart'
# Output: Restart=on-failure
#         RestartSec=10s

# Systemd automatically attempts restart
# Wait 30 seconds, then verify service recovered
ssh root@mail-1.prod.nbg 'systemctl status <service>'
# Output: Active: active (running) since ...
```

**If automatic restart succeeds**: No manual action needed, proceed to verification.

**If automatic restart fails**: Proceed to Option B (manual restart).

---

**Option B: Manual Service Restart**

If automatic restart failed or service is hung:

```bash
# Stop service (graceful)
ssh root@mail-1.prod.nbg 'systemctl stop <service>'

# Verify stopped
ssh root@mail-1.prod.nbg 'systemctl status <service>'
# Output: Active: inactive (dead)

# Check for lingering processes
ssh root@mail-1.prod.nbg 'ps aux | grep <service-name>'

# Force kill if needed
ssh root@mail-1.prod.nbg 'pkill -9 <service-name>'

# Start service
ssh root@mail-1.prod.nbg 'systemctl start <service>'

# Verify started
ssh root@mail-1.prod.nbg 'systemctl status <service>'
# Output: Active: active (running)
```

**Time**: <5 minutes for manual restart

---

**Option C: Rollback Ansible Deployment**

If service failed after Ansible deployment:

```bash
# Review recent deployment
git log --oneline -5
git show HEAD  # Review changes in last deployment

# Revert Ansible configuration
git revert HEAD
# Or: git checkout HEAD~1 -- ansible/

# Re-deploy to affected server(s)
just ansible-deploy-env prod
# Or target specific host:
# cd ansible/
# ansible-playbook playbooks/deploy.yaml --limit mail-1.prod.nbg

# Verify service recovered
ssh root@mail-1.prod.nbg 'systemctl status <service>'
```

For detailed Ansible rollback procedure, see [rollback_procedures.md#61](rollback_procedures.md#61-service-down-after-deployment).

**Time**: <20 minutes for rollback and re-deployment

---

**Option D: Re-deploy Configuration (Config Corruption)**

If configuration files are corrupted but git is unchanged:

```bash
# Re-run Ansible to restore configuration
just ansible-deploy-env prod

# This re-templates all configuration files
# and ensures idempotent state

# Restart service after config restore
ssh root@mail-1.prod.nbg 'systemctl restart <service>'

# Verify service recovered
ssh root@mail-1.prod.nbg 'systemctl status <service>'
```

For detailed configuration restoration procedure, see [rollback_procedures.md#62](rollback_procedures.md#62-configuration-corruption).

**Time**: <20 minutes for re-deployment

---

### Verification Procedures

**After Recovery**:

1. **Verify service is running**:
   ```bash
   ssh root@mail-1.prod.nbg 'systemctl status <service>'
   # Output: Active: active (running)
   #         Main PID: <pid> (running since ...)
   ```

2. **Verify service responds to requests**:
   ```bash
   # HTTP service
   curl -I http://mail-1.prod.nbg
   # Output: HTTP/1.1 200 OK

   # Mail service (SMTP)
   telnet mail-1.prod.nbg 25
   # Output: 220 mail.example.com ESMTP Postfix
   ```

3. **Check for errors in logs**:
   ```bash
   ssh root@mail-1.prod.nbg 'journalctl -u <service> -n 50 --no-pager'
   # Look for: startup messages, no error/warning patterns
   ```

4. **Test application functionality**:
   ```bash
   # Example for mail server
   # Send test email, verify delivery
   # Check webmail interface accessible
   # Verify users can connect via IMAP
   ```

5. **Monitor for re-failure**:
   ```bash
   # Check again after 5-10 minutes
   ssh root@mail-1.prod.nbg 'systemctl status <service>'
   # Ensure service hasn't crashed again
   ```

---

### RTO/RPO Estimates

| Recovery Method | RTO | RPO | Notes |
|----------------|-----|-----|-------|
| Automatic systemd restart | <5 min | 0 | No manual intervention, service auto-recovers |
| Manual service restart | <5 min | 0 | Simple restart command |
| Ansible rollback | <20 min | 0 | Config rollback, re-deploy, restart |
| Config re-deployment | <20 min | 0 | Re-template configs, restart |

**RTO Breakdown (Automatic Restart)**:
- Detection: 1-3 minutes (depends on monitoring or user report)
- Automatic restart: 10-30 seconds (systemd RestartSec)
- Service startup: 5-30 seconds (depends on service)
- Verification: <1 minute

**RTO Breakdown (Manual Restart)**:
- Detection: 1-3 minutes
- Decision: <1 minute (determine restart needed)
- Stop service: 5-10 seconds
- Start service: 5-30 seconds
- Verification: <1 minute

**RPO**: Zero - service failures don't cause data loss. Application data persists across restarts.

---

### Escalation Criteria

**Escalate when**:

1. ✅ **Service won't start after 3 restart attempts**
2. ✅ **Service crashes immediately after restart** (crash loop)
3. ✅ **Rollback doesn't resolve failure** - Even previous config fails
4. ✅ **OOM kills persist** - Insufficient resources, need capacity planning
5. ✅ **Application bug suspected** - Logs show software error, not config issue
6. ✅ **Filesystem corruption suspected** - I/O errors in logs
7. ✅ **Multiple services failing** - Indicates system-wide issue

**Escalation Actions**:
- Review application logs for bug patterns
- Check disk space, inode usage: `df -h`, `df -i`
- Check memory usage: `free -h`
- Consider data restoration from backup (see [Section 7](#7-scenario-4-data-loss-accidental-deletion))
- Consider complete system rebuild (see [Section 8](#8-scenario-5-complete-vps-loss-datacenter-failure))
- See [Section 11: Escalation](#11-escalation-and-external-resources)

---

## 7. Scenario 4: Data Loss (Accidental Deletion)

### Overview

**Failure Type**: Application data, user files, or configuration files accidentally deleted, corrupted, or otherwise lost.

**Affected Data Types**:
- Application data: Mail messages, databases, user files
- Configuration files: Ansible-managed configs, application configs
- Git-tracked files: Infrastructure code, deployment configs

**Recovery Strategy**: Restore from restic backup (application data), restore from git history (configuration), or restore from application-specific backups.

---

### Detection Methods

1. **User reports**:
   - "My emails are missing"
   - "Application data disappeared"
   - "Configuration file is empty"

2. **File/directory missing**:
   ```bash
   ssh root@mail-1.prod.nbg 'ls /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data'
   # Output: No such file or directory
   # Or: Directory empty when expected to have files
   ```

3. **Application errors**:
   ```bash
   ssh root@mail-1.prod.nbg 'journalctl -u postfix -n 100 | grep -i error'
   # Output: Error: Cannot open database
   #         Error: Configuration file not found
   ```

4. **Service startup failure**:
   ```bash
   ssh root@mail-1.prod.nbg 'systemctl status postfix'
   # Output: failed - Missing configuration file
   ```

5. **Backup verification finds missing data**:
   ```bash
   restic --repo /mnt/storagebox/restic-mail-backups ls latest | grep important-file
   # Output: File not in latest snapshot (was deleted)
   ```

---

### Recovery Steps

**Step 1: Assess Data Loss Scope**

```bash
# What data is missing?
# - Application data (mail, databases)
# - Configuration files (service configs)
# - Infrastructure code (Nix, Terraform, Ansible)

# When was it deleted?
# - Recent (<1 hour) - likely in latest backup
# - Today (1-24 hours) - likely in yesterday's backup
# - Older (>24 hours) - check backup history

# How much data is affected?
# - Single file
# - Directory
# - Entire volume/filesystem
```

**Step 2: Identify Backup Source**

| Data Type | Backup Source | Restore Procedure | Reference |
|-----------|--------------|------------------|-----------|
| Application data (mail, DB) | Restic backup to Hetzner Storage Box | Restic restore | [backup_verification.md](backup_verification.md) |
| Configuration files (Git-tracked) | Git history | Git restore | [rollback_procedures.md#73](rollback_procedures.md#73-configuration-files-git) |
| Infrastructure code | Git history | Git restore | [rollback_procedures.md#73](rollback_procedures.md#73-configuration-files-git) |
| Non-backed-up data | No backup available | Data loss, recreate | N/A |

**Step 3: Determine Recovery Method**

**Option A: Restore from Restic Backup (Application Data)**

For application data on production VPS:

1. **Stop services** (prevent data corruption during restore):
   ```bash
   ssh root@mail-1.prod.nbg 'systemctl stop postfix dovecot'
   ssh root@mail-1.prod.nbg 'docker-compose -f /opt/mailcow-dockerized/docker-compose.yml down'
   ```

2. **List available snapshots**:
   ```bash
   ssh root@mail-1.prod.nbg
   export RESTIC_PASSWORD=$(grep RESTIC_PASSWORD /etc/restic/backup.env | cut -d= -f2)
   export RESTIC_REPOSITORY="/mnt/storagebox/restic-mail-backups"

   restic snapshots
   # Output: List of backup snapshots with timestamps
   # Identify snapshot ID before data loss occurred
   ```

3. **Verify snapshot contains data**:
   ```bash
   restic ls <snapshot-id> | grep <missing-file-or-directory>
   # Output: Should show the missing data exists in snapshot
   ```

4. **Restore data**:
   ```bash
   # Option 1: Restore to original location (overwrites)
   restic restore <snapshot-id> --target / --include /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data

   # Option 2: Restore to temp location for inspection (safer)
   restic restore <snapshot-id> --target /tmp/restore
   # Then manually copy files: cp -a /tmp/restore/... /original/location/
   ```

5. **Verify data restored**:
   ```bash
   ls -lh /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data
   # Check file count, sizes, timestamps

   du -sh /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data
   # Compare with expected data size
   ```

6. **Restart services**:
   ```bash
   docker-compose -f /opt/mailcow-dockerized/docker-compose.yml up -d
   systemctl start postfix dovecot
   ```

7. **Verify application functionality**:
   ```bash
   # Check service status
   systemctl status postfix dovecot

   # Check application logs
   journalctl -u postfix -n 50 --no-pager

   # Test application (send/receive email, access webmail)
   ```

For detailed restic restore procedures (including database restore, point-in-time recovery), see [backup_verification.md](backup_verification.md).

**Time**: <4 hours (depends on data volume, network speed, verification time)

**RPO**: 1-24 hours (daily backup schedule)

---

**Option B: Restore from Git History (Configuration Files)**

For Git-tracked configuration files:

```bash
# Identify when file was deleted
git log --oneline --all --full-history -- path/to/deleted/file

# View file content from previous commit
git show HEAD~1:path/to/deleted/file

# Restore file from specific commit
git checkout <commit-hash> -- path/to/deleted/file

# Or restore from most recent commit
git checkout HEAD~1 -- path/to/deleted/file

# Stage and commit restoration
git add path/to/deleted/file
git commit -m "Restore accidentally deleted file"

# Re-deploy if needed
just ansible-deploy  # If Ansible-managed file
sudo nixos-rebuild switch --flake .#xmsi  # If NixOS config
```

For detailed git restore procedure, see [rollback_procedures.md#73](rollback_procedures.md#73-configuration-files-git).

**Time**: <30 minutes (quick git restore, re-deployment if needed)

**RPO**: Zero (git history preserved)

---

**Option C: No Backup Available**

If data was not backed up:

1. **Assess recreatability**: Can data be regenerated or is it lost forever?
2. **Check alternative sources**:
   - Application logs might contain some data
   - Other systems might have copies (Syncthing sync, email sent copies)
   - Users might have local copies
3. **Document data loss**: Record what was lost, when, how, for post-incident review
4. **Implement backup**: Add missing data to backup coverage (update restic paths)

---

### Verification Procedures

**After Data Restoration**:

1. **Verify files restored**:
   ```bash
   # Check file existence
   ls -lh /path/to/restored/data

   # Check file count (compare with backup manifest)
   find /path/to/restored/data -type f | wc -l

   # Check disk usage (should match pre-deletion size)
   du -sh /path/to/restored/data
   ```

2. **Verify file permissions and ownership**:
   ```bash
   # Check ownership
   ls -lh /path/to/restored/data | head -20

   # Fix permissions if needed (example for mailcow)
   chown -R 5000:5000 /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data
   chmod -R 750 /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data
   ```

3. **Verify data integrity**:
   ```bash
   # For databases: Run integrity check
   ssh root@mail-1.prod.nbg 'docker exec mailcowdockerized-mysql-mailcow-1 mysqlcheck --all-databases'

   # For files: Check for corruption
   find /path/to/restored/data -type f -name "*.eml" -exec file {} \; | grep -v "mail message"
   # Empty output = all files are valid mail messages
   ```

4. **Test application functionality**:
   ```bash
   # Example for mail server
   # - Send test email, verify delivery
   # - Access webmail, verify emails visible
   # - Check user can login via IMAP
   ```

5. **Document RPO (actual data loss)**:
   ```bash
   # What was the time difference between:
   # - Last backup snapshot timestamp
   # - Time of data deletion
   # This is your actual RPO for this incident

   restic snapshots --last 5
   # Note timestamp of snapshot used for restore
   ```

---

### RTO/RPO Estimates

| Data Type | Backup Source | RTO | RPO | Notes |
|-----------|--------------|-----|-----|-------|
| Configuration files | Git history | <30 min | 0 | Instant restore, re-deployment if needed |
| Small application data (<1GB) | Restic backup | <1 hour | 1-24 hours | Fast restore, quick verification |
| Large application data (1-100GB) | Restic backup | <4 hours | 1-24 hours | Network transfer time, extensive verification |
| Database dumps | Restic backup | <2 hours | 1-24 hours | Restore + database import time |

**RTO Breakdown (Application Data Restore)**:
- Detection: 5-15 minutes (user report or monitoring)
- Assessment: 5-10 minutes (identify data loss scope)
- Snapshot selection: 2-5 minutes (find correct backup)
- Stop services: 1-2 minutes
- Restore data: 15 minutes - 2 hours (depends on data size)
- Verify data: 10-30 minutes (file counts, integrity checks)
- Start services: 1-2 minutes
- Test application: 5-10 minutes

**RPO**:
- **Configuration files**: Zero (git history)
- **Application data**: 1-24 hours (daily backup at 02:00 UTC)
- **Worst case**: Data modified between last backup and deletion is lost
- **Best case**: Data in latest backup, minimal loss

**RPO Example**:
- Last backup: Today 02:15 UTC
- Deletion occurred: Today 14:00 UTC
- Restore from: Today 02:15 UTC snapshot
- Data loss: Changes between 02:15-14:00 (approximately 12 hours)

---

### Escalation Criteria

**Escalate when**:

1. ✅ **No backup exists for deleted data** - Data loss is permanent
2. ✅ **Backup is corrupted** - `restic check` reports errors
3. ✅ **Data loss exceeds RPO tolerance** - >24 hours data lost
4. ✅ **Multiple backup snapshots affected** - Deletion propagated to multiple backups
5. ✅ **Restore fails after 2 attempts** - Technical issue with restoration
6. ✅ **Restored data is corrupted** - Backup contains corrupted data
7. ✅ **Critical business data lost** - Requires stakeholder notification

**Escalation Actions**:
- Attempt restore from older snapshots (trade RPO for working backup)
- Check restic repository integrity: `restic check --read-data`
- Consider Hetzner Storage Box recovery options (snapshots, trash)
- Document data loss for stakeholder communication
- Review backup policy: Increase frequency, add verification
- See [Section 11: Escalation](#11-escalation-and-external-resources)

---

## 8. Scenario 5: Complete VPS Loss (Datacenter Failure)

### Overview

**Failure Type**: Complete loss of VPS due to datacenter failure, accidental deletion, hardware failure, or Hetzner Cloud incident.

**Affected Systems**:
- `mail-1.prod.nbg` - Mail server (Postfix, Dovecot, mailcow)
- `syncthing-1.prod.hel` - Syncthing file sync
- `test-1.dev.nbg` - Test environment

**Recovery Strategy**: Full system rebuild via three-phase recovery:
1. **Phase 1**: Provision new infrastructure (Terraform)
2. **Phase 2**: Deploy configuration (Ansible)
3. **Phase 3**: Restore application data (Restic)

---

### Detection Methods

1. **No SSH access**:
   ```bash
   ssh root@mail-1.prod.nbg
   # Output: Connection timed out / No route to host
   ```

2. **Hetzner console shows offline or missing**:
   ```bash
   hcloud server list
   # Output: Server not in list, or status: off

   hcloud server describe mail-1.prod.nbg
   # Output: Error: server not found
   ```

3. **All services down**:
   ```bash
   curl http://mail-1.prod.nbg
   # Output: Connection refused

   ping mail-1.prod.nbg
   # Output: Request timeout
   ```

4. **Hetzner status page**:
   - Check https://status.hetzner.com/ for datacenter incidents
   - Hetzner email notification about server deletion or incident

---

### Recovery Steps

**Phase 1: Provision Infrastructure (Terraform)**

**Estimated Time**: 10-15 minutes

```bash
cd /path/to/infra

# Step 1: Verify current Terraform state
just tf-plan
# Output: Shows missing server resource

# Step 2: Remove destroyed server from state (if present)
cd terraform/
tofu state rm 'hcloud_server.mail-1'
# Or: tofu state rm 'hcloud_server.syncthing-1'
# Or: tofu state rm 'hcloud_server.test-1'

# Step 3: Ensure resource definition exists in servers.tf
# (Should already be defined, but verify)
cat servers.tf | grep -A 20 'resource "hcloud_server" "mail-1"'

# Step 4: Apply Terraform to provision new server
just tf-apply
# Output: Creates new server, assigns IP, attaches to network

# Step 5: Verify server created
hcloud server list
# Output: Shows new server in list, status: running

hcloud server describe mail-1.prod.nbg
# Output: Server details, IP addresses, datacenter

# Step 6: Test SSH access (will fail, OS not configured yet)
ssh root@<new-ip-address>
# Output: Connection refused (expected, no SSH keys yet)
```

**Verification**:
- ✅ Server visible in Hetzner console
- ✅ Server has public IP address
- ✅ Server attached to private network
- ✅ Server in running state

For detailed Terraform provisioning procedure, see [rollback_procedures.md#81](rollback_procedures.md#81-vps-deleted-via-hetzner-console-or-api).

---

**Phase 2: Deploy Configuration (Ansible)**

**Estimated Time**: 20-30 minutes

```bash
# Step 1: Update Ansible inventory with new IP
just ansible-inventory-update
# Output: Updates inventory/hosts.yaml with new server IP from Terraform

# Step 2: Verify inventory updated
cd ansible/
cat inventory/hosts.yaml | grep mail-1.prod.nbg
# Output: Shows new IP address

# Step 3: Test connectivity (will fail if SSH not configured)
just ansible-ping
# Output: mail-1.prod.nbg | UNREACHABLE

# Step 4: Bootstrap server (first-time setup)
just ansible-bootstrap
# This playbook:
# - Configures SSH keys
# - Installs base packages (python3, apt packages)
# - Sets up user accounts
# - Configures firewall
# - Mounts Hetzner Storage Box

# Step 5: Verify bootstrap succeeded
just ansible-ping
# Output: mail-1.prod.nbg | SUCCESS

# Step 6: Deploy application configuration
just ansible-deploy-env prod
# Or: just ansible-deploy (all environments)
# This playbook:
# - Deploys service configurations
# - Installs application packages
# - Creates systemd services
# - Configures application settings
# - Does NOT restore application data

# Step 7: Verify deployment succeeded
ssh root@mail-1.prod.nbg 'systemctl list-units --type=service --state=running'
# Output: Shows deployed services (may not be fully functional without data)
```

**Verification**:
- ✅ SSH access works
- ✅ Ansible can connect (`ansible-ping` succeeds)
- ✅ Services deployed (systemd units created)
- ✅ Configuration files in place
- ⚠️ Services may not start yet (missing application data)

For detailed Ansible bootstrap procedure, see [rollback_procedures.md#82](rollback_procedures.md#82-hardware-failure-vps-unrecoverable).

---

**Phase 3: Restore Application Data (Restic)**

**Estimated Time**: 1-4 hours (depends on data volume)

```bash
# Step 1: Verify Storage Box is mounted
ssh root@mail-1.prod.nbg 'df -h | grep storagebox'
# Output: /mnt/storagebox mounted

# Step 2: Set up restic environment
ssh root@mail-1.prod.nbg
export RESTIC_PASSWORD=$(grep RESTIC_PASSWORD /etc/restic/backup.env | cut -d= -f2)
export RESTIC_REPOSITORY="/mnt/storagebox/restic-mail-backups"

# Step 3: List available snapshots
restic snapshots
# Output: List of backup snapshots with timestamps

# Step 4: Identify snapshot to restore (usually latest)
restic snapshots --last 1
# Output: Most recent snapshot ID and timestamp

# Step 5: Stop services (prevent conflicts during restore)
systemctl stop postfix dovecot
docker-compose -f /opt/mailcow-dockerized/docker-compose.yml down

# Step 6: Restore application data
# Option A: Restore all backed-up paths
restic restore latest --target /

# Option B: Restore specific paths (more control)
restic restore latest --target / \
  --include /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data \
  --include /var/lib/docker/volumes/mailcowdockerized_mysql-vol-1/_data \
  --include /opt/mailcow-dockerized/data

# Step 7: Verify data restored
du -sh /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data
# Output: Data size matches expected size

ls -lh /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data | head -20
# Output: Files present with correct timestamps

# Step 8: Fix permissions if needed
chown -R 5000:5000 /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data
chmod -R 750 /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data

# Step 9: Start services
docker-compose -f /opt/mailcow-dockerized/docker-compose.yml up -d
systemctl start postfix dovecot

# Step 10: Verify services started
systemctl status postfix dovecot
docker ps  # Check mailcow containers running
```

**Verification**:
- ✅ Application data restored (files present)
- ✅ File permissions correct
- ✅ Services started successfully
- ✅ No errors in service logs

For detailed restic restore procedures (including database restore, verification), see [backup_verification.md](backup_verification.md).

---

**Phase 4: Verify Full Recovery**

**Estimated Time**: 10-20 minutes

```bash
# 1. Check all services running
ssh root@mail-1.prod.nbg 'systemctl --failed'
# Output: No failed services

# 2. Check service logs for errors
ssh root@mail-1.prod.nbg 'journalctl -u postfix -n 50 --no-pager'
ssh root@mail-1.prod.nbg 'journalctl -u dovecot -n 50 --no-pager'
# Output: Normal startup messages, no errors

# 3. Test application functionality
curl http://mail-1.prod.nbg
# Output: HTTP 200 OK, webmail interface

telnet mail-1.prod.nbg 25
# Output: 220 mail.example.com ESMTP Postfix

telnet mail-1.prod.nbg 143
# Output: * OK [CAPABILITY ...] Dovecot ready

# 4. Test mail delivery (send test email)
# - Send email to test account
# - Verify delivery in logs
# - Check email accessible via webmail/IMAP

# 5. Verify backups still working
ssh root@mail-1.prod.nbg 'systemctl status restic-backup.timer'
# Output: Timer active, next backup scheduled

# 6. Update DNS if IP changed
# If public IP changed, update DNS A/AAAA records:
just tf-output
# Note new IP address, update DNS provider

# 7. Update monitoring (when Iteration 7 deployed)
# - Update Prometheus targets with new IP
# - Verify monitoring alerts working

# 8. Document recovery
# - Record RTO (actual recovery time)
# - Record RPO (data loss from backup age)
# - Update incident log
```

---

### Complete Recovery Timeline Example

**Scenario**: Mail server (mail-1.prod.nbg) completely lost due to accidental deletion.

| Phase | Activity | Time | Cumulative |
|-------|----------|------|------------|
| **Detection** | Noticed services down, confirmed server deleted | 5 min | 0:05 |
| **Assessment** | Checked Hetzner console, verified complete loss | 5 min | 0:10 |
| **Phase 1** | Removed from Terraform state, re-applied | 15 min | 0:25 |
| | Verified new server created in Hetzner | 2 min | 0:27 |
| **Phase 2** | Updated Ansible inventory | 2 min | 0:29 |
| | Ran bootstrap playbook | 10 min | 0:39 |
| | Ran deployment playbook | 15 min | 0:54 |
| | Verified services deployed | 3 min | 0:57 |
| **Phase 3** | Listed restic snapshots | 2 min | 0:59 |
| | Stopped services for restore | 1 min | 1:00 |
| | Restored data from restic (50GB) | 90 min | 2:30 |
| | Fixed permissions | 5 min | 2:35 |
| | Started services | 2 min | 2:37 |
| **Phase 4** | Verified services running | 5 min | 2:42 |
| | Tested mail functionality | 10 min | 2:52 |
| | Updated DNS records | 5 min | 2:57 |
| | Documented recovery | 10 min | 3:07 |
| **Total** | | | **3:07** |

**Actual RTO**: 3 hours 7 minutes (faster than 8-hour target)
**Actual RPO**: 8 hours (data restored from 02:15 UTC backup, loss occurred at 10:00 UTC)

---

### RTO/RPO Estimates

| Phase | Activity | Time | Notes |
|-------|----------|------|-------|
| Detection & Assessment | Identify complete loss | 10-15 min | Depends on monitoring or user report |
| Phase 1: Infrastructure | Terraform provision | 10-15 min | API calls, server boot time |
| Phase 2: Configuration | Ansible bootstrap + deploy | 20-30 min | Package installation, config deployment |
| Phase 3: Data Restore | Restic restore | 1-4 hours | **Depends on data volume and network** |
| Phase 4: Verification | Testing and validation | 10-20 min | Service checks, functionality tests |
| **Total RTO** | | **2-5 hours typical, <8 hours maximum** | |

**RTO Variables**:
- **Data volume**: 10GB = 1 hour, 50GB = 2 hours, 100GB = 4 hours (approximate)
- **Network speed**: Hetzner internal network is fast, but large restores take time
- **Complexity**: Mail server recovery more complex than simple applications
- **Operator experience**: Experienced operator can parallelize phases

**RPO**: 1-24 hours (depends on backup age)
- **Best case**: Last backup 1 hour old = 1 hour data loss
- **Worst case**: Last backup 24 hours old = 24 hours data loss
- **Typical**: Daily backups at 02:00 UTC, so RPO = time since 02:00

**RPO Calculation Example**:
- Last backup: Yesterday 02:15 UTC
- Server lost: Today 14:00 UTC
- Time difference: ~36 hours
- **However**: Daily backups, so maximum data loss is from yesterday 02:15 to today 02:15 (24 hours), plus today 02:15 to 14:00 (12 hours) = **36 hours RPO**
- **Wait**: If today's backup ran successfully, RPO is only 14:00 - 02:15 = **12 hours**

**Improving RTO/RPO**:
- **RTO**: Automate recovery scripts, practice recovery procedures
- **RPO**: Increase backup frequency (6-hour backups instead of daily)

---

### Escalation Criteria

**Escalate when**:

1. ✅ **Terraform provisioning fails** - Cannot create new server (API errors, quota exceeded)
2. ✅ **Ansible bootstrap fails** - Cannot configure new server (network issues, package errors)
3. ✅ **No backup available** - Restic repository empty or corrupted
3. ✅ **Backup restore fails** - Restic errors, corrupted snapshots
4. ✅ **Services won't start after restore** - Application errors, config incompatibility
5. ✅ **Data volume too large** - Restore exceeds 8-hour RTO target
6. ✅ **Multiple servers lost simultaneously** - Datacenter-wide incident
7. ✅ **DNS/external dependencies affected** - Recovery requires external changes

**Escalation Actions**:
- Contact Hetzner support (server provisioning issues, network problems)
- Review backup verification logs (when was last successful backup verification?)
- Consider alternative restore locations (restore to different datacenter)
- Prioritize critical services (restore mail first, defer test systems)
- Communicate with stakeholders (set expectations for extended RTO)
- See [Section 11: Escalation](#11-escalation-and-external-resources)

---

## 8.1. Scenario 6: Intermittent Connectivity During Recovery

**Symptoms**:
- SSH connections work initially but timeout after 5-15 minutes
- Long-running operations (Ansible, backups) succeed but manual commands fail
- Connection timeouts occur randomly, not consistently
- Server shows "running" status in cloud console but SSH is unreachable

**Detection**:
1. SSH connection works initially: `ssh root@server 'hostname'` succeeds
2. Later SSH attempts timeout: `ssh: connect to host X.X.X.X port 22: Operation timed out`
3. Server shows "running" in `hcloud server list` (not a server failure)
4. Long operations complete (e.g., Ansible playbooks) but short commands fail

**Root Cause Investigation**:
1. **Test from alternative network** (mobile hotspot, VPN): `ssh root@server 'hostname'`
   - If works from alternative network → local ISP/firewall issue
   - If fails from all networks → Hetzner routing or server network issue
2. **Test other Hetzner servers**: `ssh root@mail-1.prod.nbg 'hostname'`
   - If other servers work → issue specific to one server/IP
   - If all servers fail → broader connectivity problem
3. **Check SSH daemon on server** (via Hetzner Console):
   - `systemctl status sshd` (should be active/running)
   - `journalctl -u sshd -n 50` (check for connection logs)
4. **Check for SSH timeout pattern**:
   - Does timeout occur at consistent interval (e.g., exactly 300 seconds)?
   - Does connection work after server reboot? How long until timeout recurs?
   - Based on test DRT-2025-10-30-003: Connectivity may self-stabilize after 15-30 minutes

**Workarounds**:

**Primary Workaround - Wait for Stabilization**:
```bash
# If SSH times out, wait 15-30 minutes and retry
# Test DRT-2025-10-30-003 showed connectivity self-stabilized after 15 minutes
sleep 900  # Wait 15 minutes
ssh root@server 'hostname'  # Retry connection
```

**Alternative 1 - Hetzner Cloud Console**:
```bash
# Request console access via CLI (returns WebSocket URL)
hcloud server request-console test-1.dev.nbg
# Open returned wss:// URL in browser, log in via web terminal
```

Or via web UI:
1. Navigate to https://console.hetzner.cloud/
2. Select server → Click "Console" button
3. Log in as root (may require password reset)
4. Execute recovery commands directly in web terminal

**Alternative 2 - SSH Keepalive Configuration**:
Add to `~/.ssh/config`:
```
Host 5.75.134.87
    ServerAliveInterval 30
    ServerAliveCountMax 3
    TCPKeepAlive yes
```

**Alternative 3 - Batch Operations in Single Session**:
```bash
# Execute all commands in single SSH session (avoid reconnecting)
ssh root@server 'bash -s' <<'EOF'
  export RESTIC_REPOSITORY="/mnt/storagebox/restic-dev-backups"
  export RESTIC_PASSWORD="..."
  restic snapshots
  restic restore latest --target /tmp/restore-test
  find /tmp/restore-test -type f
  sha256sum /tmp/restore-test/etc/hostname /etc/hostname
EOF
```

**Alternative 4 - Proxy via Stable Server**:
SSH to mail-1, then SSH to test-1 via private network:
```bash
ssh root@mail-1.prod.nbg 'ssh root@10.0.0.4 "commands"'
```

**Prevention**:
- **Run sustained connectivity test** before critical recovery operations (see recovery_testing_plan.md Section 5.4 Pre-Flight Connectivity Validation)
- **Consider Hetzner Cloud Console** for recovery operations with known connectivity issues
- **Document alternative access methods** in advance (VPN, proxy, Console)
- **Add SSH keepalive** to reduce timeout likelihood
- **Be patient**: If SSH fails initially, wait 15-30 minutes before switching to alternative methods

**Recovery Steps**:
1. **Attempt connection**: Try SSH to verify failure
2. **Wait 15-30 minutes**: Connectivity may self-stabilize (based on test DRT-2025-10-30-003)
3. **Retry SSH**: Check if connectivity restored after waiting
4. **If still failing**: Switch to Hetzner Cloud Console (web terminal)
5. **Document pattern**: Note when timeouts occur, duration, any recovery triggers

**RTO Impact**: Connectivity issues can add 15-30 minutes delay to recovery operations. Factor this into RTO calculations for affected systems. If using Hetzner Cloud Console, add 5-10 minutes for access setup (password reset, browser setup).

**Known Affected Systems**:
- test-1.dev.nbg (documented in tests DRT-2025-10-30-002, DRT-2025-10-30-003)
- IP 5.75.134.87 (may be IP-specific routing issue)

**When to Escalate**:
- Connectivity does not stabilize after 30 minutes
- Hetzner Cloud Console also inaccessible
- Multiple servers affected simultaneously
- Recovery blocked for >1 hour due to connectivity

---

## 9. RTO/RPO Summary

**Recovery Time Objective (RTO)**: Maximum acceptable downtime for service restoration
**Recovery Point Objective (RPO)**: Maximum acceptable data loss measured in time

### RTO/RPO by Failure Scenario

| Scenario | Detection Method | RTO Target | RPO | Notes |
|----------|------------------|------------|-----|-------|
| **Configuration Error** | Build failure, boot failure, service failed state | **<5 min** | **0** | No data loss, rollback to previous generation |
| **Infrastructure Error** | Terraform apply failure, state inconsistency | **<30 min** | **0** | Infrastructure recreation, no data involved |
| **Service Failure** | Service down, no HTTP response, systemd failed | **<5 min automatic, <20 min manual** | **0** | Systemd auto-restart, or manual restart |
| **Data Loss** | Missing files, user report, application errors | **<4 hours** | **1-24 hours** | Restore from restic backup |
| **Complete VPS Loss** | No SSH, server missing from Hetzner | **<8 hours** | **1-24 hours** | Full rebuild: provision + deploy + restore |

### RTO/RPO by System

| System | Primary Services | RTO Target | RPO Target | Backup Method | Criticality |
|--------|------------------|------------|------------|---------------|-------------|
| **xbook** | Development workstation (Darwin) | 1 hour | 0 | Git (continuous), Time Machine (hourly) | Low |
| **xmsi** | Desktop workstation (NixOS) | 1 hour | 0 | Git (continuous), local snapshots | Low |
| **srv-01** | Local server (NixOS, future) | 4 hours | 1 hour | Git (continuous), restic (daily) | Medium |
| **mail-1.prod.nbg** | Mail server (Postfix, Dovecot, mailcow) | **4 hours** | **1 hour** | Restic to Storage Box (daily 02:00 UTC) | **High** |
| **syncthing-1.prod.hel** | File synchronization | 8 hours | 1 day | Syncthing replication (no backup needed) | Medium |
| **test-1.dev.nbg** | Test environment | Best effort | No requirement | No backup (ephemeral) | Low |

**Criticality Definitions**:
- **High**: Production service with user impact, requires immediate response
- **Medium**: Important but non-critical, can tolerate longer outage
- **Low**: Development/personal systems, minimal business impact

---

### RTO Assumptions

For RTO targets to be achievable, the following assumptions must hold:

1. ✅ **Operator availability**: Operator can respond within 15 minutes of incident detection
2. ✅ **Backup exists**: Recent restic backup available and verified working
3. ✅ **State files intact**: Terraform state (`terraform.tfstate`) and git history accessible
4. ✅ **Network available**: Internet connectivity for API calls, package downloads, restic restore
5. ✅ **Credentials accessible**: SOPS age keys, Hetzner API token, SSH keys available
6. ✅ **Monitoring functional**: Incidents detected promptly (currently manual, automated in I7)
7. ✅ **Documentation accessible**: Runbooks available (not stored only on failed system)

**If assumptions violated**, see [Degraded Mode RTO/RPO](#degraded-mode-rtorpo).

---

### RPO Assumptions

For RPO targets to be achievable, the following assumptions must hold:

1. ✅ **Backup schedule running**: Daily restic backups executing successfully at 02:00 UTC
2. ✅ **Backup verification passing**: Quarterly backup restore tests successful
3. ✅ **Storage Box accessible**: Hetzner Storage Box mounted and writable
4. ✅ **Sufficient storage**: Storage Box has capacity for retention policy (7 daily, 4 weekly, 12 monthly)
5. ✅ **Git commits frequent**: Configuration changes committed regularly (not uncommitted local changes)
6. ✅ **No local modifications**: Production systems don't have uncommitted config changes

**If assumptions violated**, see [Degraded Mode RTO/RPO](#degraded-mode-rtorpo).

---

### Degraded Mode RTO/RPO

If critical assumptions are violated, RTO/RPO degrade significantly:

| Degraded Condition | Impact on RTO | Impact on RPO | Mitigation |
|--------------------|---------------|---------------|------------|
| **No backup exists** | +4 hours (no data restore possible) | **Data loss permanent** | Accept data loss, rebuild from scratch |
| **Backup corrupted** | +2 hours (try older snapshots) | +24-168 hours (older backup) | Restore from weekly/monthly snapshot |
| **Terraform state lost** | +2 hours (manual import to state) | 0 (infra can be recreated) | Rebuild state via `tofu import` |
| **SOPS keys lost** | +4 hours (reconfigure secrets) | 0 (secrets can be reset) | Manual secret provisioning |
| **Network outage** | **Cannot recover** (external dependency) | No additional impact | Wait for network restoration |
| **Operator unavailable** | **RTO = time to operator arrival** | +RPO for each hour delayed | Automated alerting, on-call rotation |
| **Multiple systems down** | **RTO × number of systems** | No additional impact (parallel restore) | Prioritize critical systems first |

**Example Degraded Scenario**:

**Situation**: Mail server lost, but last successful backup was 3 days ago (backup job failing).

- **Normal RTO**: 4 hours (provision + deploy + restore)
- **Normal RPO**: 1-24 hours (daily backup)
- **Degraded RPO**: **3 days** (last successful backup)
- **Decision**: Proceed with recovery using 3-day-old backup, accept 3 days data loss
- **Action**: Investigate backup failure after recovery (see [backup_verification.md](backup_verification.md))

---

### RTO/RPO Improvement Opportunities

**To improve RTO** (reduce recovery time):

1. **Automate recovery**: Create recovery scripts for common scenarios (see [Section 10](#10-disaster-recovery-testing))
2. **Practice recovery**: Regular disaster recovery drills (quarterly, see I5.T4)
3. **Parallel recovery**: Restore multiple systems simultaneously (requires additional operators)
4. **Pre-staged resources**: Keep warm standby servers (expensive, not recommended for homelab)
5. **Faster backups**: Use incremental restores, restore only critical data first

**To improve RPO** (reduce data loss):

1. **Increase backup frequency**: 6-hour or hourly backups instead of daily
2. **Continuous replication**: Use database replication for critical data (complex)
3. **Application-level backups**: More frequent application-specific backups
4. **Snapshot-based backups**: Use filesystem snapshots (ZFS, Btrfs) for instant recovery points
5. **Monitoring backup status**: Alert on backup failures immediately (Iteration 7)

**Cost-benefit analysis** (for homelab context):

- **Current**: Daily backups, manual recovery = Low cost, acceptable RTO/RPO for homelab
- **Hourly backups**: Higher storage cost, 1-hour RPO = Medium cost, marginal benefit
- **Continuous replication**: High complexity, near-zero RPO = High cost, overkill for homelab

**Recommendation**: Current RTO/RPO targets are appropriate for single-operator homelab. Focus on **reliability** (ensuring backups run successfully) rather than **frequency** (more backups).

---

## 10. Disaster Recovery Testing

### Purpose

Regular disaster recovery testing validates that:
1. ✅ Backups are restorable (not corrupted)
2. ✅ Recovery procedures are accurate and complete
3. ✅ RTO/RPO targets are achievable
4. ✅ Operator is familiar with recovery process
5. ✅ Dependencies and assumptions are documented

**Without testing, disaster recovery plans are theoretical and may fail when needed most.**

---

### Testing Strategy

**Quarterly Disaster Recovery Drills** (see I5.T4: Recovery Testing Plan):

1. **Q1**: Configuration error recovery (NixOS rollback)
2. **Q2**: Data loss recovery (restic restore to test system)
3. **Q3**: Service failure recovery (application restart procedures)
4. **Q4**: Complete system loss (full rebuild of test-1.dev.nbg)

**Testing Principles**:
- **Non-disruptive**: Use test systems (test-1.dev.nbg) or non-production hours
- **Documented**: Record actual RTO/RPO achieved, note discrepancies
- **Comprehensive**: Test full recovery path, not just individual components
- **Realistic**: Simulate actual failure conditions (don't take shortcuts)

---

### Test Scenarios

**Test 1: Configuration Rollback** (validates Scenario 1)

**Frequency**: Quarterly
**System**: test-1.dev.nbg or xmsi (non-production hours)
**Duration**: 30 minutes

**Procedure**:
1. Introduce intentional configuration error
2. Attempt deployment (should fail)
3. Rollback using documented procedure
4. Verify system operational
5. Record RTO achieved

**Success criteria**: System recovered within 5 minutes RTO

---

**Test 2: Data Restore** (validates Scenario 4)

**Frequency**: Quarterly
**System**: mail-1.prod.nbg (non-production hours recommended)
**Duration**: 2 hours

**Procedure**:
1. Identify non-critical test data to restore
2. Follow restic restore procedure from [backup_verification.md](backup_verification.md)
3. Restore to temporary location (not production)
4. Verify data integrity and completeness
5. Record restore time and data volume

**Success criteria**: Data restored successfully, RTO <4 hours verified

---

**Test 3: Complete System Rebuild** (validates Scenario 5)

**Frequency**: Annually
**System**: test-1.dev.nbg (can be destroyed safely)
**Duration**: Half day (4-6 hours)

**Procedure**:
1. Delete test-1.dev.nbg server via Hetzner console
2. Follow complete rebuild procedure (Section 8)
   - Phase 1: Terraform provision
   - Phase 2: Ansible deploy
   - Phase 3: Data restore (if applicable)
   - Phase 4: Verification
3. Record time for each phase
4. Note any deviations from documented procedure
5. Update runbook with lessons learned

**Success criteria**: System fully operational, RTO <8 hours achieved

---

### Testing Documentation

**For each test, record**:

- **Test date and time**
- **Operator(s) performing test**
- **Failure scenario tested**
- **Systems involved**
- **Actual RTO achieved** (compare to target)
- **Actual RPO** (if data restore involved)
- **Issues encountered** (procedure gaps, errors, outdated commands)
- **Lessons learned**
- **Runbook updates needed**

**Example Test Report**:

```markdown
## Disaster Recovery Test Report

**Test ID**: DR-2025-Q2-001
**Test Date**: 2025-04-15
**Operator**: mi-skam
**Scenario**: Data Loss Recovery (Scenario 4)
**System**: mail-1.prod.nbg

### Procedure Followed
- Followed [backup_verification.md] restic restore procedure
- Restored mailbox for test user to /tmp/restore
- Verified data integrity

### Results
- **RTO Target**: <4 hours
- **Actual RTO**: 1 hour 23 minutes
- **RPO**: 8 hours (last backup 8 hours before test)
- **Data Volume**: 2.3 GB
- **Success**: ✅ PASS

### Issues Encountered
1. Restic password not in documented location (found in /etc/restic/backup.env)
2. Permissions reset needed after restore (not documented in runbook)

### Lessons Learned
- Restic restore is faster than expected for small data volumes
- Permission reset is critical step, should be emphasized in runbook

### Actions
- [ ] Update backup_verification.md with permission reset step
- [ ] Clarify restic password location in runbook prerequisites
- [ ] Schedule next test for Q3 (service failure scenario)
```

---

### Integration with Backup Verification

This disaster recovery runbook complements the detailed testing procedures in:
- **[backup_verification.md](backup_verification.md)**: Detailed restic backup and restore procedures

For backup verification procedures, see that runbook. This disaster recovery runbook focuses on **when** and **why** to use those procedures during actual incidents.

---

## 11. Escalation and External Resources

### When to Escalate

Escalation is necessary when:

1. ✅ **Recovery procedure fails after 2 attempts** - Technical issue preventing recovery
2. ✅ **Failure cause unclear after 30 minutes investigation** - Need expert diagnosis
3. ✅ **Data loss exceeds RPO tolerance** (>24 hours) - Business impact assessment needed
4. ✅ **Multiple cascading failures** - Systemic issue, not isolated incident
5. ✅ **RTO target will be exceeded** - Need to communicate delay
6. ✅ **External dependencies affected** - DNS, Hetzner, network provider issues
7. ✅ **Security incident suspected** - Unauthorized access, malware, compromise
8. ✅ **Resource constraints** (time, expertise, access) - Need assistance

**Escalation is NOT failure - it's recognizing when additional resources are needed.**

---

### Escalation Levels

**Level 1: Self-Service** (0-30 minutes)

**Available resources**:
- This disaster recovery runbook
- [rollback_procedures.md](rollback_procedures.md) - Detailed recovery procedures
- [backup_verification.md](backup_verification.md) - Backup restoration procedures
- [deployment_procedures.md](deployment_procedures.md) - Normal deployment procedures
- [CLAUDE.md](CLAUDE.md) - Infrastructure overview and commands

**Actions**:
- Follow documented procedures for failure scenario
- Search runbooks for error messages or symptoms
- Review git history for recent changes
- Check system logs for failure cause

**Decision point**: If not resolved in 30 minutes, escalate to Level 2.

---

**Level 2: External Documentation** (30-60 minutes)

**Available resources**:
- Hetzner Cloud documentation: https://docs.hetzner.com/cloud/
- NixOS manual: https://nixos.org/manual/nixos/stable/
- Ansible documentation: https://docs.ansible.com/
- Restic documentation: https://restic.readthedocs.io/
- OpenTofu documentation: https://opentofu.org/docs/

**Actions**:
- Search official documentation for error messages
- Check community forums (NixOS Discourse, Reddit, Stack Overflow)
- Review GitHub issues for known bugs in tools (Nix, Terraform, Ansible)
- Check Hetzner status page: https://status.hetzner.com/

**Decision point**: If not resolved in 60 minutes total, escalate to Level 3.

---

**Level 3: Vendor Support** (60+ minutes)

**Available resources**:
- **Hetzner support**: For infrastructure issues (server not booting, network outages, API errors)
  - Support ticket: https://accounts.hetzner.com/support/tickets
  - Phone support: Available for datacenter incidents
  - Response time: Usually within hours for urgent issues

**When to contact Hetzner**:
- ✅ Server won't boot, console shows hardware errors
- ✅ Network connectivity issues (private network, public IP)
- ✅ API errors persist (authentication, quota, rate limiting)
- ✅ Datacenter incident suspected (multiple servers affected)
- ✅ Storage Box access issues (mounting, permissions)

**Information to provide**:
- Server ID or name (e.g., mail-1.prod.nbg)
- Error messages (exact text, screenshots)
- Timeline (when did issue start, what changed)
- Troubleshooting steps already taken

---

**Level 4: Community / Professional Help** (Complex issues)

**Available resources**:
- **NixOS community**:
  - Discourse: https://discourse.nixos.org/ (questions, troubleshooting)
  - IRC/Matrix: #nixos channel (real-time help)
  - GitHub issues: For confirmed bugs

- **Ansible community**:
  - Mailing list: ansible-project@googlegroups.com
  - IRC: #ansible on Libera.Chat
  - GitHub issues: ansible/ansible repository

- **Professional consultants** (if homelab becomes business-critical):
  - NixOS consultants: For complex Nix issues
  - DevOps consultants: For infrastructure architecture
  - Disaster recovery specialists: For business continuity planning

**When to seek community help**:
- ✅ Complex Nix build errors (flake issues, module conflicts)
- ✅ Terraform/Ansible best practices (architecture questions)
- ✅ Performance issues (resource optimization)
- ✅ Security review needed

---

### Escalation Decision Tree

```
Incident Cannot Be Resolved
│
├─ Is it a known failure scenario?
│  ├─ YES → Review appropriate runbook section again
│  │        Try alternative recovery method
│  │        If still failing, continue escalation ↓
│  └─ NO → Continue escalation ↓
│
├─ Is it a tool/platform issue?
│  ├─ Hetzner infrastructure → Contact Hetzner support (Level 3)
│  ├─ Nix build/deployment → Search NixOS docs, community (Level 2/4)
│  ├─ Terraform state issue → Search Terraform docs (Level 2)
│  ├─ Ansible playbook error → Search Ansible docs (Level 2)
│  └─ Restic backup issue → Search restic docs (Level 2)
│
├─ Is there suspected data corruption?
│  ├─ Backup corrupted → Try older snapshots (Section 7)
│  ├─ Filesystem corrupt → Hetzner support (Level 3)
│  └─ Database corrupt → Application-specific recovery
│
├─ Is there a time constraint?
│  ├─ Critical service down → Accept data loss, restore to last known good state
│  ├─ Approaching RTO limit → Communicate delay to stakeholders
│  └─ No urgency → Take time to investigate properly
│
└─ Is this a security incident?
   └─ YES → STOP disaster recovery, begin security incident response
              (Preserve evidence, isolate systems, assess compromise)
```

---

### Alternative Recovery Strategies

If documented procedures fail, consider these alternatives:

**Alternative 1: Accept Data Loss**

If data restore is failing but infrastructure can be rebuilt:

1. Accept RPO degradation (lose more data)
2. Rebuild infrastructure without data (Phases 1-2 only)
3. Restore application to empty state
4. Users manually restore what they can (email clients, local backups)

**When to use**: Data restore consistently failing, service availability more critical than data.

---

**Alternative 2: Restore to Different System**

If restoration to original system fails:

1. Provision new system (different datacenter, different OS)
2. Restore backup to new system
3. Migrate to new system
4. Decommission failed system

**When to use**: Original system has hardware issues, corruption, incompatibility.

---

**Alternative 3: Partial Restore**

If full restore is too slow or failing:

1. Identify critical data subset (recent emails, active users)
2. Restore only critical data
3. Bring service online with partial data
4. Restore remaining data in background

**When to use**: RTO deadline approaching, partial service better than no service.

---

**Alternative 4: Rebuild from Scratch**

If all recovery attempts fail:

1. Accept complete data loss
2. Provision fresh infrastructure
3. Deploy clean configuration
4. Reconfigure application from documentation
5. Users start fresh

**When to use**: Complete backup failure, data corruption beyond recovery.

**This is the worst-case scenario - avoid if any alternative exists.**

---

### Communication During Incidents

**For multi-hour incidents**, communicate status:

**Who to notify**:
- Users affected by service outage (email, status page)
- Stakeholders if business-critical (family, if personal email)

**What to communicate**:
- **Incident start time**: When did failure occur
- **Current status**: What's being done
- **Estimated resolution**: RTO estimate (be conservative)
- **Workarounds**: Alternative methods (use different email temporarily)
- **Updates**: Regular progress updates (every 1-2 hours for long incidents)

**Example status update**:

> **Incident Update: Mail Server Outage**
> **Time**: 2025-04-15 14:30 UTC
> **Status**: Recovery in progress
> **Cause**: Complete VPS loss (Hetzner datacenter incident)
> **Action**: Rebuilding server from backup (Phase 2 of 4 complete)
> **ETA**: Service restoration by 18:00 UTC (estimated)
> **Workaround**: Use alternative email provider temporarily
> **Next update**: 16:00 UTC or when service restored

---

### Post-Incident Review

**After every disaster recovery incident**, conduct a post-incident review:

1. **Timeline**: Document incident from detection to resolution
2. **Root cause**: What caused the failure? (configuration error, hardware failure, human error)
3. **Response**: What worked well? What could be improved?
4. **RTO/RPO**: Actual vs. target, explain deviations
5. **Lessons learned**: What did we learn from this incident?
6. **Action items**: Runbook updates, process improvements, automation opportunities

**Post-Incident Review Template**:

```markdown
## Disaster Recovery Post-Incident Review

**Incident ID**: DR-2025-001
**Date**: 2025-04-15
**Operator**: mi-skam
**Scenario**: Complete VPS Loss (Scenario 5)
**System**: mail-1.prod.nbg

### Timeline
- 10:15 UTC: Monitoring alert (service down)
- 10:20 UTC: Confirmed server deleted (Hetzner console)
- 10:25 UTC: Began recovery (Phase 1: Terraform)
- 10:45 UTC: Server provisioned, starting Phase 2
- 11:15 UTC: Ansible deployment complete, starting Phase 3
- 13:45 UTC: Data restore complete (2.5 hours)
- 14:00 UTC: Services verified operational
- **Total RTO**: 3 hours 45 minutes

### Root Cause
Accidental server deletion via Hetzner console (human error).

### Response Analysis

**What Worked Well**:
- ✅ Disaster recovery runbook was clear and accurate
- ✅ Terraform state allowed quick infrastructure recreation
- ✅ Restic backup was recent and valid (8 hours old)
- ✅ Ansible playbooks deployed configuration correctly

**What Could Be Improved**:
- ⚠️ No monitoring alert (detected by user report, not automated)
- ⚠️ Restic restore slower than expected (network bottleneck)
- ⚠️ DNS update not documented in runbook (had to figure out)

### RTO/RPO Analysis
- **RTO Target**: <8 hours
- **Actual RTO**: 3:45 (✅ within target)
- **RPO Target**: 1-24 hours
- **Actual RPO**: 8 hours (✅ within target)

### Lessons Learned
1. Hetzner console needs confirmation dialogs (prevent accidental deletion)
2. Monitoring (I7) would have detected failure immediately
3. DNS update procedure should be added to runbook Section 8
4. Consider faster backup method for large data (restic was network-bound)

### Action Items
- [ ] Add Hetzner API protection (prevent accidental server deletion)
- [ ] Update disaster recovery runbook Section 8 with DNS update procedure
- [ ] Prioritize Iteration 7 monitoring deployment
- [ ] Research faster backup options (Hetzner Storagebox snapshots?)
- [ ] Schedule quarterly DR drill for test-1.dev.nbg
```

---

### External Resources Quick Reference

| Resource | URL | Use Case |
|----------|-----|----------|
| **Hetzner Cloud Docs** | https://docs.hetzner.com/cloud/ | Server, network, API issues |
| **Hetzner Status** | https://status.hetzner.com/ | Datacenter incidents, outages |
| **Hetzner Support** | https://accounts.hetzner.com/support/tickets | Urgent infrastructure issues |
| **NixOS Manual** | https://nixos.org/manual/nixos/stable/ | Configuration, module options |
| **NixOS Discourse** | https://discourse.nixos.org/ | Community help, troubleshooting |
| **Ansible Docs** | https://docs.ansible.com/ | Playbook syntax, module usage |
| **Restic Docs** | https://restic.readthedocs.io/ | Backup/restore procedures |
| **OpenTofu Docs** | https://opentofu.org/docs/ | Terraform syntax, state management |
| **Project CLAUDE.md** | [CLAUDE.md](../../CLAUDE.md) | Infrastructure overview, commands |
| **Rollback Runbook** | [rollback_procedures.md](rollback_procedures.md) | Detailed rollback procedures |
| **Backup Runbook** | [backup_verification.md](backup_verification.md) | Backup verification, restore |

---

## 12. Document Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-30 | 1.0 | Initial disaster recovery runbook | Claude (I5.T2) |

---

**End of Disaster Recovery Runbook**

**Related Documentation**:
- **Detailed rollback procedures**: [rollback_procedures.md](rollback_procedures.md)
- **Backup verification and restore**: [backup_verification.md](backup_verification.md)
- **Normal deployment procedures**: [deployment_procedures.md](deployment_procedures.md)
- **Recovery testing plan**: [recovery_testing_plan.md](recovery_testing_plan.md) (I5.T4)
- **Project overview**: [CLAUDE.md](../../CLAUDE.md)

---

**Emergency Contact Information**:

- **Hetzner Support**: https://accounts.hetzner.com/support/tickets
- **Hetzner Status**: https://status.hetzner.com/

**For questions or runbook updates**: Submit issue to project repository
