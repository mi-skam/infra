# Recovery Testing Plan

**Purpose**: Procedures for systematically testing disaster recovery capabilities through regular scheduled drills
**Audience**: System operators performing quarterly disaster recovery testing
**Last Updated**: 2025-10-30

---

## Table of Contents

1. [Quick Reference](#1-quick-reference)
2. [Testing Principles](#2-testing-principles)
3. [Quarterly Testing Schedule](#3-quarterly-testing-schedule)
4. [Test Environment Setup](#4-test-environment-setup)
5. [Test Scenarios](#5-test-scenarios)
   - 5.1 [Test 1: Configuration Error Recovery](#51-test-1-configuration-error-recovery)
   - 5.2 [Test 2: Infrastructure Error Recovery](#52-test-2-infrastructure-error-recovery)
   - 5.3 [Test 3: Service Failure Recovery](#53-test-3-service-failure-recovery)
   - 5.4 [Test 4: Data Loss Recovery](#54-test-4-data-loss-recovery)
   - 5.5 [Test 5: Complete VPS Loss Recovery](#55-test-5-complete-vps-loss-recovery)
6. [Test Execution Workflow](#6-test-execution-workflow)
7. [Test Acceptance Criteria](#7-test-acceptance-criteria)
8. [Test Results Documentation](#8-test-results-documentation)
9. [Continuous Improvement Process](#9-continuous-improvement-process)
10. [Safety Guidelines](#10-safety-guidelines)
11. [References](#11-references)
12. [Document Revision History](#12-document-revision-history)

---

## 1. Quick Reference

| Test Scenario | Frequency | System | Duration | DR Runbook Reference | RTO Target | RPO Target |
|---------------|-----------|--------|----------|---------------------|------------|------------|
| **Configuration Error Recovery** | Quarterly (Q1, Q4) | test-1.dev.nbg or xmsi | 30 min | [DR: Scenario 1](disaster_recovery.md#4-scenario-1-configuration-error-bad-nix-build) | <5 min | 0 |
| **Infrastructure Error Recovery** | Quarterly (Q3) | test-1.dev.nbg | 45 min | [DR: Scenario 2](disaster_recovery.md#5-scenario-2-infrastructure-provisioning-error-terraform-failure) | <30 min | 0 |
| **Service Failure Recovery** | Quarterly (Q2) | test-1.dev.nbg | 20 min | [DR: Scenario 3](disaster_recovery.md#6-scenario-3-service-failure-vps-application-crash) | <5 min auto, <20 min manual | 0 |
| **Data Loss Recovery (Backup Restore)** | Quarterly (Q1, Q2) | mail-1.prod.nbg (temp restore) | 2 hours | [DR: Scenario 4](disaster_recovery.md#7-scenario-4-data-loss-accidental-deletion) | <4 hours | 1-24 hours |
| **Complete VPS Loss Recovery** | Annually (Q3) | test-1.dev.nbg | 4-6 hours | [DR: Scenario 5](disaster_recovery.md#8-scenario-5-complete-vps-loss-datacenter-failure) | <8 hours | 1-24 hours |

**Testing Calendar**:
- **Q1 (Jan-Mar)**: Configuration Error + Backup Restore
- **Q2 (Apr-Jun)**: Service Failure + Data Loss (quarterly full restore)
- **Q3 (Jul-Sep)**: Infrastructure Error + Complete VPS Rebuild
- **Q4 (Oct-Dec)**: Configuration Error (re-test) + All Scenarios Review

---

## 2. Testing Principles

### Why Test Disaster Recovery?

Regular disaster recovery testing validates that:

1. ✅ **Backups are restorable** - Not corrupted, contain expected data, can be decrypted
2. ✅ **Recovery procedures are accurate** - Runbooks are complete, commands work, steps are clear
3. ✅ **RTO/RPO targets are achievable** - Recovery completes within target time, data loss within tolerance
4. ✅ **Operator is familiar with procedures** - Regular practice builds muscle memory, reduces stress during real incidents
5. ✅ **Dependencies are documented** - Hidden assumptions and prerequisites are identified and documented

**Without testing, disaster recovery plans are theoretical and may fail when needed most.**

---

### Core Testing Principles

1. **Non-Disruptive**
   - Use test systems (test-1.dev.nbg) for destructive tests
   - Use non-production hours for production system tests (if needed)
   - Always have rollback plan before starting test
   - Confirm target system before executing breaking commands

2. **Documented**
   - Record all test executions using standardized template
   - Capture actual RTO/RPO achieved vs. targets
   - Document issues encountered, even minor ones
   - Note discrepancies between runbook and reality

3. **Comprehensive**
   - Test full recovery path, not just individual components
   - Include verification steps (don't just restore, verify it works)
   - Test with realistic data volumes when possible
   - Include edge cases and failure modes

4. **Realistic**
   - Simulate actual failure conditions accurately
   - Don't take shortcuts or skip steps
   - Use production-like data (anonymized if needed)
   - Test under realistic time pressure (set timer)

5. **Safe (Chaos Engineering)**
   - Deliberately break things to validate recovery works
   - Break things safely in controlled environment
   - Always backup current state before breaking
   - Have "abort test" procedure ready

---

## 3. Quarterly Testing Schedule

### Q1 (January - March): Foundation Testing

**Focus**: Configuration management and backup restore fundamentals

**Test Scenarios**:
1. **Configuration Error Recovery** (30 min)
   - System: test-1.dev.nbg or xmsi (non-production hours)
   - Validates: Ansible/NixOS rollback procedures work
   - Reference: [Test 1](#51-test-1-configuration-error-recovery)

2. **Backup Restore Test** (2 hours)
   - System: mail-1.prod.nbg (restore to temp location)
   - Validates: Restic backups are restorable, data integrity verified
   - Reference: [Test 4](#54-test-4-data-loss-recovery) (quarterly full restore variant)

**Schedule**: Execute both tests within Q1, on different days. Non-production hours recommended for backup restore test.

---

### Q2 (April - June): Service and Data Recovery

**Focus**: Application-level failures and data recovery

**Test Scenarios**:
1. **Service Failure Recovery** (20 min)
   - System: test-1.dev.nbg
   - Validates: Service restart procedures, systemd auto-restart
   - Reference: [Test 3](#53-test-3-service-failure-recovery)

2. **Data Loss Recovery** (2 hours)
   - System: mail-1.prod.nbg (quarterly full restore test)
   - Validates: Restore large data volumes, verify data integrity, measure restore time
   - Reference: [Test 4](#54-test-4-data-loss-recovery)

**Schedule**: Execute service failure test first (low risk). Schedule data loss recovery test during non-production hours (early morning or weekend).

---

### Q3 (July - September): Infrastructure Resilience

**Focus**: Infrastructure destruction and complete system rebuild

**Test Scenarios**:
1. **Infrastructure Error Recovery** (45 min)
   - System: test-1.dev.nbg
   - Validates: Terraform state recovery, resource recreation
   - Reference: [Test 2](#52-test-2-infrastructure-error-recovery)

2. **Complete VPS Loss Recovery** (4-6 hours, **annual test**)
   - System: test-1.dev.nbg (can be safely destroyed)
   - Validates: Full rebuild from scratch (Terraform + Ansible + data restore)
   - Reference: [Test 5](#55-test-5-complete-vps-loss-recovery)

**Schedule**: Block half-day for complete VPS rebuild test. This is the most comprehensive test, validating all phases of disaster recovery.

---

### Q4 (October - December): Review and Validation

**Focus**: Re-test problem areas, comprehensive review

**Test Scenarios**:
1. **Configuration Error Recovery** (30 min, re-test)
   - System: test-1.dev.nbg or xmsi
   - Validates: Any issues found in Q1 are resolved
   - Reference: [Test 1](#51-test-1-configuration-error-recovery)

2. **All Scenarios Review** (2-3 hours)
   - Review test results from Q1-Q3
   - Identify patterns and trends
   - Update runbooks based on year's findings
   - Plan improvements for next year

**Schedule**: Execute configuration re-test early in Q4. Reserve end of Q4 for comprehensive review and planning.

---

### Integration with Backup Verification Testing

This recovery testing plan integrates with the backup verification schedule from [backup_verification.md](backup_verification.md):

| Frequency | Backup Verification Task | Recovery Testing Task |
|-----------|------------------------|---------------------|
| **Weekly** | List snapshots, check timer, verify retention | N/A (backup-specific) |
| **Monthly** | Repository integrity check, restore test file | N/A (covered by weekly/monthly backup tasks) |
| **Quarterly** | Full restore to test-1.dev.nbg | **Data Loss Recovery test** (Q1, Q2 - uses quarterly full restore) |

**Note**: The quarterly full restore test from backup_verification.md becomes part of the Q1 and Q2 disaster recovery testing schedule.

---

## 4. Test Environment Setup

### Primary Test System: test-1.dev.nbg

**System Specifications**:
- **Hostname**: test-1.dev.nbg
- **OS**: Ubuntu 24.04 LTS
- **Hardware**: Hetzner CAX11 (ARM64, 2 vCPU, 4GB RAM, 40GB disk)
- **Network**: 10.0.0.20 (private), public IP (variable)
- **Criticality**: Low (ephemeral, no backup requirement, best-effort recovery)
- **Purpose**: Designated system for destructive disaster recovery testing

**Why Use test-1.dev.nbg?**
- ✅ Can be safely deleted and recreated without data loss
- ✅ Representative of production VPS architecture
- ✅ Lower resource tier allows testing resource constraints
- ✅ Separate from production systems (no risk of accidental production impact)

---

### Setting Up Test Data

Before executing tests, set up realistic test data on test-1.dev.nbg:

#### For Service Failure Tests
```bash
# Deploy a simple test service to test-1.dev.nbg
ssh root@test-1.dev.nbg

# Create test web service
cat > /tmp/test-service.py <<'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'Test service operational')
HTTPServer(('', 8080), Handler).serve_forever()
EOF

chmod +x /tmp/test-service.py

# Create systemd service
cat > /etc/systemd/system/test-recovery.service <<'EOF'
[Unit]
Description=Test Recovery Service
After=network.target

[Service]
Type=simple
ExecStart=/tmp/test-service.py
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable test-recovery.service
systemctl start test-recovery.service

# Verify service running
systemctl status test-recovery.service
curl http://localhost:8080
```

#### For Data Loss Tests
```bash
# Create test data directory with known files
ssh root@test-1.dev.nbg

mkdir -p /var/test-data
cd /var/test-data

# Create test files with checksums
for i in {1..100}; do
  echo "Test file $i - $(date)" > "testfile-$i.txt"
done

# Create checksum manifest
find /var/test-data -type f -exec sha256sum {} \; > /var/test-data-checksums.txt

# Document file count and size
echo "File count: $(find /var/test-data -type f | wc -l)" > /var/test-data-manifest.txt
echo "Total size: $(du -sh /var/test-data | cut -f1)" >> /var/test-data-manifest.txt
```

#### For Configuration Tests
```bash
# Ensure Ansible inventory includes test-1.dev.nbg
# Ensure git repository is clean
git status  # Should show clean working tree
```

---

### Safety Precautions

**Before Every Test**:

1. ✅ **Confirm target system**
   ```bash
   # CRITICAL: Verify you're on the correct system
   hostname
   # Should output: test-1.dev.nbg

   # Check system details
   hcloud server describe test-1.dev.nbg
   ```

2. ✅ **Backup current state** (if test-1 has any configuration to preserve)
   ```bash
   # Snapshot current configuration (if needed)
   rsync -av /etc/ /tmp/etc-backup-$(date +%Y%m%d-%H%M%S)/
   ```

3. ✅ **Set up rollback plan**
   - Know how to abort test if it goes wrong
   - Have disaster recovery runbook open and ready
   - Ensure production systems are not affected

4. ✅ **Communication**
   - Notify stakeholders if test might affect availability (even briefly)
   - Set "Do Not Disturb" if test requires focus
   - Have escalation contacts ready (Hetzner support, community forums)

5. ✅ **Time blocking**
   - Reserve sufficient time for test execution
   - Don't rush tests before meetings or deadlines
   - Allow buffer time for unexpected issues

---

### Test Environment Validation

Before starting any test, validate environment is ready:

```bash
# Checklist for test readiness
# [ ] SSH access to test system works
ssh root@test-1.dev.nbg 'echo "SSH OK"'

# [ ] Git repository is clean
git status  # Should be clean

# [ ] Terraform state is consistent
just tf-plan  # Should show no changes

# [ ] Ansible can connect to test system
just ansible-ping  # test-1.dev.nbg should respond SUCCESS

# [ ] Backup repository is accessible (for data restore tests)
ssh root@mail-1.prod.nbg 'mount | grep storagebox'

# [ ] Documentation is accessible (this runbook, DR runbook, rollback procedures)
ls -l docs/runbooks/disaster_recovery.md
ls -l docs/runbooks/rollback_procedures.md
ls -l docs/runbooks/backup_verification.md
```

---

## 5. Test Scenarios

### 5.1 Test 1: Configuration Error Recovery

**Objective**: Validate that configuration rollback procedures work correctly for Ansible and NixOS deployments.

**Validates**: [Disaster Recovery Scenario 1](disaster_recovery.md#4-scenario-1-configuration-error-bad-nix-build)

**Frequency**: Quarterly (Q1, Q4)

**System**: test-1.dev.nbg (preferred) or xmsi (non-production hours)

**Duration**: 30 minutes

**RTO Target**: <5 minutes

**RPO Target**: 0 (no data loss)

---

#### Prerequisites

- [ ] Test system operational and accessible via SSH
- [ ] Git repository has clean working directory (`git status` clean)
- [ ] Ansible inventory includes test system
- [ ] Test service deployed on test-1.dev.nbg (from Test Environment Setup)

---

#### Failure Simulation

**Introduce intentional Ansible syntax error**:

```bash
# Navigate to infra repository
cd /path/to/infra

# Create a branch for testing (safety measure)
git checkout -b test-config-error-$(date +%Y%m%d)

# Introduce syntax error in Ansible playbook
# Example: Remove closing quote in variable
cd ansible/playbooks
vim deploy.yaml

# Make change: Find a variable definition and break it
# Change:  some_var: "value"
# To:      some_var: "value  (missing closing quote)

# Stage changes (Nix flakes require staged files)
git add ansible/playbooks/deploy.yaml

# Attempt deployment to test system
just ansible-deploy --limit test-1.dev.nbg
# Or: cd ansible/ && ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg --check

# Expected result: Ansible syntax check should fail with error
# Example output: "ERROR! Syntax Error while loading YAML."
```

**Alternative: Introduce NixOS configuration error** (if testing on xmsi):

```bash
# Introduce syntax error in NixOS configuration
vim hosts/xmsi/configuration.nix

# Example: Remove semicolon, add typo, introduce undefined variable
# Change:  services.openssh.enable = true;
# To:      services.openssh.enable = tru  (typo)

# Stage changes
git add hosts/xmsi/configuration.nix

# Attempt build (pre-deployment detection preferred)
nix build .#nixosConfigurations.xmsi.config.system.build.toplevel

# Expected result: Build fails with error
# Example: "error: undefined variable 'tru'"
```

**Record Start Time**: [YYYY-MM-DD HH:MM:SS UTC] - Failure simulated

---

#### Recovery Execution

**Step 1: Detect failure**
- Verify error message is clear and actionable
- Note detection method (build failure, deployment failure)

**Step 2: Execute rollback**

For Ansible configuration error:
```bash
# Rollback using git
git checkout -- ansible/playbooks/deploy.yaml

# Verify clean state
git status  # Should show clean working directory

# Verify syntax is valid
cd ansible/
ansible-playbook playbooks/deploy.yaml --syntax-check

# Re-deploy to confirm rollback worked
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg --check
# Should show success (or "ok" for idempotent operations)
```

For NixOS configuration error:
```bash
# Rollback using git
git checkout -- hosts/xmsi/configuration.nix

# Verify clean state
git status

# Verify build succeeds
nix build .#nixosConfigurations.xmsi.config.system.build.toplevel

# Clean up test branch
git checkout main
git branch -D test-config-error-$(date +%Y%m%d)
```

**Record End Time**: [YYYY-MM-DD HH:MM:SS UTC] - Recovery completed

**Calculate Actual RTO**: [End Time - Start Time]

---

#### Verification Criteria

**After Recovery**:

1. **Verify configuration is valid**:
   ```bash
   # Ansible
   ansible-playbook playbooks/deploy.yaml --syntax-check
   # Output: "playbook: playbooks/deploy.yaml"

   # NixOS
   nix flake check
   # Output: No errors
   ```

2. **Verify system operational**:
   ```bash
   # Test system responds
   ssh root@test-1.dev.nbg 'systemctl --failed'
   # Output: 0 failed services

   # Test service still operational
   ssh root@test-1.dev.nbg 'systemctl status test-recovery.service'
   curl http://test-1.dev.nbg:8080
   # Output: "Test service operational"
   ```

3. **Verify no configuration drift**:
   ```bash
   # Re-run Ansible to confirm idempotent
   cd ansible/
   ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg
   # Output: changed=0 (all tasks should be "ok" or "skipped")
   ```

4. **Verify git repository clean**:
   ```bash
   git status
   # Output: "nothing to commit, working tree clean"
   ```

---

#### Success Criteria

- ✅ Configuration error detected during build/deployment (pre-production detection)
- ✅ Rollback procedure completed within RTO target (<5 minutes)
- ✅ System operational after rollback (no failed services)
- ✅ No configuration drift (idempotent re-run shows no changes)
- ✅ No data loss (RPO = 0)

**Result**: [PASS / FAIL / PARTIAL]

---

#### Failure Handling

**If rollback fails**:
1. Consult [rollback_procedures.md](rollback_procedures.md#scenario-1-nixos-configuration-bad-build)
2. Try alternative rollback method (e.g., git revert instead of checkout)
3. If NixOS: Try previous generation (`nixos-rebuild switch --rollback`)
4. Document failure reason in test results
5. Mark test as FAIL and schedule re-test after investigation

---

### 5.2 Test 2: Infrastructure Error Recovery

**Objective**: Validate that Terraform state can be recovered from backup and infrastructure can be recreated after provisioning failures.

**Validates**: [Disaster Recovery Scenario 2](disaster_recovery.md#5-scenario-2-infrastructure-provisioning-error-terraform-failure)

**Frequency**: Quarterly (Q3)

**System**: test-1.dev.nbg (infrastructure)

**Duration**: 45 minutes

**RTO Target**: <30 minutes

**RPO Target**: 0 (infrastructure is stateless)

---

#### Prerequisites

- [ ] Terraform state is consistent (`just tf-plan` shows no changes)
- [ ] Terraform state backup exists (`terraform/terraform.tfstate.backup`)
- [ ] test-1.dev.nbg is operational and can be safely deleted/recreated
- [ ] Hetzner API access confirmed (`hcloud server list` works)

---

#### Failure Simulation

**Simulate Terraform state corruption**:

```bash
cd terraform/

# Backup current state (safety measure)
cp terraform.tfstate terraform.tfstate.pre-test-$(date +%Y%m%d-%H%M%S)

# Option A: Simulate partial apply failure (state inconsistency)
# Manually remove test-1 from Terraform state
tofu state rm 'hcloud_server.test-1'

# Verify state inconsistency
just tf-plan
# Expected output: Shows test-1 needs to be created (even though it exists in Hetzner)

# Option B: Simulate accidental resource deletion
# Delete test-1.dev.nbg server via Hetzner console (safe, can be recreated)
hcloud server delete test-1.dev.nbg
# Confirm deletion

# Verify resource missing
hcloud server list | grep test-1
# Expected: No output (server deleted)
```

**Record Start Time**: [YYYY-MM-DD HH:MM:SS UTC] - Failure simulated

---

#### Recovery Execution

**Option A: Restore Terraform state from backup** (if state corrupted):

```bash
cd terraform/

# Backup corrupted state (for analysis)
cp terraform.tfstate terraform.tfstate.corrupted

# Restore from backup
cp terraform.tfstate.backup terraform.tfstate

# Verify state restored
tofu state list
# Should show all resources including test-1

# Verify plan is now consistent
just tf-plan
# Expected: "No changes" or only minor differences
```

**Option B: Recreate destroyed infrastructure** (if resource deleted):

```bash
cd terraform/

# Option 1: Resource already in state, just recreate
just tf-apply
# This will recreate test-1.dev.nbg

# Option 2: Resource removed from state, need to re-add
# (If you removed it from state in failure simulation)
# Ensure resource definition exists in servers.tf
cat servers.tf | grep -A 20 'resource "hcloud_server" "test-1"'

# Apply to create
just tf-apply
# Creates new server
```

**Record End Time**: [YYYY-MM-DD HH:MM:SS UTC] - Recovery completed

**Calculate Actual RTO**: [End Time - Start Time]

---

#### Verification Criteria

**After Recovery**:

1. **Verify Terraform state consistent**:
   ```bash
   just tf-plan
   # Output: "No changes. Your infrastructure matches the configuration."
   ```

2. **Verify server exists in Hetzner**:
   ```bash
   hcloud server list | grep test-1
   # Output: Shows test-1.dev.nbg with status "running"

   hcloud server describe test-1.dev.nbg
   # Output: Server details (ID, datacenter, IP, status)
   ```

3. **Verify server network connectivity**:
   ```bash
   # Test SSH access (may fail if not yet bootstrapped)
   ssh root@test-1.dev.nbg 'echo "SSH OK"'
   # If fails: Expected for newly provisioned server (need Ansible bootstrap)
   ```

4. **Verify Ansible can reach server** (after bootstrap):
   ```bash
   # Update Ansible inventory
   just ansible-inventory-update

   # Bootstrap if needed (new server)
   just ansible-bootstrap

   # Verify connectivity
   just ansible-ping
   # test-1.dev.nbg should respond SUCCESS
   ```

---

#### Success Criteria

- ✅ Terraform state restored or infrastructure recreated within RTO target (<30 minutes)
- ✅ Terraform plan shows no changes after recovery (state consistent)
- ✅ Server visible in Hetzner console and responding
- ✅ Network connectivity verified (SSH or Ansible ping)
- ✅ No data loss (RPO = 0, infrastructure is stateless)

**Result**: [PASS / FAIL / PARTIAL]

---

#### Failure Handling

**If state recovery fails**:
1. Consult [rollback_procedures.md](rollback_procedures.md#scenario-2-infrastructure-provisioning-error)
2. Try manual import: `tofu import hcloud_server.test-1 <server-id>`
3. Check Terraform state backup is not also corrupted
4. Consider rebuilding state from scratch (import all resources)

**If resource recreation fails**:
1. Check Hetzner API status: https://status.hetzner.com/
2. Verify API token is valid: `hcloud server list`
3. Check quota limits: `hcloud server list` (count servers)
4. Try different datacenter if provisioning fails

---

### 5.3 Test 3: Service Failure Recovery

**Objective**: Validate that service restart procedures work correctly, including systemd auto-restart and manual recovery.

**Validates**: [Disaster Recovery Scenario 3](disaster_recovery.md#6-scenario-3-service-failure-vps-application-crash)

**Frequency**: Quarterly (Q2)

**System**: test-1.dev.nbg

**Duration**: 20 minutes

**RTO Target**: <5 minutes (automatic), <20 minutes (manual)

**RPO Target**: 0 (no data loss)

---

#### Prerequisites

- [ ] Test service deployed on test-1.dev.nbg (test-recovery.service from Test Environment Setup)
- [ ] SSH access to test-1.dev.nbg confirmed
- [ ] Service currently running and responding

---

#### Failure Simulation

**Simulate service crash**:

```bash
# Connect to test system
ssh root@test-1.dev.nbg

# Verify service is running
systemctl status test-recovery.service
curl http://localhost:8080
# Expected: "Test service operational"

# Simulate crash by killing service
pkill -9 -f test-service.py
# Or: systemctl kill --signal=SIGKILL test-recovery.service

# Verify service crashed
systemctl status test-recovery.service
# Expected: "failed" or "activating (auto-restart)"

# Check if systemd auto-restart is configured
systemctl show test-recovery.service | grep Restart
# Expected: Restart=on-failure
```

**Record Start Time**: [YYYY-MM-DD HH:MM:SS UTC] - Service crashed

---

#### Recovery Execution

**Option A: Automatic restart (systemd)**:

```bash
# Wait for systemd auto-restart (RestartSec=10s)
sleep 15

# Check service status
systemctl status test-recovery.service
# Expected: "active (running)" if auto-restart succeeded

# Verify service responds
curl http://localhost:8080
# Expected: "Test service operational"
```

**Option B: Manual restart** (if auto-restart failed):

```bash
# Stop service (graceful)
systemctl stop test-recovery.service

# Verify stopped
systemctl status test-recovery.service
# Expected: "inactive (dead)"

# Check for lingering processes
ps aux | grep test-service
# If any, force kill: pkill -9 -f test-service.py

# Start service
systemctl start test-recovery.service

# Verify started
systemctl status test-recovery.service
# Expected: "active (running)"

# Verify responds
curl http://localhost:8080
# Expected: "Test service operational"
```

**Record End Time**: [YYYY-MM-DD HH:MM:SS UTC] - Service recovered

**Calculate Actual RTO**: [End Time - Start Time]

---

#### Verification Criteria

**After Recovery**:

1. **Verify service is running**:
   ```bash
   systemctl status test-recovery.service
   # Output: Active: active (running)
   #         Main PID: <pid> (running since ...)
   ```

2. **Verify service responds to requests**:
   ```bash
   curl http://localhost:8080
   # Output: "Test service operational"

   # Verify response time reasonable
   time curl http://localhost:8080
   # Should complete in <1 second
   ```

3. **Check for errors in logs**:
   ```bash
   journalctl -u test-recovery.service -n 50 --no-pager
   # Look for: Clean startup, no error/warning patterns
   ```

4. **Monitor for re-failure**:
   ```bash
   # Check again after 5 minutes
   sleep 300
   systemctl status test-recovery.service
   # Should still be "active (running)"
   curl http://localhost:8080
   # Should still respond
   ```

---

#### Success Criteria

- ✅ Service auto-restart succeeded (if configured) within 30 seconds
- ✅ Manual restart completed within RTO target (<5 min for auto, <20 min for manual)
- ✅ Service operational and responding after recovery
- ✅ No errors in service logs
- ✅ Service remains stable (no immediate re-crash)
- ✅ No data loss (RPO = 0, service state is ephemeral)

**Result**: [PASS / FAIL / PARTIAL]

---

#### Failure Handling

**If service won't restart**:
1. Check service logs for root cause: `journalctl -u test-recovery.service -n 100`
2. Verify service file is valid: `systemctl cat test-recovery.service`
3. Check for port conflicts: `netstat -tulpn | grep 8080`
4. Try running service manually: `/tmp/test-service.py` (check for errors)
5. Consult [disaster_recovery.md#scenario-3](disaster_recovery.md#6-scenario-3-service-failure-vps-application-crash)

---

### 5.4 Test 4: Data Loss Recovery

**Objective**: Validate that data can be restored from restic backups, including integrity verification and performance measurement.

**Validates**: [Disaster Recovery Scenario 4](disaster_recovery.md#7-scenario-4-data-loss-accidental-deletion)

**Frequency**: Quarterly (Q1, Q2 - full restore), Integrated with backup verification schedule

**System**: mail-1.prod.nbg (restore to temporary location, non-destructive)

**Duration**: 2 hours (depends on data volume)

**RTO Target**: <4 hours

**RPO Target**: 1-24 hours (depends on backup age)

---

#### Prerequisites

- [ ] SSH access to mail-1.prod.nbg
- [ ] Storage Box mounted at `/mnt/storagebox`
- [ ] Restic repository accessible and healthy (`restic check` passes)
- [ ] Restic password available (`/etc/restic/backup.env`)
- [ ] Recent backup snapshot exists (daily backup has run)

---

#### Pre-Flight Connectivity Validation

**Required before proceeding with test setup:**

Run 15-minute sustained connectivity test:
```bash
# Test SSH connectivity every 30 seconds for 15 minutes (30 attempts)
for i in {1..30}; do
  timestamp=$(date -u +"%H:%M:%S")
  echo "[$timestamp] Attempt $i/30:"
  if ssh -i ~/.ssh/homelab/hetzner -o ConnectTimeout=10 root@5.75.134.87 'date -u' >/dev/null 2>&1; then
    echo "  SUCCESS"
  else
    echo "  FAILED - SSH timeout"
    echo "BLOCKER: SSH connectivity is unstable. Do not proceed with test."
    exit 1
  fi
  sleep 30
done
echo "All 30 connectivity attempts succeeded. SSH is stable, proceed with test."
```

**If validation fails**: STOP and diagnose network issue before provisioning infrastructure. Previous tests (DRT-2025-10-30-002, DRT-2025-10-30-003) showed intermittent connectivity where initial SSH worked but timed out during test execution.

**Known Issue - test-1.dev.nbg Connectivity**: This system has exhibited intermittent SSH timeouts from certain network paths. Consider:
- Testing from alternative network (VPN, mobile hotspot)
- Using Hetzner Cloud Console (web terminal) for test execution
- Scheduling test from co-location with stable Hetzner connectivity
- **If SSH fails initially**: Wait 15-30 minutes for connectivity to stabilize before using alternative methods (test DRT-2025-10-30-003 showed connectivity self-stabilizes)

---

#### Failure Simulation

**Simulate data loss by selecting data to restore** (non-destructive test):

```bash
# Connect to mail server
ssh root@mail-1.prod.nbg

# Set up restic environment
export RESTIC_PASSWORD=$(grep RESTIC_PASSWORD /etc/restic/backup.env | cut -d= -f2)
export RESTIC_REPOSITORY="/mnt/storagebox/restic-mail-backups"

# List available snapshots
restic snapshots
# Note: Choose a recent snapshot for testing

# Identify test data to restore (non-critical for testing)
# For example: Restore a specific user's mailbox or a subdirectory

# Record what we expect to find
restic ls latest | grep "vmail-vol-1/_data" | head -20
# Note file count and structure
```

**Record Start Time**: [YYYY-MM-DD HH:MM:SS UTC] - Data restore started

---

#### Recovery Execution

**Step 1: Create restore target directory**:

```bash
# Create temporary restore location
mkdir -p /tmp/restore-test-$(date +%Y%m%d-%H%M%S)
RESTORE_DIR=$(ls -td /tmp/restore-test-* | head -1)

echo "Restoring to: $RESTORE_DIR"
```

**Step 2: Restore data from backup**:

```bash
# Restore specific path from latest snapshot
# Example: Restore mailcow mail data
restic restore latest \
  --target "$RESTORE_DIR" \
  --include /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data

# Monitor restore progress
# (restic shows progress bars by default)
```

**Step 3: Measure restore performance**:

```bash
# Record end time
echo "Restore completed at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

# Measure restored data volume
du -sh "$RESTORE_DIR"
echo "Restored data size: $(du -sh $RESTORE_DIR | cut -f1)"

# Count restored files
find "$RESTORE_DIR" -type f | wc -l
echo "Restored file count: $(find $RESTORE_DIR -type f | wc -l)"
```

**Record End Time**: [YYYY-MM-DD HH:MM:SS UTC] - Data restore completed

**Calculate Actual RTO**: [End Time - Start Time]

---

#### Verification Criteria

**After Restore**:

1. **Verify data restored completely**:
   ```bash
   # Check restored directory structure
   ls -lR "$RESTORE_DIR" | head -50

   # Compare file count with backup manifest
   restic ls latest | wc -l
   find "$RESTORE_DIR" -type f | wc -l
   # Counts should match (approximately)
   ```

2. **Verify data integrity**:
   ```bash
   # Check file types (should be mail messages, not corrupted)
   find "$RESTORE_DIR" -type f -name "*.eml" -exec file {} \; | head -20
   # Output should show "mail message" or "ASCII text"

   # Check for corruption indicators
   find "$RESTORE_DIR" -type f -size 0
   # Should be minimal (few or no zero-byte files)
   ```

3. **Verify file permissions and ownership**:
   ```bash
   # Check ownership (might differ from original, that's OK for test)
   ls -lh "$RESTORE_DIR/var/lib/docker/volumes" | head -20

   # Note: In production restore, would need to fix permissions:
   # chown -R 5000:5000 /path/to/restored/data
   ```

4. **Verify restoration performance**:
   ```bash
   # Calculate RTO achieved
   echo "Restore duration: [calculated from start/end times]"
   echo "RTO target: <4 hours"
   echo "RTO met: [YES/NO]"

   # Calculate restoration speed
   # [Data size] / [Duration] = [MB/s or GB/hour]
   ```

5. **Document RPO**:
   ```bash
   # Check snapshot timestamp
   restic snapshots --last 1
   # Note: Snapshot time shows when backup was taken

   # Calculate RPO (time between snapshot and "data loss")
   # For this test: RPO = time since last backup
   echo "Last backup: [timestamp from restic snapshots]"
   echo "Test time: $(date -u)"
   echo "RPO: [calculated difference]"
   ```

---

#### Cleanup

```bash
# After verification, clean up restored data
rm -rf "$RESTORE_DIR"

# Verify cleanup
df -h /tmp
```

---

#### Success Criteria

- ✅ Data restored successfully from restic backup
- ✅ Restore completed within RTO target (<4 hours)
- ✅ File count matches backup manifest (within reasonable margin)
- ✅ Data integrity verified (files are valid mail messages, not corrupted)
- ✅ RPO documented (time since last backup, should be <24 hours)
- ✅ Restoration performance measured and documented

**Result**: [PASS / FAIL / PARTIAL]

---

#### Failure Handling

**If restore fails**:
1. Check restic repository integrity: `restic check --read-data`
2. Try restoring from older snapshot: `restic snapshots` (choose different snapshot)
3. Verify Storage Box is mounted: `mount | grep storagebox`
4. Check disk space on restore target: `df -h /tmp`
5. Consult [backup_verification.md](backup_verification.md#troubleshooting)

**If data is corrupted**:
1. Try different snapshot (older backup)
2. Check backup logs for errors during backup creation
3. Run repository integrity check: `restic check --read-data`
4. Document corruption and escalate (may indicate backup system issue)

---

### 5.5 Test 5: Complete VPS Loss Recovery

**Objective**: Validate that a VPS can be completely rebuilt from scratch using Terraform provisioning, Ansible configuration, and restic data restore.

**Validates**: [Disaster Recovery Scenario 5](disaster_recovery.md#8-scenario-5-complete-vps-loss-datacenter-failure)

**Frequency**: Annually (Q3)

**System**: test-1.dev.nbg (will be deleted and recreated)

**Duration**: 4-6 hours

**RTO Target**: <8 hours

**RPO Target**: 1-24 hours (depends on backup age, if test data is backed up)

---

#### Prerequisites

- [ ] Terraform state is consistent (`just tf-plan` shows no changes)
- [ ] Ansible inventory includes test-1.dev.nbg
- [ ] test-1.dev.nbg is operational (baseline state)
- [ ] Hetzner API access confirmed
- [ ] **CRITICAL**: Block calendar for half-day (4-6 hours)
- [ ] test-1.dev.nbg has test data deployed (optional, for data restore testing)

---

#### Failure Simulation

**Delete test-1.dev.nbg server completely**:

```bash
# SAFETY CHECK: Confirm you're deleting the correct server
hcloud server describe test-1.dev.nbg
# Verify: Name is test-1.dev.nbg, not production server

# Delete server via Hetzner console or CLI
hcloud server delete test-1.dev.nbg
# Confirm deletion when prompted

# Verify server is gone
hcloud server list | grep test-1
# Expected: No output (server deleted)

# Verify SSH no longer works
ssh root@10.0.0.20
# Expected: Connection refused or timeout
```

**Record Start Time**: [YYYY-MM-DD HH:MM:SS UTC] - Complete VPS loss simulated

---

#### Recovery Execution

**Phase 1: Provision Infrastructure (Terraform)** - Estimated 10-15 minutes

```bash
cd /path/to/infra

# Step 1: Verify current Terraform state
just tf-plan
# Expected: Shows test-1 server missing (needs to be created)

# Step 2: Remove destroyed server from state (if still present)
cd terraform/
tofu state rm 'hcloud_server.test-1'

# Step 3: Verify resource definition exists in servers.tf
cat servers.tf | grep -A 20 'resource "hcloud_server" "test-1"'
# Expected: Resource block exists

# Step 4: Apply Terraform to provision new server
cd ..
just tf-apply
# Expected: Creates new test-1.dev.nbg server

# Step 5: Verify server created
hcloud server list | grep test-1
# Expected: Shows test-1.dev.nbg with status "running"

hcloud server describe test-1.dev.nbg
# Note new public IP address (may have changed)
```

**Record Phase 1 End Time**: [YYYY-MM-DD HH:MM:SS UTC]

**Phase 1 Duration**: [Calculated from start time]

---

**Phase 2: Deploy Configuration (Ansible)** - Estimated 20-30 minutes

```bash
# Step 1: Update Ansible inventory with new IP
just ansible-inventory-update

# Verify inventory updated
cat ansible/inventory/hosts.yaml | grep test-1.dev.nbg
# Expected: Shows new IP address

# Step 2: Test connectivity (will fail, SSH not configured yet)
just ansible-ping
# Expected: test-1.dev.nbg | UNREACHABLE (expected)

# Step 3: Bootstrap server (first-time setup)
just ansible-bootstrap
# This configures SSH keys, base packages, user accounts, firewall

# Step 4: Verify bootstrap succeeded
just ansible-ping
# Expected: test-1.dev.nbg | SUCCESS

# Step 5: Deploy application configuration
just ansible-deploy-env dev
# Or: just ansible-deploy --limit test-1.dev.nbg

# Step 6: Verify deployment succeeded
ssh root@test-1.dev.nbg 'systemctl --failed'
# Expected: 0 failed services (or minimal failures before data restore)
```

**Record Phase 2 End Time**: [YYYY-MM-DD HH:MM:SS UTC]

**Phase 2 Duration**: [Calculated from Phase 1 end time]

---

**Phase 3: Restore Application Data (Restic)** - Estimated 1-4 hours (optional for test-1)

**Note**: test-1.dev.nbg typically has no backed-up data (ephemeral system). This phase is **optional** for test-1 but should be **simulated** to validate the procedure.

**If test data was previously backed up**:

```bash
# Connect to test-1 (now rebuilt)
ssh root@test-1.dev.nbg

# Set up restic environment (if backup exists for test-1)
# Note: Typically test-1 is NOT backed up, but for testing purposes:
export RESTIC_PASSWORD="[test-backup-password]"
export RESTIC_REPOSITORY="/path/to/test-backup-repo"

# List available snapshots
restic snapshots
# Expected: Shows snapshots from before server deletion

# Stop services (prevent conflicts during restore)
systemctl stop test-recovery.service

# Restore test data
restic restore latest \
  --target / \
  --include /var/test-data

# Verify data restored
ls -lh /var/test-data
du -sh /var/test-data

# Restart services
systemctl start test-recovery.service

# Verify service operational
systemctl status test-recovery.service
curl http://localhost:8080
```

**Alternative: Simulate data restore** (if no backup exists for test-1):

```bash
# Deploy fresh test data (simulates restore)
# Follow "Test Environment Setup" to recreate test data
# This simulates what would happen with a real data restore
```

**Record Phase 3 End Time**: [YYYY-MM-DD HH:MM:SS UTC]

**Phase 3 Duration**: [Calculated from Phase 2 end time]

---

**Phase 4: Verify Full Recovery** - Estimated 10-20 minutes

```bash
# 1. Check all services running
ssh root@test-1.dev.nbg 'systemctl --failed'
# Expected: 0 failed services

# 2. Check service logs for errors
ssh root@test-1.dev.nbg 'journalctl -n 100 --no-pager'
# Expected: Normal startup messages, no critical errors

# 3. Test application functionality
curl http://test-1.dev.nbg:8080
# Expected: "Test service operational"

# 4. Verify network connectivity
ping test-1.dev.nbg
ssh root@test-1.dev.nbg 'ip a'
# Expected: Public and private IPs configured

# 5. Verify Terraform state consistent
just tf-plan
# Expected: "No changes" (state matches reality)

# 6. Verify Ansible connectivity
just ansible-ping
# Expected: test-1.dev.nbg | SUCCESS

# 7. Verify configuration matches expected state
ssh root@test-1.dev.nbg 'systemctl list-units --type=service --state=running | wc -l'
# Expected: Reasonable number of running services

# 8. Document recovery
# - Record total RTO
# - Record any issues encountered
# - Note any runbook deviations
```

**Record Phase 4 End Time**: [YYYY-MM-DD HH:MM:SS UTC]

**Total Recovery Time (RTO)**: [End Time - Start Time]

---

#### Verification Criteria

**After Complete Recovery**:

1. **Infrastructure recreated**:
   - ✅ Server exists in Hetzner console
   - ✅ Server has public and private IP addresses
   - ✅ Server attached to homelab network
   - ✅ Terraform state consistent (tf-plan shows no changes)

2. **Configuration deployed**:
   - ✅ SSH access works
   - ✅ Ansible can connect and manage server
   - ✅ Base packages installed
   - ✅ Firewall configured
   - ✅ Services running (no failed systemd units)

3. **Application operational**:
   - ✅ Test services respond to requests
   - ✅ No errors in service logs
   - ✅ Application functionality verified

4. **Data restored** (if applicable):
   - ✅ Test data present and accessible
   - ✅ File counts and sizes match expectations
   - ✅ Data integrity verified

5. **RTO/RPO met**:
   - ✅ Total recovery time within RTO target (<8 hours)
   - ✅ Data loss within RPO target (1-24 hours if backup-based)

---

#### Success Criteria

- ✅ **Phase 1** (Infrastructure): Server provisioned successfully, <15 minutes
- ✅ **Phase 2** (Configuration): Ansible deployment completed, <30 minutes
- ✅ **Phase 3** (Data): Data restored or redeployed, <4 hours (if applicable)
- ✅ **Phase 4** (Verification): System fully operational and verified, <20 minutes
- ✅ **Total RTO**: <8 hours
- ✅ **No manual intervention required** beyond following documented procedures
- ✅ **All verification checks passed**

**Result**: [PASS / FAIL / PARTIAL]

---

#### Lessons Learned Documentation

**After test completion, document**:

1. **What worked well**:
   - Which phases went smoothly?
   - Which runbook sections were clear and accurate?
   - Any pleasant surprises?

2. **What could be improved**:
   - Which phases took longer than expected?
   - Which runbook sections were unclear or outdated?
   - Any missing prerequisites or dependencies?

3. **Runbook updates needed**:
   - [ ] Update disaster_recovery.md Section 8 with [specific changes]
   - [ ] Update rollback_procedures.md with [specific changes]
   - [ ] Update ansible bootstrap procedures with [specific changes]

4. **Process improvements**:
   - What could be automated?
   - What could be parallelized to reduce RTO?
   - What documentation gaps were found?

---

#### Failure Handling

**If infrastructure provisioning fails** (Phase 1):
1. Check Hetzner status: https://status.hetzner.com/
2. Verify API token: `hcloud server list`
3. Check quota limits: May have hit resource limits
4. Try different datacenter if specific datacenter has issues
5. Consult [rollback_procedures.md#terraform](rollback_procedures.md#scenario-2-infrastructure-provisioning-error)

**If configuration deployment fails** (Phase 2):
1. Verify SSH access manually: `ssh root@<new-ip>`
2. Check Ansible logs: `journalctl -u ansible-bootstrap.service`
3. Try manual bootstrap steps one by one
4. Verify network connectivity (firewall rules, security groups)
5. Consult [rollback_procedures.md#ansible](rollback_procedures.md#scenario-3-ansible-playbook-applied-service-down)

**If data restore fails** (Phase 3):
1. Verify backup repository accessible
2. Try restoring to temporary location first
3. Check disk space on target system
4. Try older snapshot if latest is corrupted
5. Consult [backup_verification.md](backup_verification.md#troubleshooting)

**If RTO target exceeded**:
1. Document actual time for each phase
2. Identify bottlenecks (network speed, manual steps, waiting for services)
3. Plan improvements (automation, parallelization, faster restore methods)
4. Accept that first test may exceed RTO (practice improves performance)

---

## 6. Test Execution Workflow

### Generic Test Workflow

All disaster recovery tests follow this standard workflow:

```
┌─────────────────────────────────────────────────────────────────┐
│                     PREPARATION PHASE                           │
└─────────────────────────────────────────────────────────────────┘
1. Review test plan (this runbook, specific test section)
2. Verify prerequisites (system access, environment setup, time blocked)
3. Prepare test environment (deploy test data, verify baseline state)
4. Confirm safety (correct target system, no production impact)
5. Open DR runbook and rollback procedures (ready for reference)

┌─────────────────────────────────────────────────────────────────┐
│                   FAILURE SIMULATION PHASE                      │
└─────────────────────────────────────────────────────────────────┘
6. Record start time (baseline for RTO measurement)
7. Execute failure simulation (introduce error, delete resource, crash service)
8. Verify failure occurred (confirm system/service is actually broken)
9. Document failure state (error messages, symptoms, detection method)

┌─────────────────────────────────────────────────────────────────┐
│                   RECOVERY EXECUTION PHASE                      │
└─────────────────────────────────────────────────────────────────┘
10. Follow DR runbook recovery procedure (execute documented steps)
11. Measure recovery time (track time for each major step)
12. Document deviations (any steps that didn't work as documented)
13. Record end time (completion of recovery procedure)

┌─────────────────────────────────────────────────────────────────┐
│                    VERIFICATION PHASE                           │
└─────────────────────────────────────────────────────────────────┘
14. Execute verification checks (as defined in test scenario)
15. Confirm RTO/RPO targets met (compare actual vs. target)
16. Test application functionality (ensure services work, not just "up")
17. Monitor for re-failure (wait 5-10 minutes, verify stability)

┌─────────────────────────────────────────────────────────────────┐
│                    DOCUMENTATION PHASE                          │
└─────────────────────────────────────────────────────────────────┘
18. Fill out test results template (use standard template)
19. Document lessons learned (what worked, what didn't)
20. Identify runbook updates needed (inaccuracies, gaps, improvements)
21. Create action items (assign owner, due date, priority)

┌─────────────────────────────────────────────────────────────────┐
│                   CONTINUOUS IMPROVEMENT                        │
└─────────────────────────────────────────────────────────────────┘
22. Update disaster recovery runbook (fix inaccuracies found)
23. Update rollback procedures (add missing steps)
24. Schedule re-test (if test failed or found major issues)
25. Archive test results (save for trend analysis)
```

---

### Pre-Test Checklist

**Before starting ANY disaster recovery test**:

```markdown
## Pre-Test Checklist

**Test**: [Test name, e.g., "Q2-2025 Service Failure Recovery"]
**Date**: [YYYY-MM-DD]
**Operator**: [Name]

### Environment Preparation
- [ ] Calendar blocked (sufficient time allocated)
- [ ] Test plan reviewed (test scenario section read thoroughly)
- [ ] Prerequisites verified (system access, tools, credentials)
- [ ] Test environment prepared (test data deployed if needed)
- [ ] Target system confirmed (hostname verified, not production)
- [ ] Current state documented (baseline for comparison)

### Safety Checks
- [ ] Correct system targeted (triple-check hostname)
- [ ] Production systems protected (no risk of accidental impact)
- [ ] Backup of current state (if applicable)
- [ ] Rollback plan ready (know how to abort test)
- [ ] Communication sent (stakeholders notified if needed)

### Documentation Ready
- [ ] Test results template prepared (ready to fill out)
- [ ] DR runbook accessible (disaster_recovery.md open)
- [ ] Rollback procedures accessible (rollback_procedures.md open)
- [ ] Backup procedures accessible (backup_verification.md open if needed)
- [ ] Timer/stopwatch ready (for RTO measurement)

### Tools Verified
- [ ] SSH access works (can connect to test system)
- [ ] Git repository clean (no uncommitted changes)
- [ ] Terraform state consistent (tf-plan shows no changes)
- [ ] Ansible connectivity confirmed (ansible-ping succeeds)
- [ ] Monitoring accessible (can view system status)

**All checks passed**: [YES / NO - do not proceed if NO]
**Ready to start test**: [YYYY-MM-DD HH:MM UTC]
```

---

### Post-Test Checklist

**After completing ANY disaster recovery test**:

```markdown
## Post-Test Checklist

**Test**: [Test name]
**Date**: [YYYY-MM-DD]
**Result**: [PASS / FAIL / PARTIAL]

### Immediate Cleanup
- [ ] Test system restored to stable state
- [ ] Temporary test data removed (if applicable)
- [ ] Services verified operational
- [ ] No lingering issues (system is clean)

### Documentation
- [ ] Test results template filled out completely
- [ ] RTO/RPO measurements recorded
- [ ] Issues encountered documented
- [ ] Lessons learned captured
- [ ] Screenshots/logs saved (if relevant)

### Action Items
- [ ] Runbook updates identified (specific sections noted)
- [ ] Action items created (in tracking system)
- [ ] Owner assigned (person responsible for each action)
- [ ] Due dates set (realistic deadlines)
- [ ] Priority assigned (High/Med/Low)

### Continuous Improvement
- [ ] Test results archived (saved in docs/test-results/)
- [ ] Runbook updates scheduled (added to todo list)
- [ ] Re-test scheduled (if test failed or issues found)
- [ ] Next quarter's test planned (calendar blocked)

### Review
- [ ] Test reviewed (self-review or peer review)
- [ ] Findings shared (with stakeholders if applicable)
- [ ] Improvements prioritized (which to tackle first)

**Test complete**: [YYYY-MM-DD HH:MM UTC]
**Time to complete**: [Total duration including documentation]
```

---

## 7. Test Acceptance Criteria

### Overall Success Criteria

For a disaster recovery test to be considered **PASS**, all of the following criteria must be met:

1. ✅ **Recovery completed within RTO target**
   - Actual recovery time ≤ Target RTO for the scenario
   - Example: Configuration error recovery completed in 3 minutes (target <5 min) = PASS

2. ✅ **Data loss within RPO target** (if applicable)
   - Actual data loss ≤ Target RPO for the scenario
   - Example: Restored from backup 8 hours old (target <24 hours) = PASS

3. ✅ **All services operational after recovery**
   - No failed systemd services (`systemctl --failed` shows 0 services)
   - Services respond to requests (HTTP 200, service-specific checks pass)
   - Services remain stable (no crashes within 10 minutes of recovery)

4. ✅ **All verification steps passed**
   - System verification checks passed (as defined in test scenario)
   - Application functionality verified (not just "up", but actually works)
   - Data integrity verified (if data restore involved)

5. ✅ **Test documented using template**
   - Test results template filled out completely
   - Lessons learned captured
   - Action items created for any issues found

---

### Pass/Fail/Partial Definitions

**PASS**: All acceptance criteria met
- Recovery successful within RTO/RPO targets
- System fully operational
- All verification checks passed
- No blocking issues identified
- Test documented completely

**FAIL**: One or more critical criteria not met
- Recovery exceeded RTO target by >50%
- Data loss exceeded RPO target
- System not operational after recovery
- Critical verification checks failed
- Unable to complete recovery procedure

**PARTIAL**: Recovery succeeded but with issues
- Recovery completed but slightly exceeded RTO (<50% over target)
- System operational but with degraded performance
- Minor verification checks failed (non-critical)
- Recovery procedure had gaps but was completable
- Issues found that need addressing but didn't block recovery

---

### RTO/RPO Compliance Thresholds

| Scenario | RTO Target | RTO Pass Threshold | RTO Partial Threshold | RTO Fail Threshold |
|----------|------------|-------------------|---------------------|-------------------|
| **Config Error** | <5 min | ≤5 min | ≤7.5 min (+50%) | >7.5 min |
| **Infrastructure** | <30 min | ≤30 min | ≤45 min (+50%) | >45 min |
| **Service Failure (auto)** | <5 min | ≤5 min | ≤7.5 min (+50%) | >7.5 min |
| **Service Failure (manual)** | <20 min | ≤20 min | ≤30 min (+50%) | >30 min |
| **Data Loss** | <4 hours | ≤4 hours | ≤6 hours (+50%) | >6 hours |
| **Complete VPS Loss** | <8 hours | ≤8 hours | ≤12 hours (+50%) | >12 hours |

**RPO Compliance**:
- **PASS**: Actual RPO ≤ Target RPO
- **PARTIAL**: Actual RPO ≤ Target RPO × 1.5
- **FAIL**: Actual RPO > Target RPO × 1.5

**Examples**:
- Data loss recovery: Target RPO 24 hours, actual 8 hours → **PASS**
- Data loss recovery: Target RPO 24 hours, actual 30 hours → **PARTIAL** (within 1.5× target)
- Data loss recovery: Target RPO 24 hours, actual 48 hours → **FAIL** (exceeds 1.5× target)

---

### Verification Checklist by Test Type

**Configuration Error Recovery**:
- [ ] Build/deployment succeeds after rollback
- [ ] No syntax errors in configuration
- [ ] Git repository in clean state
- [ ] Services running (systemctl --failed = 0)
- [ ] No configuration drift (idempotent re-run = no changes)

**Infrastructure Error Recovery**:
- [ ] Terraform plan shows no changes (state consistent)
- [ ] Resources exist in Hetzner console
- [ ] Network connectivity verified (SSH or ping)
- [ ] Ansible can manage server (ansible-ping succeeds)

**Service Failure Recovery**:
- [ ] Service status = active (running)
- [ ] Service responds to requests (curl succeeds)
- [ ] No errors in service logs (journalctl shows clean startup)
- [ ] Service stable (no crashes after 10 minutes)

**Data Loss Recovery**:
- [ ] Data files present (ls shows expected files)
- [ ] File count matches backup manifest
- [ ] Data integrity verified (checksums match, files not corrupted)
- [ ] File permissions correct (chown/chmod if needed)
- [ ] Application can access restored data

**Complete VPS Loss Recovery**:
- [ ] All verification checks from above (infrastructure, services, data)
- [ ] Full system operational (no degraded functionality)
- [ ] RTO/RPO documented for each phase
- [ ] Lessons learned captured (for most complex test)

---

### Handling Test Failures

**If a test receives FAIL result**:

1. **Document failure thoroughly**
   - Exact point where recovery procedure failed
   - Error messages encountered
   - Attempts made to resolve (what was tried)
   - Root cause if identified

2. **Identify runbook gaps**
   - Was procedure inaccurate?
   - Were prerequisites unclear?
   - Were steps missing?
   - Were commands incorrect?

3. **Create immediate action items**
   - [ ] Fix runbook inaccuracies (high priority)
   - [ ] Re-test failed scenario (within 2 weeks)
   - [ ] Investigate root cause (if unclear)
   - [ ] Update prerequisites (if missing dependencies found)

4. **Schedule re-test**
   - Re-test within 2 weeks (if critical failure)
   - Re-test next quarter (if minor issue)
   - Re-test after runbook updates applied

5. **Escalate if needed**
   - If failure indicates systemic issue (backup corruption, infrastructure problem)
   - If failure would prevent real disaster recovery
   - If failure exceeds operator's ability to resolve

**Important**: Test failures are **learning opportunities**, not operator failures. The purpose of testing is to find gaps before real disasters occur.

---

## 8. Test Results Documentation

### Using the Test Results Template

**For every disaster recovery test executed**, fill out the standardized test results template:

**Template Location**: [docs/templates/recovery_test_results_template.md](../templates/recovery_test_results_template.md)

**Saved As**: `docs/test-results/YYYY-MM-DD-test-scenario-name.md`

**Example**: `docs/test-results/2025-04-15-data-loss-recovery-Q2.md`

---

### Required Information

The test results template captures:

1. **Test Metadata**
   - Test ID (e.g., DRT-2025-Q1-001)
   - Test date and time (UTC)
   - Operator name
   - Test scenario (which of the 5 DR scenarios)
   - System tested (test-1.dev.nbg, xmsi, mail-1.prod.nbg)
   - Duration (actual test execution time)
   - Overall result (PASS/FAIL/PARTIAL)

2. **Test Execution Details**
   - Preparation steps completed
   - Failure simulation commands executed
   - Recovery procedure followed (with link to runbook section)
   - Recovery commands executed
   - Verification checks performed

3. **RTO/RPO Assessment**
   - RTO target vs. actual (table format)
   - RPO target vs. actual (table format)
   - Met targets? (Yes/No with explanation)

4. **Pass/Fail by Criteria**
   - Each acceptance criterion (recovery within RTO, data loss within RPO, services operational, verification passed)
   - Status for each (✅ PASS / ❌ FAIL)
   - Notes explaining any failures

5. **Issues Encountered**
   - Description of each issue
   - Severity (High/Medium/Low)
   - Impact on test
   - Root cause (if identified)
   - Workaround used (if any)

6. **Lessons Learned**
   - What went well
   - What could be improved
   - Runbook updates needed (specific sections)

7. **Action Items**
   - Specific action descriptions
   - Owner assigned
   - Due date set
   - Priority (High/Med/Low)
   - Status (Open/In Progress/Done)

8. **Recommendations**
   - For next test (what to focus on)
   - For production readiness (improvements needed)

---

### Example Filled Template

See the template itself for detailed examples. Key points:

- **Be specific**: "Updated disaster_recovery.md Section 8 paragraph 3 to clarify SSH key location" not "Fixed docs"
- **Quantify**: "RTO: 3 min 42 sec (target <5 min)" not "RTO was good"
- **Be honest**: Document failures and issues clearly (that's the point of testing)
- **Action-oriented**: Every issue should have corresponding action item with owner and due date

---

### Archiving Test Results

**After completing test documentation**:

1. Save filled template to: `docs/test-results/YYYY-MM-DD-scenario-name.md`
2. Add to git: `git add docs/test-results/`
3. Commit: `git commit -m "test: Document Q2 2025 data loss recovery test results"`
4. Keep test results for trend analysis (track RTO/RPO over time)

---

### Reviewing Test Results

**Quarterly (end of each quarter)**:

Review all test results from the quarter:

```bash
# List all test results from Q2 2025
ls -l docs/test-results/2025-04-* docs/test-results/2025-05-* docs/test-results/2025-06-*

# Read each result file
cat docs/test-results/2025-04-15-service-failure-recovery.md
cat docs/test-results/2025-06-20-data-loss-recovery.md
```

**Look for**:
- Trends (is RTO improving or degrading over time?)
- Recurring issues (same problems in multiple tests?)
- Runbook accuracy (are updates actually being made after tests?)
- Test coverage (are all scenarios being tested as scheduled?)

---

## 9. Continuous Improvement Process

### Feedback Loop

Disaster recovery testing creates a continuous improvement feedback loop:

```
┌─────────────────────────────────────────────────────────────┐
│                      1. EXECUTE TEST                        │
│  Perform quarterly disaster recovery test following plan   │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   2. DOCUMENT RESULTS                       │
│  Fill out test results template, capture lessons learned   │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                3. IDENTIFY RUNBOOK GAPS                     │
│  Find inaccuracies, missing steps, outdated commands       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  4. UPDATE RUNBOOKS                         │
│  Fix disaster_recovery.md, rollback_procedures.md, etc.    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              5. TRACK ACTION ITEMS                          │
│  Assign owners, set due dates, track completion            │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            6. RE-TEST (Next Quarter)                        │
│  Validate that runbook updates resolved issues             │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           └──────────────┐
                                          │
                                          ▼
                              Next Quarter: Repeat Cycle
```

---

### After Each Test

**Within 3 days of completing a test**:

1. **Fill out test results template**
   - Complete all sections
   - Be thorough and specific
   - Don't skip "lessons learned"

2. **Identify runbook updates needed**
   - List specific sections that need changes
   - Be precise: "Update disaster_recovery.md Section 4 step 3 to add '--check' flag"
   - Note **why** update is needed (what was wrong)

3. **Create action items**
   - One action item per runbook update
   - Assign owner (yourself if single-operator)
   - Set realistic due date (within next quarter)
   - Assign priority:
     - **High**: Inaccuracies that would cause recovery to fail
     - **Medium**: Missing information or unclear instructions
     - **Low**: Improvements or optimizations

4. **Archive test results**
   - Save to `docs/test-results/`
   - Commit to git
   - Keep for historical reference

---

### Runbook Update Procedures

**Mapping issues to runbooks**:

| Issue Type | Runbook to Update | Example |
|------------|------------------|---------|
| Recovery procedure inaccurate | [disaster_recovery.md](disaster_recovery.md) | "Step 5 says run 'tofu apply' but should be 'just tf-apply'" |
| Rollback command incorrect | [rollback_procedures.md](rollback_procedures.md) | "Git rollback section missing '--' before filename" |
| Backup restore procedure outdated | [backup_verification.md](backup_verification.md) | "Restic restore command missing --target flag" |
| Test procedure unclear | [recovery_testing_plan.md](recovery_testing_plan.md) (this file) | "Failure simulation steps not specific enough" |
| Prerequisites missing | Any runbook | "Test requires storagebox mounted but prerequisite didn't mention it" |

**Updating runbooks**:

```bash
# Create branch for runbook updates
git checkout -b runbook-updates-2025-Q2

# Edit runbook files
vim docs/runbooks/disaster_recovery.md
vim docs/runbooks/rollback_procedures.md

# Test changes (if possible)
# Re-run test scenario to verify fix

# Commit with descriptive message
git add docs/runbooks/
git commit -m "docs(dr): Fix Terraform rollback procedure in Section 5

- Added 'just tf-apply' instead of 'tofu apply' for consistency
- Clarified state backup location
- Added verification step after state restore

Fixes issues found in DRT-2025-Q2-002 test"

# Merge back to main
git checkout main
git merge runbook-updates-2025-Q2
```

---

### Action Item Tracking

**Example action items table** (can be tracked in project management tool or markdown file):

| Action ID | Action | Runbook | Owner | Due Date | Priority | Status |
|-----------|--------|---------|-------|----------|----------|--------|
| Q2-001 | Update DR Section 5 Terraform rollback commands | disaster_recovery.md | Maxime | 2025-05-01 | High | ✅ Done |
| Q2-002 | Add restic restore verification steps | backup_verification.md | Maxime | 2025-05-15 | Medium | 🔄 In Progress |
| Q2-003 | Document ansible-bootstrap SSH key requirements | rollback_procedures.md | Maxime | 2025-06-01 | Low | ⏸️ Open |
| Q2-004 | Create faster rollback script for config-only changes | N/A (new script) | Maxime | 2025-06-30 | Medium | ⏸️ Open |

**Tracking in simple markdown file** (`docs/action-items.md`):

```markdown
# Disaster Recovery Action Items

## Q2 2025

### High Priority
- [x] Update DR Section 5 Terraform rollback commands (Maxime, 2025-05-01) - DONE 2025-04-28
- [ ] Fix backup restoration permission reset procedure (Maxime, 2025-05-15)

### Medium Priority
- [ ] Add systemd auto-restart validation to test procedures (Maxime, 2025-06-01)
- [ ] Document IP address change handling in complete VPS rebuild (Maxime, 2025-06-15)

### Low Priority
- [ ] Research faster backup restore methods (Maxime, 2025-06-30)
```

---

### Re-Testing Failed Scenarios

**If a test receives FAIL or PARTIAL result**:

1. **Fix identified issues** (update runbooks, improve procedures)
2. **Schedule re-test** within 2 weeks (high priority) or next quarter (medium priority)
3. **Execute re-test** following same test plan
4. **Compare results** (did fixes resolve issues?)
5. **Continue iterating** until test passes

**Re-test tracking**:

```markdown
## Test: Data Loss Recovery
**Initial Test**: 2025-04-15 - FAIL (RTO exceeded, restore took 6 hours)
**Issue**: Restic restore was slower than expected, bottlenecked on network
**Fix**: Researched restic performance tuning, updated backup verification runbook
**Re-test**: 2025-05-10 - PASS (RTO 3h 45m, within target)
```

---

### Quarterly Review Process

**At end of each quarter** (Q1: March, Q2: June, Q3: September, Q4: December):

**Q4 Review Meeting** (or self-review for single operator):

1. **Review all test results from the year**
   - List all tests executed
   - Note pass/fail/partial counts
   - Identify trends (improving or degrading?)

2. **Review action items completion**
   - How many action items created?
   - How many completed on time?
   - Any recurring issues not addressed?

3. **Measure RTO/RPO trends**
   - Is actual RTO improving over time? (getting faster with practice)
   - Are runbook updates reducing test failures?
   - Graph RTO over time (if multiple tests of same scenario)

4. **Identify systemic issues**
   - Are there patterns across multiple tests?
   - Do certain scenarios consistently have issues?
   - Are there tool/platform problems (Terraform bugs, Ansible inconsistencies)?

5. **Plan next year's improvements**
   - Which scenarios need more focus?
   - What automation could reduce RTO?
   - What monitoring would improve detection? (feed into Iteration 7 monitoring plans)
   - Should backup frequency increase? (improve RPO)

6. **Update testing plan if needed**
   - Adjust test frequency (if needed)
   - Add new test scenarios (if new failure modes identified)
   - Remove obsolete tests (if systems changed)

---

### Continuous Improvement Metrics

**Track over time**:

| Metric | Q1 | Q2 | Q3 | Q4 | Trend |
|--------|----|----|----|----|-------|
| **Tests Executed** | 2 | 2 | 3 | 2 | 📊 |
| **Tests Passed** | 1 | 2 | 2 | 2 | ✅ Improving |
| **Tests Failed** | 1 | 0 | 1 | 0 | ✅ Improving |
| **Avg Config Error RTO** | 4m | 3m | 3m | 2.5m | ✅ Improving |
| **Avg Data Loss RTO** | 6h | 4.5h | 3.5h | 3h | ✅ Improving |
| **Action Items Created** | 5 | 3 | 4 | 2 | ✅ Decreasing (fewer issues) |
| **Action Items Completed** | 4 | 3 | 4 | 2 | ✅ Good completion rate |
| **Runbook Updates** | 8 | 5 | 6 | 3 | ✅ Decreasing (runbooks stabilizing) |

**Good trends**:
- ✅ Pass rate increasing
- ✅ RTO decreasing (getting faster)
- ✅ Action items decreasing (fewer issues found)
- ✅ Runbook updates decreasing (documentation stabilizing)

**Bad trends**:
- ❌ Fail rate increasing
- ❌ RTO increasing (getting slower)
- ❌ Same issues recurring (not being fixed)
- ❌ Action items not completed

---

## 10. Safety Guidelines

### Core Safety Principles

**ALWAYS**:
- ✅ Triple-check target system before breaking things
- ✅ Use test-1.dev.nbg for destructive tests
- ✅ Have rollback plan before starting
- ✅ Block sufficient time (don't rush)
- ✅ Keep disaster recovery runbook open and ready

**NEVER**:
- ❌ Test on production systems without explicit planning
- ❌ Rush tests before meetings or deadlines
- ❌ Skip verification steps
- ❌ Ignore safety checks
- ❌ Test when fatigued or distracted

---

### System Safety Checklists

**Before ANY destructive command**:

```bash
# CRITICAL SAFETY CHECK
# Run these commands BEFORE executing any destructive test action

# 1. Confirm hostname
hostname
# VERIFY: Output is test-1.dev.nbg (or intended test system)

# 2. Confirm you're logged into correct system
whoami; pwd; hostname
# VERIFY: User, path, and hostname are all expected

# 3. Check system details
hcloud server describe $(hostname -s)
# VERIFY: Shows test-1.dev.nbg details, NOT production server

# 4. If deleting a server, confirm via Hetzner CLI
hcloud server describe test-1.dev.nbg
# VERIFY: Server ID, name, datacenter match expectations

# 5. Double-check no production data on system
df -h
mount
# VERIFY: No production volumes mounted, no critical data paths

# ONLY PROCEED IF ALL CHECKS PASS
```

---

### Production System Testing Safety

**If testing on production system** (e.g., mail-1.prod.nbg for data restore):

**Additional safety requirements**:

1. ✅ **Schedule non-production hours**
   - Early morning (02:00-06:00 UTC)
   - Weekend
   - Low-usage period

2. ✅ **Notify stakeholders**
   - Send notification 24 hours in advance
   - Explain what will be tested
   - Estimate duration and potential impact

3. ✅ **Use non-destructive methods**
   - Restore to temporary location (`/tmp/restore-test`)
   - Do NOT restore over production data
   - Do NOT stop production services unless absolutely necessary

4. ✅ **Have abort plan**
   - Know how to cancel test mid-execution
   - Have rollback procedure ready
   - Monitor for unexpected issues

5. ✅ **Verify production unaffected**
   - Check services remain running
   - Verify no performance degradation
   - Monitor for errors after test

**Example: Safe production data restore test**:

```bash
# SAFE: Restore to temporary location
ssh root@mail-1.prod.nbg
restic restore latest --target /tmp/restore-test-$(date +%Y%m%d)
# No impact on production services

# UNSAFE: Don't do this during testing
# restic restore latest --target /  # OVERWRITES PRODUCTION DATA
```

---

### Handling Test Emergencies

**If test goes wrong**:

**Emergency Abort Procedure**:

1. **STOP** immediately if:
   - Wrong system affected (production impacted)
   - Unexpected data loss
   - Services failing that shouldn't be
   - Unfamiliar error messages

2. **Assess damage**:
   - What broke?
   - Is production affected?
   - Can it be rolled back immediately?

3. **Execute emergency rollback**:
   ```bash
   # Configuration test gone wrong
   git reset --hard HEAD  # Discard all changes

   # Infrastructure test gone wrong
   cd terraform/
   cp terraform.tfstate.backup terraform.tfstate  # Restore state

   # Service test gone wrong
   systemctl restart <service>  # Restart failed service

   # Data test gone wrong
   rm -rf /tmp/restore-*  # Clean up test restore data
   ```

4. **Verify no lasting damage**:
   - Check production systems operational
   - Verify no data loss
   - Confirm no configuration changes persisted

5. **Document what happened**:
   - Fill out test results template (mark as FAIL)
   - Document emergency and response
   - Create high-priority action items to prevent recurrence

6. **Escalate if needed**:
   - If production is affected, follow incident response plan
   - If unsure how to recover, seek help immediately
   - Don't continue test until issue is understood

---

### Pre-Test Safety Briefing

**Before starting any test, verbally or mentally confirm**:

```
I am about to execute: [TEST NAME]
On system: [HOSTNAME]
This will: [BREAK/DELETE/STOP] [WHAT]
Expected impact: [DESCRIPTION]
Target system verified: [YES/NO]
Production protected: [YES/NO]
Rollback plan ready: [YES/NO]
Time allocated: [HOURS]
Ready to proceed: [YES/NO]

If any answer is NO: DO NOT PROCEED
```

---

### Safety Mindset

**Chaos engineering is about**:
- ✅ **Deliberate breaking** - Intentionally causing failures in controlled environment
- ✅ **Learning from failure** - Understanding what happens when things break
- ✅ **Safe experimentation** - Breaking things safely to build confidence

**Chaos engineering is NOT about**:
- ❌ **Reckless destruction** - Breaking things without planning or care
- ❌ **Production gambling** - "Let's see what happens if I delete this"
- ❌ **Shortcuts** - Skipping safety checks to save time

**Key principle**: "Break things on purpose in test, so they don't break by accident in production."

---

### 10.X Fallback Access: Hetzner Cloud Console

**When SSH is unavailable or unreliable**, use Hetzner Cloud Console (web-based terminal):

**Access Procedure**:
1. Open web browser, navigate to https://console.hetzner.cloud/
2. Select project "homelab" (or relevant project)
3. Click on server (e.g., test-1.dev.nbg)
4. Click "Console" button in top-right (opens web-based VNC terminal)
5. Log in as root (may require password reset if not set)

**CLI Access via hcloud**:
```bash
# Request console access via CLI (returns WebSocket URL)
hcloud server request-console test-1.dev.nbg

# Note: This returns a wss:// URL that must be opened in a web browser
# The CLI cannot directly connect to the console - it only generates the access URL
```

**When to Use Console**:
- SSH connection consistently times out
- Need to diagnose network/SSH issues (check `ip addr`, `systemctl status sshd`)
- Emergency access when normal access methods fail
- Executing critical restoration procedures when SSH is unreliable

**Console Limitations**:
- Copy-paste may be limited (varies by browser)
- No SSH key authentication (requires password)
- Slower than SSH (keyboard input latency)
- No persistent session (closes when browser closed)
- WebSocket URL expires after 1 hour (must request new URL)

**Best Practice**: For DR tests with known connectivity issues, execute test commands via Console session rather than SSH. However, note from test DRT-2025-10-30-003: SSH connectivity issues may self-resolve after 15-30 minutes - consider waiting before switching to Console.

---

## 11. References

### Related Runbooks

**Primary disaster recovery documentation**:
- **[Disaster Recovery Runbook](disaster_recovery.md)** - Strategic guidance for 5 failure scenarios, RTO/RPO targets, recovery decision trees
- **[Rollback Procedures Runbook](rollback_procedures.md)** - Tactical rollback commands for Nix, Terraform, and Ansible deployments
- **[Backup Verification Runbook](backup_verification.md)** - Detailed restic backup and restore procedures, testing schedule

**Related operational documentation**:
- **[Incident Response Plan](incident_response.md)** - Incident severity levels, response workflow, communication plan, postmortem process
- **[Test Results Template](../templates/recovery_test_results_template.md)** - Standardized template for documenting test results

**Project documentation**:
- **[CLAUDE.md](../../CLAUDE.md)** - Infrastructure overview, managed systems, essential commands

---

### External Resources

**Tool documentation**:
- **Restic**: https://restic.readthedocs.io/ - Backup and restore procedures
- **OpenTofu**: https://opentofu.org/docs/ - Terraform syntax and state management
- **Ansible**: https://docs.ansible.com/ - Playbook syntax and module usage
- **NixOS**: https://nixos.org/manual/nixos/stable/ - Configuration and module options

**Hetzner resources**:
- **Hetzner Cloud Docs**: https://docs.hetzner.com/cloud/ - Server, network, API documentation
- **Hetzner Status**: https://status.hetzner.com/ - Datacenter incidents and outages
- **Hetzner Support**: https://accounts.hetzner.com/support/tickets - Support ticket system

---

### Testing Best Practices Resources

**Chaos engineering**:
- **Principles of Chaos Engineering**: https://principlesofchaos.org/
- **Chaos Engineering Book**: "Chaos Engineering" by Casey Rosenthal and Nora Jones

**Disaster recovery testing**:
- **Google SRE Book - Chapter 27**: Testing for Reliability
- **AWS Disaster Recovery**: https://aws.amazon.com/disaster-recovery/

---

## 12. Document Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-30 | 1.0 | Initial recovery testing plan created for I5.T4 | Claude |

---

**Document Status**: Active
**Next Review**: End of Q1 2026 (after first year of testing)
**Owner**: Maxime (plumps)

---

**End of Recovery Testing Plan**

**Related Documentation**:
- **Test Results Template**: [../templates/recovery_test_results_template.md](../templates/recovery_test_results_template.md)
- **Disaster Recovery Runbook**: [disaster_recovery.md](disaster_recovery.md)
- **Backup Verification Runbook**: [backup_verification.md](backup_verification.md)
- **Rollback Procedures Runbook**: [rollback_procedures.md](rollback_procedures.md)
- **Incident Response Plan**: [incident_response.md](incident_response.md)

---

**For questions or runbook updates**: Submit issue to project repository or update directly via pull request.
