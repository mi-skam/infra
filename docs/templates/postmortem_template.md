# Incident Postmortem: [Title]

**Incident ID**: [e.g., INC-2025-001]
**Date**: [YYYY-MM-DD]
**Severity**: [P1/P2/P3/P4]
**Duration**: [Total downtime/impact duration]
**Author**: [Name]
**Status**: [Draft/Under Review/Final]

---

## Incident Summary

[2-3 sentence overview: what happened, what systems were affected, what was the impact, and how was it resolved?]

**Example**: "On 2025-10-30 at 14:35 UTC, the mail-1.prod.nbg server's Postfix service crashed due to a configuration error introduced during deployment. All inbound and outbound email was unavailable for 23 minutes. The issue was resolved by reverting the configuration change and restarting the service."

---

## Timeline

| Time (UTC) | Event | Action Taken |
|------------|-------|--------------|
| HH:MM | [Event description] | [Action taken by operator] |
| HH:MM | [Event description] | [Action taken by operator] |
| HH:MM | [Event description] | [Action taken by operator] |

**Example Timeline**:
```
14:35 | Postfix service failed after ansible deployment | None (not yet detected)
14:40 | Monitoring alert: mail delivery failures | Began triage, SSH to mail-1
14:42 | Identified systemd failure, checked logs | Found configuration syntax error
14:45 | Decided to rollback configuration | Executed git revert + ansible-deploy
14:52 | Postfix restarted successfully | Verified service status
14:58 | Confirmed email delivery working | Sent test emails, checked queue
```

---

## Root Cause Analysis

### Immediate Cause
[What directly caused the incident? Be specific about the technical failure.]

**Example**: "A syntax error in `/etc/postfix/main.cf` (missing semicolon on line 47) prevented Postfix from starting after configuration deployment."

### Contributing Factors
[What made this possible or made the impact worse?]
- [Factor 1: e.g., insufficient pre-deployment validation]
- [Factor 2: e.g., lack of automated syntax checking]
- [Factor 3: e.g., no staging environment for mail configuration testing]

### Why This Wasn't Caught Earlier
[What detection or prevention gaps allowed this to reach production?]

**Example**: "The Ansible playbook does not validate Postfix configuration syntax before deployment. The change was tested manually but the syntax error was in a conditional block that wasn't exercised during testing."

---

## Impact Assessment

### Systems Affected
- **[System 1]**: [Description of impact and duration]
- **[System 2]**: [Description of impact and duration]

**Example**:
- **mail-1.prod.nbg**: Complete mail service outage (inbound/outbound) for 23 minutes
- **syncthing-1.prod.hel**: No impact (uses separate email notifications)

### Users Affected
[Number/description of affected users and how they were impacted]

**Example**: "All 5 email users experienced inability to send/receive email. Approximately 12 inbound emails were delayed (queued at sender MTAs) but not lost."

### Data Loss
**Data Loss**: [Yes/No]
**Details**: [If yes, what data was lost? How much? Was it recoverable?]

**Example**: "No data loss. All emails were queued at sender servers and delivered after service restoration."

### Downtime
**Total Downtime**: [Duration]
**Services Affected**: [List of services]
**User-Facing Impact**: [Description]

**Example**: "23 minutes of complete mail service unavailability (14:35-14:58 UTC)"

### RTO/RPO Compliance
**RTO Target**: [From disaster recovery plan]
**Actual RTO**: [Measured recovery time]
**RPO Target**: [From disaster recovery plan]
**Actual RPO**: [Measured data loss window]
**Met Targets?**: [Yes/No, with explanation]

**Example**: "RTO target: <5 min (P1), Actual: 23 min (exceeded due to deployment rollback complexity). RPO target: 0, Actual: 0 (no data loss). Did not meet RTO target."

---

## Resolution Steps

### Actions Taken
1. [Step 1: Detection and triage]
2. [Step 2: Initial containment]
3. [Step 3: Investigation]
4. [Step 4: Resolution implementation]
5. [Step 5: Verification]

**Example**:
1. **Triage** (14:40-14:42): SSH to mail-1, checked `systemctl status postfix`, identified failed state
2. **Investigation** (14:42-14:45): Examined `journalctl -u postfix`, found configuration syntax error
3. **Resolution** (14:45-14:52): Reverted configuration using `git revert HEAD && just ansible-deploy`
4. **Verification** (14:52-14:58): Confirmed Postfix running, tested email delivery, checked mail queue

### Runbooks Used
- [Link to runbook section used, e.g., `disaster_recovery.md#scenario-3`]
- [Link to rollback procedure used, e.g., `rollback_procedures.md#ansible-rollback`]

