# Disaster Recovery Test Report

**Test ID**: [e.g., DRT-2025-Q1-001]
**Test Date**: [YYYY-MM-DD]
**Test Time**: [HH:MM - HH:MM UTC]
**Operator**: [Name]
**Test Scenario**: [Configuration Error / Infrastructure Error / Service Failure / Data Loss / Complete VPS Loss]
**Scenario Reference**: [Link to recovery_testing_plan.md section, e.g., recovery_testing_plan.md#51-test-1-configuration-error-recovery]

---

## Test Summary

**Objective**: [What was being tested? Copy from test scenario objective]

**System**: [test-1.dev.nbg / mail-1.prod.nbg / xmsi / etc.]

**Duration**: [Actual test execution time from start to end]

**Result**: [PASS / FAIL / PARTIAL]

**One-sentence summary**: [Brief description of test outcome]

**Example**: "Configuration error rollback procedure successfully validated on test-1.dev.nbg with Ansible syntax error recovery completing in 3 minutes 42 seconds (within <5 min RTO target)."

---

## Test Execution

### Preparation

**Prerequisites Completed**:
- [ ] Test plan reviewed (recovery_testing_plan.md section read)
- [ ] Target system confirmed (hostname verified)
- [ ] Environment validated (SSH access, git clean, services running)
- [ ] Safety checks performed (correct system, no production risk)
- [ ] Documentation ready (DR runbook, rollback procedures accessible)
- [ ] Timer/stopwatch ready for RTO measurement

**Test Environment Setup**:
- **System hostname**: [hostname output]
- **System IP**: [IP address]
- **Git status**: [clean / X files uncommitted]
- **Services baseline**: [systemctl --failed output: 0 services / X services]
- **Test data prepared**: [Yes/No - describe if applicable]

**Baseline State Documented**: [Yes/No]

---

### Failure Simulation

**Start Time**: [YYYY-MM-DD HH:MM:SS UTC]

**Failure Simulation Method**: [Brief description of how failure was simulated]

**Commands Executed**:
```bash
[Exact commands used to simulate failure]
# Example:
# vim ansible/playbooks/deploy.yaml  # Introduced syntax error
# git add ansible/playbooks/deploy.yaml
# just ansible-deploy --limit test-1.dev.nbg
```

**Expected Outcome**: [What should happen when failure is simulated]

**Example**: "Ansible syntax check should fail with 'ERROR! Syntax Error while loading YAML' message, deployment should abort before reaching target system."

**Actual Outcome**: [What actually happened]

**Example**: "Ansible syntax check failed as expected with error 'ERROR! Syntax Error while loading YAML. Mapping values are not allowed in this context.' Deployment aborted before any changes applied to target system."

**Failure Confirmed**: [Yes/No]

**Failure Detection Method**: [Build failure / Deployment error / Service status / User report / Monitoring alert]

---

### Recovery Execution

**Recovery Start Time**: [YYYY-MM-DD HH:MM:SS UTC]

**Procedure Followed**: [Link to disaster recovery runbook section used]

**Example**: "[disaster_recovery.md#4-scenario-1-configuration-error-bad-nix-build](../runbooks/disaster_recovery.md#4-scenario-1-configuration-error-bad-nix-build)"

**Recovery Method**: [Which recovery option from DR runbook was used]

**Example**: "Option A: Fix Configuration Error (Pre-Deployment) - Rollback using git checkout"

**Commands Executed**:
```bash
[Exact recovery commands executed]
# Example:
# git checkout -- ansible/playbooks/deploy.yaml
# git status  # Verified clean
# cd ansible/
# ansible-playbook playbooks/deploy.yaml --syntax-check  # Verified valid
# ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg --check  # Verified idempotent
```

**Time to Complete Each Step**:
- Detection: [X minutes - time from failure to recognizing need for recovery]
- Decision: [X minutes - time to decide on recovery method]
- Execution: [X minutes - time to execute recovery commands]
- Verification: [X minutes - time to verify recovery successful]

**Recovery End Time**: [YYYY-MM-DD HH:MM:SS UTC]

**Total Recovery Time (RTO)**: [Calculated: End Time - Start Time]

**Deviations from Documented Procedure**: [Any steps that didn't work as documented, or additional steps needed]

**Example**: "No deviations. Procedure followed exactly as documented in disaster_recovery.md Section 4."

---

### Verification

**Verification Checks Performed**:

1. **[Check 1 Name]**: [Description and result]
   - **Command**: `[command executed]`
   - **Expected Output**: [what should happen]
   - **Actual Output**: [what did happen]
   - **Status**: [✅ PASS / ❌ FAIL]

2. **[Check 2 Name]**: [Description and result]
   - **Command**: `[command executed]`
   - **Expected Output**: [what should happen]
   - **Actual Output**: [what did happen]
   - **Status**: [✅ PASS / ❌ FAIL]

3. **[Check 3 Name]**: [Description and result]
   - **Command**: `[command executed]`
   - **Expected Output**: [what should happen]
   - **Actual Output**: [what did happen]
   - **Status**: [✅ PASS / ❌ FAIL]

**Example**:
1. **Configuration Syntax Valid**: Ansible syntax check passes
   - **Command**: `ansible-playbook playbooks/deploy.yaml --syntax-check`
   - **Expected Output**: "playbook: playbooks/deploy.yaml"
   - **Actual Output**: "playbook: playbooks/deploy.yaml"
   - **Status**: ✅ PASS

2. **System Operational**: Services running, no failed units
   - **Command**: `ssh root@test-1.dev.nbg 'systemctl --failed'`
   - **Expected Output**: "0 loaded units listed."
   - **Actual Output**: "0 loaded units listed."
   - **Status**: ✅ PASS

3. **No Configuration Drift**: Re-running Ansible shows no changes
   - **Command**: `ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg`
   - **Expected Output**: "changed=0"
   - **Actual Output**: "ok=12  changed=0  unreachable=0  failed=0"
   - **Status**: ✅ PASS

**All Verification Checks Passed**: [Yes/No]

**Stability Check**: [Did system remain stable after recovery? Monitored for X minutes, no re-failure]

---

## Test Results

### RTO/RPO Assessment

| Metric | Target | Actual | Met Target? | Notes |
|--------|--------|--------|-------------|-------|
| **RTO** (Recovery Time Objective) | [e.g., <5 min] | [e.g., 3 min 42 sec] | ✅ Yes / ❌ No | [Explanation if target not met] |
| **RPO** (Recovery Point Objective) | [e.g., 0 data loss] | [e.g., 0 data loss] | ✅ Yes / ❌ No | [Explanation if target not met] |

**RTO Breakdown**:
- **Detection**: [X min XX sec] - Time from failure occurrence to detection
- **Decision**: [X min XX sec] - Time to decide on recovery method
- **Execution**: [X min XX sec] - Time to execute recovery procedure
- **Verification**: [X min XX sec] - Time to verify successful recovery
- **Total**: [X min XX sec]

**RTO Analysis**: [Was target met? Why or why not? What affected timing?]

**Example**: "RTO target met with 1 minute 18 seconds to spare. Recovery was faster than target due to familiarity with rollback procedure and pre-deployment detection (no actual deployment occurred, only build failure)."

**RPO Analysis**: [Was target met? How much data loss occurred, if any?]

**Example**: "RPO target met with zero data loss. Configuration error was detected before deployment, so no changes were applied to production system. Application data completely unaffected."

---

### Pass/Fail by Acceptance Criteria

| Acceptance Criterion | Status | Notes |
|---------------------|--------|-------|
| Recovery completed within RTO target | ✅ PASS / ❌ FAIL / 🔶 PARTIAL | [Details] |
| Data loss within RPO target | ✅ PASS / ❌ FAIL / 🔶 PARTIAL | [Details] |
| All services operational after recovery | ✅ PASS / ❌ FAIL / 🔶 PARTIAL | [Details] |
| All verification steps passed | ✅ PASS / ❌ FAIL / 🔶 PARTIAL | [Details] |
| Test documented using template | ✅ PASS / ❌ FAIL / 🔶 PARTIAL | [Details] |

**Overall Test Result**: [PASS / FAIL / PARTIAL]

**Result Justification**: [Why did test receive this result? Summarize key factors]

**Example**: "Test receives PASS result. All acceptance criteria met: RTO target achieved (3m 42s < 5m target), RPO target achieved (zero data loss), all services operational, all 5 verification checks passed, test fully documented."

---

## Issues Encountered

### Issue 1: [Brief description]

**Severity**: [High / Medium / Low]

**Impact**: [How did this affect the test or recovery?]

**Root Cause**: [What caused this issue? If unknown, note "Under investigation"]

**Workaround Used**: [How was the issue bypassed during test? If none, note "None - test failed at this point"]

**Recommendation**: [What should be done to prevent this in future?]

---

### Issue 2: [Brief description]

**Severity**: [High / Medium / Low]

**Impact**: [How did this affect the test or recovery?]

**Root Cause**: [What caused this issue?]

**Workaround Used**: [How was the issue bypassed?]

**Recommendation**: [What should be done to prevent this?]

---

**[Repeat for each issue encountered]**

**If no issues**: "No issues encountered during test execution. All procedures worked as documented."

---

### Example Issues

**Example Issue 1: Runbook command outdated**

**Severity**: Medium

**Impact**: Initial rollback command failed, required consulting git documentation, added 2 minutes to RTO

**Root Cause**: Disaster recovery runbook Section 4 listed `git checkout ansible/playbooks/deploy.yaml` without `--` separator, causing git to interpret path as branch name

**Workaround Used**: Used correct syntax `git checkout -- ansible/playbooks/deploy.yaml` (with `--` separator)

**Recommendation**: Update disaster_recovery.md Section 4 Step 2 to include `--` separator in git checkout command

---

## Lessons Learned

### What Went Well

**Positive aspects of test execution and recovery**:

- [Positive aspect 1]
- [Positive aspect 2]
- [Positive aspect 3]

**Example**:
- Pre-deployment detection worked perfectly - error caught before any changes applied to system
- Rollback procedure was straightforward and quick
- Verification steps were comprehensive and caught all potential issues
- Muscle memory from previous tests made execution smoother

---

### What Could Be Improved

**Areas for improvement in processes, tools, or practices**:

- [Improvement area 1]
- [Improvement area 2]
- [Improvement area 3]

**Example**:
- Error message from Ansible could be clearer about which file/line had syntax error
- Runbook should emphasize importance of `--syntax-check` before deployment
- Pre-deployment validation could be automated (CI/CD syntax check)
- Test data setup procedure needs to be documented more clearly

---

### Runbook Updates Needed

**Specific sections of runbooks that need updates**:

- [ ] **[disaster_recovery.md](../runbooks/disaster_recovery.md)**: Section 4, Step 2 - Add `--` separator to git checkout command
- [ ] **[rollback_procedures.md](../runbooks/rollback_procedures.md)**: Section X, Paragraph Y - [Description of needed update]
- [ ] **[backup_verification.md](../runbooks/backup_verification.md)**: Section X - [Description of needed update]
- [ ] **[recovery_testing_plan.md](../runbooks/recovery_testing_plan.md)**: Section X - [Description of needed update]

**Rationale for each update**: [Why is this update needed? What problem does it solve?]

**Example**:
- [ ] **disaster_recovery.md**: Section 4, Step 2 - Add `--` separator to git checkout command to prevent ambiguous path/branch interpretation. This caused 2-minute delay in test when command failed without `--`.
- [ ] **recovery_testing_plan.md**: Section 5.1 - Add note about verifying Ansible syntax before simulating failure, to establish clearer baseline.

---

### Process Changes

**Changes to procedures, workflows, or testing approach**:

- [Process change 1]
- [Process change 2]

**Example**:
- Add mandatory `--syntax-check` step before all Ansible deployments (update deployment_procedures.md)
- Create pre-commit git hook to run Ansible syntax validation automatically
- Add CI/CD pipeline step to validate configuration syntax before merge

---

### Knowledge Gaps Identified

**Information or skills that would have helped prevent issues or respond faster**:

- [Knowledge gap 1]
- [Knowledge gap 2]

**Example**:
- Need better understanding of Ansible syntax validation tools (ansible-lint, yamllint)
- Should document common Ansible syntax error patterns in troubleshooting guide
- Operators should practice git rollback commands more frequently (muscle memory)

---

## Action Items

| Action | Owner | Due Date | Priority | Status | Notes |
|--------|-------|----------|----------|--------|-------|
| [Specific, actionable task] | [Name] | [YYYY-MM-DD] | High/Med/Low | Open/In Progress/Done | [Additional context] |

**Priority Definitions**:
- **High**: Critical for successful recovery, would block recovery in real incident
- **Medium**: Important for smooth recovery, workarounds exist but add time
- **Low**: Nice-to-have improvements, optimizations, or minor documentation fixes

**Example Action Items**:

| Action | Owner | Due Date | Priority | Status | Notes |
|--------|-------|----------|----------|--------|-------|
| Update disaster_recovery.md Section 4 Step 2 to add `--` separator in git checkout command | Maxime | 2025-05-01 | High | Open | Prevents ambiguous path/branch error |
| Add ansible-lint pre-commit hook to infra repository | Maxime | 2025-05-15 | Medium | Open | Automates syntax validation |
| Research Ansible syntax validation best practices | Maxime | 2025-05-30 | Low | Open | Improve prevention of syntax errors |
| Document common Ansible failure patterns in troubleshooting guide | Maxime | 2025-06-15 | Low | Open | Speed up future troubleshooting |

---

## Recommendations

### For Next Test

**What to focus on or change in the next disaster recovery test**:

- [Recommendation 1]
- [Recommendation 2]

**Example**:
- Test same scenario again in Q4 after runbook updates to verify improvements
- Focus verification on edge cases (e.g., what if syntax error in role instead of playbook?)
- Try testing with unfamiliar operator (pair testing) to validate documentation clarity

---

### For Production Readiness

**Improvements needed before relying on this procedure in production**:

- [Recommendation 1]
- [Recommendation 2]

**Example**:
- Add automated Ansible syntax validation to deployment pipeline (prevents human error)
- Implement staging environment for Ansible testing before production deployment
- Add monitoring alert for failed systemd services (improve detection time to <1 min)
- Consider blue-green deployment strategy for zero-downtime configuration changes

---

## Appendices

### Command Output

**Key command outputs captured during test**:

```
[Relevant command outputs, logs, error messages]

Example:
$ git checkout ansible/playbooks/deploy.yaml
error: pathspec 'ansible/playbooks/deploy.yaml' did not match any file(s) known to git

$ git checkout -- ansible/playbooks/deploy.yaml
Updated 1 path from the index

$ ansible-playbook playbooks/deploy.yaml --syntax-check
playbook: playbooks/deploy.yaml

$ systemctl --failed
0 loaded units listed.
```

---

### Screenshots

[If applicable, describe screenshots taken during test]

**Example**:
- Screenshot 1: Ansible syntax error message showing line number and error type
- Screenshot 2: systemctl status output showing no failed services after recovery
- Screenshot 3: Terraform plan output showing no changes after state restore

**Note**: Screenshots should be saved separately and referenced here, not embedded in markdown.

---

### Test Environment Details

**System specifications**:
- **Hostname**: [hostname]
- **OS**: [OS name and version]
- **Hardware**: [CPU, RAM, disk]
- **Network**: [Private IP, public IP if relevant]
- **Services**: [List of services deployed]

**Example**:
- **Hostname**: test-1.dev.nbg
- **OS**: Ubuntu 24.04.1 LTS
- **Hardware**: Hetzner CAX11 (ARM64, 2 vCPU, 4GB RAM, 40GB disk)
- **Network**: 10.0.0.20 (private), 198.51.100.50 (public)
- **Services**: test-recovery.service (Python HTTP server on port 8080)

---

### References

**Documentation consulted during test**:
- [Link to disaster recovery runbook section]
- [Link to rollback procedures section]
- [Link to test plan section]

**Example**:
- Test plan: [recovery_testing_plan.md#51-test-1-configuration-error-recovery](../runbooks/recovery_testing_plan.md#51-test-1-configuration-error-recovery)
- Disaster recovery procedure: [disaster_recovery.md#4-scenario-1-configuration-error-bad-nix-build](../runbooks/disaster_recovery.md#4-scenario-1-configuration-error-bad-nix-build)
- Rollback procedure: [rollback_procedures.md#41-boot-failure-grub-rollback](../runbooks/rollback_procedures.md#41-boot-failure-grub-rollback)

---

## Test Review

**Test Reviewed By**: [Name(s) of reviewers, or "Self-reviewed" for single operator]

**Review Date**: [YYYY-MM-DD]

**Review Notes**: [Feedback or additional observations from reviewer]

**Example**: "Self-reviewed on 2025-04-16. Test execution was thorough and well-documented. Identified action items are appropriate and prioritized correctly. Recommend executing runbook updates within 2 weeks and re-testing in Q4 to validate fixes."

**Approval Status**: [Draft / Approved / Needs Revision]

---

## Document Metadata

**Test Report Version**: 1.0

**Template Version**: 1.0

**Template Source**: [recovery_testing_plan.md#8-test-results-documentation](../runbooks/recovery_testing_plan.md#8-test-results-documentation)

**Created**: [YYYY-MM-DD]

**Last Updated**: [YYYY-MM-DD]

**Document Location**: `docs/test-results/YYYY-MM-DD-scenario-name.md`

---

## How to Use This Template

1. **Copy this template** to create new test report
2. **Save as**: `docs/test-results/YYYY-MM-DD-test-scenario-name.md`
   - Example: `docs/test-results/2025-04-15-config-error-recovery-Q1.md`
3. **Fill out during test** - Capture information in real-time as test progresses
4. **Complete within 3 days** of test execution (while details are fresh)
5. **Be specific** - Use exact commands, timestamps, error messages (not summaries)
6. **Be honest** - Document failures and issues clearly (that's the point of testing)
7. **Create action items** - Every issue should have corresponding action with owner and due date
8. **Archive** completed report in `docs/test-results/` directory
9. **Commit to git** - Track test results over time for trend analysis

**Tips**:
- Keep test results template open during test execution (fill out in real-time)
- Copy-paste exact command outputs (don't summarize or paraphrase)
- Use code blocks for commands and outputs (preserves formatting)
- Take screenshots of key moments (errors, verification results)
- Note start/end times immediately (don't rely on memory)
- Document deviations as they happen (don't wait until end)

---

## Template Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-30 | 1.0 | Initial test results template created for I5.T4 | Claude |

---

**Template Status**: Active

**Related Templates**:
- [Postmortem Template](postmortem_template.md) - For documenting real incidents (not tests)

**Related Runbooks**:
- [Recovery Testing Plan](../runbooks/recovery_testing_plan.md) - Test procedures and acceptance criteria
- [Disaster Recovery Runbook](../runbooks/disaster_recovery.md) - Recovery procedures being tested
- [Incident Response Plan](../runbooks/incident_response.md) - Incident response workflow and postmortem process

---

**End of Test Results Template**
