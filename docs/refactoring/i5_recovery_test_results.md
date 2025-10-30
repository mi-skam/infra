# Disaster Recovery Test Report

**Test ID**: DRT-2025-10-30-001
**Test Date**: 2025-10-30
**Test Time**: 11:45 - 12:05 UTC
**Operator**: Claude Code
**Test Scenario**: Data Loss Recovery (Backup Restoration Test)
**Scenario Reference**: [recovery_testing_plan.md#54-test-4-data-loss-recovery](../runbooks/recovery_testing_plan.md#54-test-4-data-loss-recovery)

---

## Test Summary

**Objective**: Validate that data can be restored from restic backups, including integrity verification and performance measurement on test-1.dev.nbg

**System**: test-1.dev.nbg (5.75.134.87)

**Duration**: 20 minutes (test preparation only, restoration not executed)

**Result**: FAIL (unable to execute due to connectivity blocker)

**One-sentence summary**: Test could not be executed due to SSH connectivity timeout to test-1.dev.nbg (5.75.134.87), preventing restoration test execution and verification despite server showing as "running" in Hetzner Cloud.

---

## Test Execution

### Preparation

**Prerequisites Completed**:
- [x] Test plan reviewed (recovery_testing_plan.md Section 5.4 read)
- [x] Target system confirmed via Hetzner Cloud CLI
- [ ] Environment validated (SSH access blocked)
- [ ] Safety checks performed (unable to connect)
- [x] Documentation ready (DR runbook, backup_verification.md accessible)
- [x] Timer/stopwatch ready for RTO measurement

**Test Environment Setup**:
- **System hostname**: test-1.dev.nbg (confirmed via `hcloud server list`)
- **System IP**: 5.75.134.87 (public), 10.0.0.4 (private)
- **Server status**: running (8 days uptime reported by Hetzner)
- **Git status**: N/A (unable to connect)
- **Services baseline**: N/A (unable to connect)
- **Test data prepared**: Yes (from I5.T1: 2 snapshots exist: 256d5ca2, 1f3bd427)

**Baseline State Documented**: No (connectivity blocker)

---

### Connectivity Issue (Blocker)

**Start Time**: 2025-10-30 11:45:00 UTC

**Issue Encountered**: SSH connection to test-1.dev.nbg times out

**Troubleshooting Performed**:

1. **Direct SSH attempt**:
   ```bash
   ssh -i ~/.ssh/homelab/hetzner -o StrictHostKeyChecking=no root@5.75.134.87
   ```
   **Result**: `ssh: connect to host 5.75.134.87 port 22: Operation timed out`

2. **Ansible connectivity test**:
   ```bash
   cd ansible && ansible test-1.dev.nbg -m ping
   ```
   **Result**: `UNREACHABLE! => "msg": "mux_client_request_session: read from master failed: Broken pipe"`

3. **Server status check**:
   ```bash
   hcloud server list | grep test-1
   ```
   **Result**:
   ```
   111301341   test-1.dev.nbg         running   5.75.134.87      2a01:4f8:1c1c:a339::/64   10.0.0.4 (homelab)   nbg1-dc3     8d
   ```
   - Server shows as **running** in Hetzner Cloud
   - Public IP: 5.75.134.87
   - Private IP: 10.0.0.4
   - Uptime: 8 days

4. **Firewall check**:
   ```bash
   hcloud firewall list
   ```
   **Result**: No firewalls configured (output empty)

5. **SSH key verification**:
   ```bash
   ls -la ~/.ssh/homelab/hetzner
   ```
   **Result**: Key exists (`-rw------- 1 plumps staff 399 Oct 20 2024`)

**Root Cause Analysis**:
- Server is running according to Hetzner Cloud API
- No Hetzner Cloud firewall is blocking traffic
- SSH key exists and has correct permissions
- Connection times out (not refused), suggesting:
  - Network routing issue between local machine and Hetzner
  - Server's internal firewall (iptables/ufw) may be blocking SSH
  - SSH daemon may have crashed/stopped on the server
  - VPS may be experiencing kernel panic or boot issue despite "running" status

**Blocker Impact**: Cannot proceed with any test steps. Restoration test requires SSH access to:
- List restic snapshots
- Execute restic restore command
- Verify data integrity
- Measure restoration time

---

### Failure Simulation

**Status**: NOT EXECUTED (blocked by connectivity issue)

**Planned Approach** (from recovery_testing_plan.md Section 5.4):
1. SSH to test-1.dev.nbg
2. Set restic environment variables
3. List available snapshots
4. Select snapshot for restoration
5. Record start time
6. Create restore directory
7. Execute `restic restore <snapshot-id> --target <dir>`

**Cannot Proceed**: SSH connectivity required for all steps

---

### Recovery Execution

**Status**: NOT EXECUTED (blocked by connectivity issue)

**Planned Recovery Steps**:
- Set up restic environment (`RESTIC_REPOSITORY`, `RESTIC_PASSWORD`)
- List snapshots: `restic snapshots`
- Select snapshot: 256d5ca2 or 1f3bd427 (from I5.T1 test results)
- Create restore directory: `/tmp/restore-test-$(date +%Y%m%d-%H%M%S)`
- Execute restoration: `restic restore <snapshot-id> --target "$RESTORE_DIR"`
- Measure time and verify integrity

**Cannot Proceed**: SSH connectivity required

---

### Verification

**Status**: NOT EXECUTED (blocked by connectivity issue)

**Planned Verification Checks**:

1. **File Count Verification**: Compare restored files to backup manifest
   - Expected: 3 files (/etc/hostname, /etc/hosts, /var/log/syslog)
   - Command: `find "$RESTORE_DIR" -type f | wc -l`

2. **Data Integrity Check**: Verify files are readable and not corrupted
   - Command: `cat "$RESTORE_DIR/etc/hostname" "$RESTORE_DIR/etc/hosts"`
   - Command: `find "$RESTORE_DIR" -type f -size 0` (check for zero-byte files)

3. **Checksum Verification**: Compare checksums of restored data
   - Command: `sha256sum "$RESTORE_DIR/etc/hostname"` (compare to original)

4. **Directory Structure Check**: Verify paths match expected structure
   - Command: `ls -lR "$RESTORE_DIR"`

5. **Restoration Time Measurement**: Calculate RTO
   - Target: <30 minutes (expected: <1 minute for ~21 MB test data)

**Cannot Proceed**: SSH connectivity required for all verification steps

---

## Test Results

### RTO/RPO Assessment

| Metric | Target | Actual | Met Target? | Notes |
|--------|--------|--------|-------------|-------|
| **RTO** (Recovery Time Objective) | <30 min | N/A | ❌ No | Test not executed due to connectivity blocker |
| **RPO** (Recovery Point Objective) | 1-24 hours | N/A | ❌ No | Unable to measure (test not executed) |

**RTO Breakdown**:
- **Detection**: 0 min - N/A (no failure simulated)
- **Decision**: 0 min - N/A (no failure simulated)
- **Execution**: N/A - Test blocked before execution
- **Verification**: N/A - Test blocked before execution
- **Total**: N/A

**RTO Analysis**: Cannot assess RTO achievement due to connectivity blocker. Test environment is not accessible.

**RPO Analysis**: Cannot assess RPO. Based on I5.T1 test results, two backup snapshots exist (256d5ca2 from 2025-10-30 10:07:56, 1f3bd427 from 2025-10-30 10:33:56). RPO would be time since last backup, but cannot verify current state.

---

### Pass/Fail by Acceptance Criteria

| Acceptance Criterion | Status | Notes |
|---------------------|--------|-------|
| Backup snapshot selected from test-1.dev.nbg restic repository | ❌ FAIL | Unable to access server to list snapshots |
| Restoration executed using restic restore command to separate directory | ❌ FAIL | Unable to access server to execute restoration |
| Data integrity verified: file count matches backup, checksums match | ❌ FAIL | Unable to access server to verify integrity |
| Restoration time measured and documented | ❌ FAIL | Unable to measure (test not executed) |
| RTO/RPO assessment: restoration time within target, data age acceptable | ❌ FAIL | Unable to assess (test not executed) |
| Any issues found documented with root cause | ✅ PASS | Connectivity issue documented below with root cause analysis |
| If issues found, backup verification runbook updated | 🔶 PARTIAL | Issue documented, runbook update assessment in action items |
| Test results document follows template format | ✅ PASS | This document follows template from I5.T4 |
| Test marked PASS if restoration successful | ❌ FAIL | Test marked FAIL due to execution blocker |

**Overall Test Result**: FAIL

**Result Justification**: Test marked as FAIL because the primary objective (validate backup restoration) could not be completed due to SSH connectivity issue to test-1.dev.nbg. While the blocker is documented and root cause analysis performed, the test acceptance criteria explicitly require restoration to be executed and verified, which was impossible without server access.

---

## Issues Encountered

### Issue 1: SSH Connection Timeout to test-1.dev.nbg

**Severity**: High (test blocker)

**Impact**: Complete inability to execute recovery test. All test steps require SSH access to test-1.dev.nbg to list snapshots, execute restoration, verify data integrity, and measure performance. Without connectivity, RTO/RPO cannot be measured, and backup restoration capability cannot be validated.

**Root Cause**: SSH connection to test-1.dev.nbg (5.75.134.87) times out after several minutes. Server shows as "running" in Hetzner Cloud API with 8 days uptime, but SSH port 22 is unreachable. Possible causes:
1. **Internal firewall misconfiguration**: Server's iptables/ufw may have been modified to block SSH after deployment
2. **SSH daemon failure**: sshd may have crashed or been stopped, despite server continuing to run
3. **Network routing issue**: VPS may have lost default gateway or network configuration
4. **Kernel panic/boot issue**: Server may be in degraded state despite "running" status in API
5. **Resource exhaustion**: Server may be out of memory/CPU, preventing new SSH connections

**Workaround Used**: None available. SSH access is fundamental requirement for restic restoration test. Cannot use Hetzner Cloud Console (no VNC/serial console access for cloud servers), cannot use Ansible (requires SSH), cannot use alternative access methods.

**Recommendation**:
1. **Immediate**: Reboot test-1.dev.nbg via Hetzner Cloud to restore connectivity: `hcloud server reboot test-1.dev.nbg`
2. **Immediate**: After reboot, verify SSH access and re-run this test (I5.T5)
3. **Short-term**: Add monitoring for SSH accessibility (e.g., external health check pinging port 22)
4. **Short-term**: Configure serial console access or Hetzner Rescue system for future recovery
5. **Medium-term**: Implement automated SSH connectivity checks in CI/CD to detect such issues early
6. **Medium-term**: Document SSH troubleshooting procedures in disaster_recovery.md for future reference

---

### Issue 2: No Pre-Test Connectivity Validation

**Severity**: Medium (process gap)

**Impact**: Test execution attempted without validating prerequisites (SSH access), resulting in wasted time and incomplete test. Recovery testing plan (Section 5.4) lists "SSH access to mail-1.prod.nbg" as prerequisite but does not emphasize validating this BEFORE starting test timer. Test should have failed faster during pre-flight checks.

**Root Cause**: Recovery testing plan prerequisites section (Section 5.4) includes "SSH access" as a checkbox item, but does not specify that this should be validated with an actual connection test before proceeding. Test operator (Claude Code) reviewed documentation but did not verify connectivity before starting test execution timeline.

**Workaround Used**: None. Issue discovered during test execution when attempting first SSH command.

**Recommendation**:
1. Update recovery_testing_plan.md Section 5.4 to add explicit pre-flight validation step:
   ```markdown
   #### Pre-Flight Validation (DO THIS FIRST)

   Before starting test timer, validate all prerequisites:

   - [ ] **Test SSH connectivity**: `ssh root@test-1.dev.nbg 'date -u'` (should succeed)
   - [ ] **Verify Storage Box mounted**: `ssh root@test-1.dev.nbg 'mount | grep storagebox'`
   - [ ] **Verify restic accessible**: `ssh root@test-1.dev.nbg 'restic --version'`

   **If any validation fails, STOP and resolve blocker before proceeding with test.**
   ```
2. Add similar pre-flight validation to all test scenarios in recovery_testing_plan.md
3. Consider creating a pre-flight validation script/playbook that can be run before quarterly tests

---

## Lessons Learned

### What Went Well

**Positive aspects of test execution and recovery**:

- Documentation was comprehensive and clear (recovery_testing_plan.md Section 5.4 had detailed procedure)
- Test template (recovery_test_results_template.md) provided excellent structure for documenting results
- Hetzner Cloud CLI provided quick visibility into server status
- Previous test results (I5.T1) clearly documented expected state (2 snapshots, 3 files, ~21 MB data)
- Systematic troubleshooting approach identified blocker quickly (SSH timeout, server status check, firewall check, key verification)
- Test failure was caught before any destructive actions were attempted (no data at risk)

---

### What Could Be Improved

**Areas for improvement in processes, tools, or practices**:

- **Pre-flight validation missing**: Test procedure should enforce connectivity checks before starting test timer
- **No fallback access method**: Test environment should have alternative access method (Hetzner Rescue, serial console, or VNC) for when SSH fails
- **No monitoring alerts**: SSH daemon failure did not trigger any alerts (no monitoring configured on test-1.dev.nbg)
- **Unclear "running" status**: Hetzner Cloud API reports server as "running" even when SSH is inaccessible, giving false confidence
- **No test environment health checks**: Should have automated daily/weekly health checks for test systems to catch issues before quarterly DR tests
- **Documentation assumes connectivity**: Recovery testing plan assumes SSH access will work, does not document what to do if connectivity fails during test

---

### Runbook Updates Needed

**Specific sections of runbooks that need updates**:

- [ ] **[recovery_testing_plan.md](../runbooks/recovery_testing_plan.md)**: Section 5.4 "Data Loss Recovery" - Add pre-flight validation checklist before test execution (validate SSH, Storage Box mount, restic access)

- [ ] **[recovery_testing_plan.md](../runbooks/recovery_testing_plan.md)**: All test scenarios (5.1-5.5) - Add pre-flight validation section at beginning of each scenario

- [ ] **[recovery_testing_plan.md](../runbooks/recovery_testing_plan.md)**: Section 10 "Safety Guidelines" - Add guidance for "What to do if test environment is unreachable" (use Hetzner reboot, Rescue system, etc.)

- [ ] **[disaster_recovery.md](../runbooks/disaster_recovery.md)**: Add new section "Troubleshooting SSH Access Issues" - Document steps for recovering access when SSH is unreachable (Hetzner reboot, Rescue mode, serial console)

- [ ] **[backup_verification.md](../runbooks/backup_verification.md)**: Section "Prerequisites" - Emphasize testing SSH connectivity before attempting backup verification procedures

**Rationale for each update**:
- Pre-flight validation prevents wasted time on tests that cannot succeed
- SSH troubleshooting procedures help operators recover from common access issues
- Adding "what to do when prerequisites fail" guidance makes runbooks more robust

---

### Process Changes

**Changes to procedures, workflows, or testing approach**:

- **Mandatory pre-flight checks**: All DR tests must validate prerequisites (especially SSH) before starting test execution timer
- **Test environment health monitoring**: Implement weekly automated health checks for test-1.dev.nbg (SSH access, Storage Box mount, restic repository accessibility)
- **Alternative access documentation**: Document how to use Hetzner Rescue system or server reboot for recovery when SSH fails
- **Quarterly test scheduling**: Schedule DR tests with advance notice to allow time for pre-test validation and issue resolution

---

### Knowledge Gaps Identified

**Information or skills that would have helped prevent issues or respond faster**:

- **Hetzner Rescue System**: Need to document how to boot test-1.dev.nbg into Rescue mode for troubleshooting when SSH fails
- **Serial console access**: Need to understand if Hetzner Cloud provides serial console access (or if only available via dedicated servers)
- **Server reboot impact**: Need to document whether rebooting test-1.dev.nbg will lose any data (ephemeral system, but Storage Box mount persistence unclear)
- **Network troubleshooting**: Need documented procedures for diagnosing network connectivity issues (traceroute, mtr, Hetzner network status)
- **SSH daemon recovery**: Need documented procedures for recovering SSH when it fails (Rescue mode, serial console, etc.)

---

## Action Items

| Action | Owner | Due Date | Priority | Status | Notes |
|--------|-------|----------|----------|--------|-------|
| Reboot test-1.dev.nbg via Hetzner Cloud to restore SSH connectivity | Maxime | 2025-10-31 | High | Open | Required before re-running I5.T5 |
| Re-execute I5.T5 recovery test after connectivity restored | Maxime | 2025-11-01 | High | Open | Complete I5.T5 task requirements |
| Update recovery_testing_plan.md Section 5.4 to add pre-flight validation checklist | Maxime | 2025-11-07 | High | Open | Prevent future test failures due to invalid prerequisites |
| Add pre-flight validation to all test scenarios (5.1-5.5) in recovery_testing_plan.md | Maxime | 2025-11-07 | High | Open | Ensure all tests validate prerequisites before execution |
| Document Hetzner Rescue System procedures in disaster_recovery.md | Maxime | 2025-11-14 | Medium | Open | Provide recovery path when SSH fails |
| Add SSH troubleshooting section to disaster_recovery.md | Maxime | 2025-11-14 | Medium | Open | Help operators recover from connectivity issues |
| Implement weekly automated health checks for test-1.dev.nbg | Maxime | 2025-11-21 | Medium | Open | Detect SSH/mount/restic issues before quarterly DR tests |
| Research Hetzner Cloud serial console availability | Maxime | 2025-11-30 | Low | Open | Determine alternative access methods for future incidents |
| Add monitoring for SSH daemon status on all systems | Maxime | 2025-12-15 | Low | Open | Alert when SSH becomes unavailable |

---

## Recommendations

### For Next Test

**What to focus on or change in the next disaster recovery test**:

- **Pre-test validation**: Run pre-flight validation checklist 24 hours before scheduled DR test to allow time for issue resolution
- **Reboot test-1.dev.nbg**: Execute reboot via `hcloud server reboot test-1.dev.nbg` to restore connectivity
- **Verify connectivity**: Test SSH access manually before re-running I5.T5: `ssh root@5.75.134.87 'date -u'`
- **Document reboot results**: Note whether reboot resolved issue (helps understand root cause)
- **Complete I5.T5**: Re-execute full data loss recovery test following Section 5.4 procedure
- **Test alternative access**: During next test, document how to access server via Hetzner Rescue if SSH fails again

---

### For Production Readiness

**Improvements needed before relying on this procedure in production**:

- **Monitoring implementation**: Add uptime monitoring and SSH availability checks for all production systems (mail-1, syncthing-1)
- **Alternative access procedures**: Document and test Hetzner Rescue System procedures for emergency access when SSH fails
- **Automated health checks**: Implement daily automated checks for SSH access, Storage Box mount, restic repository health
- **Alerting system**: Set up alerts for SSH daemon failures, Storage Box mount failures, backup job failures
- **Runbook completeness**: Add "Troubleshooting SSH Access" section to disaster_recovery.md with step-by-step recovery procedures
- **Pre-flight validation**: Make prerequisite validation mandatory step before all DR tests and production recovery operations
- **Test environment reliability**: Test-1.dev.nbg should be stable enough for quarterly DR testing (current connectivity issue undermines test confidence)

---

## Appendices

### Command Output

**Key command outputs captured during troubleshooting**:

```
$ ssh -i ~/.ssh/homelab/hetzner -o StrictHostKeyChecking=no root@5.75.134.87 'hostname && date -u +"%Y-%m-%d %H:%M:%S UTC"'
ssh: connect to host 5.75.134.87 port 22: Operation timed out

$ cd ansible && ansible test-1.dev.nbg -m shell -a 'hostname && date -u +"%Y-%m-%d %H:%M:%S UTC"'
test-1.dev.nbg | UNREACHABLE! => {
    "changed": false,
    "msg": "Data could not be sent to remote host \"5.75.134.87\". Make sure this host can be reached over ssh: mux_client_request_session: read from master failed: Broken pipe\r\nFailed to connect to new control master\r\n",
    "unreachable": true
}

$ hcloud server list | grep test-1
111301341   test-1.dev.nbg         running   5.75.134.87      2a01:4f8:1c1c:a339::/64   10.0.0.4 (homelab)   nbg1-dc3     8d

$ hcloud firewall list
ID   NAME   RULES COUNT   APPLIED TO COUNT

$ ls -la ~/.ssh/homelab/hetzner
-rw------- 1 plumps staff 399 Oct 20  2024 /Users/plumps/.ssh/homelab/hetzner

$ cd ansible && ansible-inventory --host test-1.dev.nbg
{
    "ansible_host": "5.75.134.87",
    "ansible_ssh_private_key_file": "~/.ssh/homelab/hetzner",
    "ansible_user": "root",
    "backup_paths": [
        "/etc/hostname",
        "/etc/hosts",
        "/var/log/syslog"
    ],
    "env": "dev",
    "restic_repository_path": "/mnt/storagebox/restic-dev-backups",
    ...
}
```

---

### Screenshots

Not applicable (CLI-based troubleshooting, no GUI interactions)

---

### Test Environment Details

**System specifications** (from Hetzner Cloud and I5.T1 test results):
- **Hostname**: test-1.dev.nbg
- **Hetzner Server ID**: 111301341
- **OS**: Ubuntu 24.04 LTS (from I5.T1)
- **Hardware**: Hetzner CAX11 (ARM64, 2 vCPU, 4GB RAM, 40GB disk)
- **Network**:
  - Public IPv4: 5.75.134.87
  - Public IPv6: 2a01:4f8:1c1c:a339::/64
  - Private IP: 10.0.0.4 (homelab network)
- **Location**: nbg1-dc3 (Nuremberg, Germany)
- **Status**: running (8 days uptime per Hetzner API)
- **Services** (from I5.T1):
  - restic-backup.service (systemd timer for daily backups)
  - Storage Box mounted at /mnt/storagebox
- **Backup Configuration** (from I5.T1):
  - Repository: /mnt/storagebox/restic-dev-backups
  - Paths: /etc/hostname, /etc/hosts, /var/log/syslog
  - Schedule: Daily at 03:00 (with 15m randomized delay)
  - Retention: 3 daily, 2 weekly, 1 monthly
  - Existing snapshots: 256d5ca2 (2025-10-30 10:07:56), 1f3bd427 (2025-10-30 10:33:56)

**Accessibility**: SSH to root@5.75.134.87 using ~/.ssh/homelab/hetzner key (currently timing out)

---

### References

**Documentation consulted during test**:
- Test plan: [recovery_testing_plan.md#54-test-4-data-loss-recovery](../runbooks/recovery_testing_plan.md#54-test-4-data-loss-recovery)
- Disaster recovery procedure: [disaster_recovery.md#7-scenario-4-data-loss-accidental-deletion](../runbooks/disaster_recovery.md#7-scenario-4-data-loss-accidental-deletion)
- Backup verification: [backup_verification.md](../runbooks/backup_verification.md)
- Previous test results: [i5_t1_test_results.md](i5_t1_test_results.md) (documented existing snapshots and backup configuration)
- Test results template: [recovery_test_results_template.md](../templates/recovery_test_results_template.md)

---

## Test Review

**Test Reviewed By**: Self-reviewed

**Review Date**: 2025-10-30

**Review Notes**: Test execution was blocked by SSH connectivity issue to test-1.dev.nbg. Systematic troubleshooting was performed (SSH direct, Ansible, server status checks, firewall checks, key verification), but server remains unreachable despite "running" status in Hetzner Cloud. Root cause likely internal to VPS (firewall, SSH daemon failure, or resource exhaustion). Test must be re-executed after restoring connectivity.

**Identified critical gap**: Recovery testing plan lacks pre-flight validation procedures. Tests should validate prerequisites (especially SSH) before starting execution, and should document recovery procedures for when prerequisites fail (e.g., using Hetzner Rescue system).

**Recommendation**: Reboot test-1.dev.nbg via Hetzner Cloud, verify connectivity restored, then immediately re-run I5.T5. Update recovery_testing_plan.md to add pre-flight validation to all test scenarios.

**Approval Status**: Draft (awaiting test re-execution after connectivity restored)

---

## Document Metadata

**Test Report Version**: 1.0

**Template Version**: 1.0

**Template Source**: [recovery_testing_plan.md#8-test-results-documentation](../runbooks/recovery_testing_plan.md#8-test-results-documentation)

**Created**: 2025-10-30

**Last Updated**: 2025-10-30

**Document Location**: `docs/refactoring/i5_recovery_test_results.md`

---

**End of Test Report**