**Example**:
- [Disaster Recovery: Service Failure](../runbooks/disaster_recovery.md#scenario-3-service-failure-vps-application-crash)
- [Rollback Procedures: Ansible](../runbooks/rollback_procedures.md#scenario-3-ansible-playbook-applied-service-down)

### What Worked Well
[Positive aspects of the response]
- [Success 1]
- [Success 2]

**Example**:
- Monitoring detected the issue within 5 minutes
- Rollback procedure was well-documented and executed cleanly
- Root cause identification was straightforward due to clear error logs

### What Slowed Recovery
[Challenges or obstacles during response]
- [Challenge 1]
- [Challenge 2]

**Example**:
- No pre-deployment validation caught the syntax error
- RTO exceeded because full ansible deployment takes ~7 minutes

---

## Prevention Measures

### Immediate Actions (Already Implemented)
[Actions taken immediately after incident to prevent recurrence]
- [x] [Action 1: e.g., Reverted problematic configuration]
- [x] [Action 2: e.g., Added manual verification step to deployment checklist]

### Short-term Improvements (Next 30 Days)
[Actions to implement within the next month]
- [ ] [Action 1: Owner, Due Date]
- [ ] [Action 2: Owner, Due Date]

**Example**:
- [ ] Add `postfix check` validation to Ansible playbook before service restart (Maxime, 2025-11-15)
- [ ] Create Postfix configuration test cases for common changes (Maxime, 2025-11-20)

### Long-term Improvements (Next Quarter)
[Strategic improvements to prevent similar incidents]
- [ ] [Action 1: Owner, Due Date]
- [ ] [Action 2: Owner, Due Date]

**Example**:
- [ ] Implement staging environment for mail configuration testing (Maxime, 2025-12-31)
- [ ] Add automated configuration validation to CI/CD pipeline (Maxime, 2026-01-15)

---

## Action Items

| Action | Owner | Due Date | Priority | Status |
|--------|-------|----------|----------|--------|
| [Specific action item] | [Name] | [YYYY-MM-DD] | [High/Med/Low] | [Open/In Progress/Done] |
| [Specific action item] | [Name] | [YYYY-MM-DD] | [High/Med/Low] | [Open/In Progress/Done] |

**Example**:
| Action | Owner | Due Date | Priority | Status |
|--------|-------|----------|----------|--------|
| Add postfix syntax validation to ansible-deploy playbook | Maxime | 2025-11-15 | High | Open |
| Document manual verification steps in deployment_procedures.md | Maxime | 2025-11-10 | Medium | Open |
| Research staging environment options for mail testing | Maxime | 2025-12-01 | Low | Open |

---

## Lessons Learned

### What Went Well
[Positive outcomes and effective practices]
- [Positive 1]
- [Positive 2]

**Example**:
- Incident detection was fast (5 minutes)
- Rollback procedure was clear and well-practiced
- No data loss occurred due to email queueing at sender MTAs
- Root cause was quickly identified from clear error messages

### What Could Be Improved
[Areas for improvement in processes, tools, or practices]
- [Improvement 1]
- [Improvement 2]

**Example**:
- Pre-deployment validation should catch syntax errors
- RTO target not met - need faster rollback mechanism for config-only changes
- No automated alerting for systemd service failures (detected via monitoring delay)

### Process Changes
[Specific changes to procedures, runbooks, or workflows]
- [Change 1]
- [Change 2]

**Example**:
- Update deployment_procedures.md to require `postfix check` before applying mail config changes
- Add systemd service status checks to monitoring (reduce detection time to <1 min)
- Create separate fast-rollback procedure for configuration-only changes (avoid full ansible run)

### Knowledge Gaps Identified
[What information or skills would have helped prevent or respond faster?]
- [Gap 1]
- [Gap 2]

**Example**:
- Need better understanding of Postfix configuration validation tools
- Should document common Postfix failure modes in runbooks

---

## References

### Related Documentation
- **Incident Ticket**: [Link to GitHub issue or tracking system]
- **Chat Logs**: [Link to incident communication channel]
- **Metrics/Graphs**: [Link to monitoring dashboards or graphs]
- **Configuration Changes**: [Link to git commits involved]

### Runbooks Referenced
- [disaster_recovery.md](../runbooks/disaster_recovery.md)
- [rollback_procedures.md](../runbooks/rollback_procedures.md)
- [deployment_procedures.md](../runbooks/deployment_procedures.md)

### External Resources
- [Link to vendor documentation used]
- [Link to community forum posts or Stack Overflow]

---

## Postmortem Review

**Postmortem Reviewed By**: [Name(s) of reviewers]
**Review Date**: [YYYY-MM-DD]
**Review Notes**: [Any feedback or additional context from reviewers]

**Approval Status**: [Draft/Approved/Needs Revision]

---

## Appendix

### Additional Context
[Any supplementary information, logs, screenshots, or technical details that provide context but aren't essential to the main narrative]

### Related Incidents
[Links to similar past incidents or related postmortems]

---

## Document Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-30 | 1.0 | Initial postmortem template | Claude (I5.T3) |

---

**Template Version**: 1.0
**Last Updated**: 2025-10-30
**Template Source**: [Incident Response Plan](../runbooks/incident_response.md)

---

## How to Use This Template

1. **Copy this template** to create a new postmortem document
2. **Save as**: `docs/postmortems/YYYY-MM-DD-brief-description.md`
3. **Fill in all sections** - replace placeholders with actual incident details
4. **Complete within 3 business days** of incident resolution
5. **Mandatory for P1 and P2 incidents**, optional for P3/P4
6. **Share with stakeholders** as defined in communication plan
7. **Add action items** to project tracking system
8. **Archive** completed postmortem in `docs/postmortems/` directory

**Note**: For single-operator context, "Reviewed By" can be "Self-reviewed" - the value is in documenting lessons learned, not bureaucratic approval.
