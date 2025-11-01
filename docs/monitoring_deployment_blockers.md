# Monitoring Deployment Blockers

## Overview
This document tracks critical blockers preventing full end-to-end validation of the monitoring infrastructure deployed in task I7.T3.

---

## 1. Network Connectivity Between test-1 and srv-01

**Status:** 🔴 BLOCKED - Requires VPN Setup

### Issue Description
- srv-01 (local NixOS server) is not on the Hetzner private network (10.0.0.0/16)
- test-1.dev.nbg (Hetzner VPS, Ubuntu 24.04) cannot reach srv-01:3100 (Loki) or srv-01:9090 (Prometheus)
- DNS resolution fails from test-1: `lookup srv-01 on 127.0.0.53:53: server misbehaving`

### Evidence
Promtail service running on test-1 continuously logs connection failures:
```
level=error ts=2025-11-01T18:52:09.813673764Z caller=client.go:430 component=client host=srv-01:3100
msg="final error sending batch" status=-1 tenant=
error="Post \"http://srv-01:3100/loki/api/v1/push\": dial tcp: lookup srv-01 on 127.0.0.53:53: server misbehaving"
```

### Impact on Task I7.T3
- ✅ node_exporter deployed successfully on test-1
- ✅ Promtail deployed successfully on test-1
- ❌ Promtail cannot ship logs to Loki on srv-01
- ❌ Prometheus on srv-01 cannot scrape metrics from test-1:9100
- ❌ Cannot validate complete monitoring pipeline end-to-end

### Acceptance Criteria Affected
1. **"Prometheus targets page shows test-1 as UP"** - Cannot verify without access to srv-01 Prometheus UI
2. **"Grafana shows test-1 metrics"** - Cannot verify without access to srv-01 Grafana UI
3. **"Loki shows test-1 logs"** - BLOCKED: Promtail cannot reach srv-01

### Acceptance Criteria Passing
1. ✅ group_vars/dev.yaml includes monitoring variables
2. ✅ ansible/playbooks/monitoring.yaml applies monitoring role to dev group
3. ✅ Ansible deployment succeeds (non-check mode): 20 tasks OK, 4 changed, 0 failed
4. ✅ node_exporter running on test-1: `systemctl is-active node_exporter` returns `active`
5. ✅ Promtail running on test-1: `systemctl is-active promtail` returns `active`
6. ✅ node_exporter metrics accessible: `curl http://localhost:9100/metrics` returns Prometheus metrics
7. ✅ Firewall configured: ufw allows port 9100/tcp

---

## 2. IP Address Mismatch in Prometheus Configuration

**Status:** 🟡 NEEDS FIX - Incorrect IP in monitoring.nix

### Issue Description
- Prometheus scrape configuration in `modules/nixos/monitoring.nix` line 129 uses IP `10.0.0.20:9100`
- test-1.dev.nbg's actual Hetzner private IP is `10.0.0.4` (verified from Ansible inventory and `ip addr` output)

### Current Configuration
```nix
# modules/nixos/monitoring.nix:129
{
  job_name = "test-1";
  static_configs = [{
    targets = [ "10.0.0.20:9100" ];  # WRONG IP
    labels = {
      environment = "dev";
      platform = "ubuntu";
      arch = "arm64";
      datacenter = "nbg1";
    };
  }];
}
```

### Required Fix
```nix
# modules/nixos/monitoring.nix:129
{
  job_name = "test-1";
  static_configs = [{
    targets = [ "10.0.0.4:9100" ];  # CORRECT IP from inventory
    labels = {
      environment = "dev";
      platform = "ubuntu";
      arch = "arm64";
      datacenter = "nbg1";
    };
  }];
}
```

### Post-Fix Actions
After updating the IP address:
```bash
# Rebuild srv-01 NixOS configuration
sudo nixos-rebuild switch --flake .#srv-01

# Verify Prometheus targets after rebuild
# Browse to http://srv-01:9090/targets
# Confirm "test-1" job shows 10.0.0.4:9100 with state UP
```

---

## Required Actions to Complete Task I7.T3

### Priority 1: Fix IP Address Mismatch (Independent Fix)
1. Edit `modules/nixos/monitoring.nix` line 129
2. Change `targets = [ "10.0.0.20:9100" ];` to `targets = [ "10.0.0.4:9100" ];`
3. Rebuild srv-01: `sudo nixos-rebuild switch --flake .#srv-01`
4. Verify Prometheus scraping (if srv-01 can reach test-1's Hetzner private IP)

**Note:** This fix is independent of VPN deployment and can be completed immediately.

### Priority 2: Deploy VPN for srv-01 ↔ Hetzner Connectivity (Blocker for Log Shipping)

**Recommended Solution: Tailscale (Zero-Config Mesh VPN)**

#### Why Tailscale?
- Zero-config mesh VPN (no manual routing or firewall rules)
- Cross-platform support (NixOS, Debian, Ubuntu, Rocky)
- Automatic NAT traversal (no port forwarding required)
- Per-host IP assignment (stable addressing)
- Simple deployment via Ansible

#### Implementation Steps:
1. Deploy Tailscale to srv-01 (NixOS module)
2. Deploy Tailscale to test-1 via Ansible
3. Get srv-01's Tailscale IP address
4. Update `ansible/inventory/group_vars/dev.yaml`:
   ```yaml
   loki_url: "http://<srv-01-tailscale-ip>:3100"
   ```
5. Redeploy monitoring agents to test-1:
   ```bash
   cd ansible && ansible-playbook playbooks/monitoring.yaml --limit test-1.dev.nbg
   ```

#### Alternative Solutions:
1. **WireGuard VPN** - More complex configuration, full control
2. **SSH Tunnel (temporary)** - For testing only: `ssh -L 3100:localhost:3100 srv-01`
3. **Public Exposure** - NOT RECOMMENDED (security risk)

**Estimated Effort:** 1-2 hours for Tailscale deployment and configuration

### Priority 3: Verification After VPN Deployment

Once VPN is operational and IP address is fixed:

1. **Test connectivity from test-1 to srv-01:**
   ```bash
   ssh test-1 "curl -v --connect-timeout 5 http://srv-01:3100/ready"
   # Should return "ready" response (Loki readiness check)
   ```

2. **Verify Promtail log shipping:**
   ```bash
   ssh test-1 "journalctl -u promtail -n 50"
   # Should show NO errors about "lookup srv-01" or "dial tcp"
   # Should show successful log shipping messages
   ```

3. **Verify Prometheus targets:**
   - Browse to http://srv-01:9090/targets
   - Find "test-1" job
   - Verify target shows 10.0.0.4:9100 with state UP (green)
   - Verify last scrape timestamp is recent (<30 seconds)

4. **Verify Grafana metrics:**
   - Browse to http://srv-01:3000
   - Navigate to Explore → Prometheus
   - Query: `node_load1{job="test-1"}`
   - Verify data points returned with recent timestamps

5. **Verify Grafana logs:**
   - In Grafana Explore → Loki
   - Query: `{job="test-1"}` or `{host="test-1"}`
   - Verify recent syslog entries visible from test-1

---

## Current Task Status Summary

### ✅ Completed (Agents Deployed)
- Monitoring role deployed to test-1.dev.nbg
- node_exporter running and serving metrics
- Promtail running (but unable to connect to Loki)
- Firewall configured correctly
- Ansible playbook created and tested

### 🟡 Partial Completion (Awaiting Fixes)
- Check-mode compatibility: ✅ FIXED (added stat checks before extraction)
- IP address mismatch: ⚠️ NEEDS FIX in monitoring.nix line 129
- End-to-end verification: ⚠️ BLOCKED on VPN deployment

### ❌ Blocked (Requires VPN)
- Promtail log shipping to Loki
- Prometheus scraping from srv-01 (may work if Hetzner private network is routable)
- Grafana metrics verification
- Grafana logs verification

---

## Recommendations

1. **Mark I7.T3 as Partially Complete:** Monitoring agents are successfully deployed and functional locally. End-to-end validation requires VPN setup, which should be tracked as a separate task.

2. **Create Follow-Up Task (I7.T3.1):** "Deploy Tailscale VPN for srv-01 to Hetzner connectivity"
   - Estimated effort: 1-2 hours
   - Blocker for: Full monitoring pipeline validation
   - Dependencies: I7.T3 (monitoring agents deployed)

3. **Fix IP Address Immediately:** The IP mismatch in monitoring.nix can be fixed independently of VPN deployment and should be corrected before final verification.

4. **Document Lessons Learned:**
   - Network connectivity between local and cloud infrastructure requires VPN
   - Always verify IP addresses match between infrastructure as code and actual deployments
   - Check-mode compatibility requires explicit handling for tasks that access downloaded files

---

## Next Steps After I7.T3 Completion

After both the IP fix and VPN deployment are complete:
1. ✅ Mark I7.T3 as complete
2. ➡️ Proceed to I7.T4: Create Grafana dashboards for test-1 metrics
3. ➡️ Proceed to I7.T5: Implement CI/CD pipeline for monitoring configuration validation
4. ➡️ Eventually I7.T6: Test and document monitoring and CI/CD end-to-end

**Dependencies for Future Tasks:**
- I7.T4 (Grafana dashboards) requires I7.T3 + VPN deployment (test-1 metrics must be available)
- I7.T5 (CI/CD pipeline) can proceed independently
- I7.T6 (End-to-end testing) requires I7.T3 + I7.T4 + I7.T5 all complete
