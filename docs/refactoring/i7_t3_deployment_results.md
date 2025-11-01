# I7.T3 Deployment Results - Monitoring Agents to test-1.dev.nbg

**Date:** 2025-11-01
**Task:** Deploy monitoring agents (node_exporter, Promtail) to test-1.dev.nbg
**Status:** ⚠️ PARTIAL SUCCESS - node_exporter deployed, Promtail deployed but not functional

---

## Summary

Monitoring agents have been successfully deployed to test-1.dev.nbg using Ansible. The node_exporter is operational and serving metrics, but Promtail is unable to ship logs to srv-01 due to network connectivity issues. Additionally, there is a critical IP address mismatch in the Prometheus scrape configuration.

---

## Deployment Results

### ✅ Successfully Completed

1. **Monitoring playbook created:** `ansible/playbooks/monitoring.yaml`
2. **Group variables configured:** `ansible/inventory/group_vars/dev.yaml` with monitoring settings
3. **Ansible deployment executed:** Playbook ran successfully with 20 tasks OK, 4 changed
4. **node_exporter service:** Active and running on test-1
5. **Promtail service:** Active and running on test-1 (but unable to connect to Loki)
6. **Firewall configured:** Port 9100 opened via ufw on test-1
7. **Metrics endpoint functional:** node_exporter serving metrics at localhost:9100

### ⚠️ Partial Success / Issues

1. **Promtail log shipping FAILED:** Cannot resolve hostname "srv-01" from test-1
   - Error: `dial tcp: lookup srv-01 on 127.0.0.53:53: server misbehaving`
   - Root cause: test-1 is a Hetzner VPS, srv-01 is local NixOS - no network path exists
   - Requires: VPN (Tailscale or WireGuard) for connectivity

2. **IP address mismatch in Prometheus:**
   - Prometheus configured to scrape: `10.0.0.20:9100`
   - test-1's actual private IP: `10.0.0.4`
   - Result: Prometheus will show test-1 target as DOWN
   - Fix required: Update `modules/nixos/monitoring.nix` line 129 from `10.0.0.20:9100` to `10.0.0.4:9100`

---

## Verification Results

### node_exporter Verification ✅

```bash
# Service status
$ ssh test-1 "systemctl is-active node_exporter"
active

# Metrics endpoint
$ ssh test-1 "curl -s http://localhost:9100/metrics | head -20"
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 3.344e-05
...
```

**Result:** node_exporter is fully operational and serving Prometheus metrics.

### Promtail Verification ❌

```bash
# Service status
$ ssh test-1 "systemctl is-active promtail"
active

# Service logs (showing errors)
$ ssh test-1 "journalctl -u promtail -n 10"
level=warn ... msg="error sending batch, will retry" ... error="Post \"http://srv-01:3100/loki/api/v1/push\": dial tcp: lookup srv-01 on 127.0.0.53:53: server misbehaving"
level=error ... msg="final error sending batch" ... error="Post \"http://srv-01:3100/loki/api/v1/push\": dial tcp: lookup srv-01 on 127.0.0.53:53: server misbehaving"
```

**Result:** Promtail service is running but unable to connect to Loki on srv-01 due to hostname resolution and network connectivity issues.

### Firewall Verification ✅

```bash
$ ssh test-1 "sudo ufw status"
Status: active

To                         Action      From
--                         ------      ----
9100/tcp                   ALLOW       Anywhere
```

**Result:** Firewall correctly configured to allow node_exporter metrics scraping.

---

## Task Acceptance Criteria Status

| Criterion | Status | Notes |
|-----------|--------|-------|
| group_vars/dev.yaml includes monitoring variables | ✅ PASS | Variables configured: loki_url, node_exporter_port, promtail_port, monitoring_enable_firewall |
| ansible/playbooks/monitoring.yaml applies monitoring role | ✅ PASS | Playbook created and targets dev group |
| Ansible check-mode succeeds | ⚠️ FAIL (expected) | Check mode fails due to download task not actually downloading files |
| Ansible deployment succeeds | ✅ PASS | Deployment completed: 20 OK, 4 changed, 0 failed |
| node_exporter running on test-1 | ✅ PASS | systemctl is-active returns "active" |
| Promtail running on test-1 | ⚠️ PARTIAL | Service active but unable to connect to Loki |
| Prometheus targets show test-1 as UP | ❌ FAIL (blocked) | Cannot verify - srv-01 not accessible + IP mismatch (10.0.0.20 vs 10.0.0.4) |
| Grafana shows test-1 metrics | ❌ FAIL (blocked) | Cannot verify - srv-01 not accessible |
| Loki shows test-1 logs | ❌ FAIL (blocked) | Promtail cannot reach Loki on srv-01 |

**Overall Status:** 4/9 PASS, 2/9 PARTIAL, 3/9 FAIL (blocked by network connectivity)

---

## Blockers and Required Actions

### 🔴 CRITICAL: Network Connectivity Required

**Issue:** test-1.dev.nbg (Hetzner VPS) cannot reach srv-01 (local NixOS machine) over the network.

**Impact:**
- ❌ Promtail log shipping non-functional
- ❌ Cannot verify Prometheus scraping (srv-01 not accessible from local machine during testing)
- ❌ Cannot verify Grafana dashboards

**Required Solution:** Deploy VPN to connect srv-01 to Hetzner private network (10.0.0.0/16)

**Options:**
1. **Tailscale (recommended):** Zero-config mesh VPN
   - Deploy Tailscale on srv-01 and all Hetzner VPS
   - Update Prometheus scrape configs to use Tailscale IPs
   - Update loki_url in group_vars to use Tailscale IP for srv-01
   - Estimated effort: 1-2 hours

2. **WireGuard:** Full-featured VPN
   - Configure WireGuard server on srv-01
   - Configure WireGuard clients on all Hetzner VPS
   - Update monitoring configs to use WireGuard network
   - Estimated effort: 2-4 hours

3. **SSH Tunnel (temporary workaround):**
   - SSH port forward: `ssh -L 3100:localhost:3100 srv-01`
   - Performance overhead, not suitable for production
   - Can be used for temporary testing only

### 🟡 HIGH PRIORITY: Fix IP Address Mismatch

**Issue:** Prometheus configured to scrape wrong IP for test-1

**File:** `modules/nixos/monitoring.nix` line 129
**Current:** `targets = [ "10.0.0.20:9100" ];`
**Correct:** `targets = [ "10.0.0.4:9100" ];`

**Fix:**
```nix
{
  job_name = "test-1";
  static_configs = [{
    targets = [ "10.0.0.4:9100" ];  # Changed from 10.0.0.20
    labels = {
      environment = "dev";
      platform = "ubuntu";
      arch = "arm64";
      datacenter = "nbg1";
    };
  }];
}
```

**After fixing:** Rebuild srv-01 configuration:
```bash
sudo nixos-rebuild switch --flake .#srv-01
```

---

## Next Steps

### Immediate (This Task - I7.T3)

1. ✅ Document deployment results (this file)
2. ⏳ Fix IP address mismatch in monitoring.nix
3. ⏳ Deploy VPN solution (Tailscale recommended)
4. ⏳ Re-verify Prometheus targets after IP fix and VPN deployment
5. ⏳ Re-verify Promtail log shipping after VPN deployment
6. ⏳ Verify Grafana metrics and logs visibility

### Follow-up Tasks

1. **I7.T4:** Create Grafana dashboards (blocked until Prometheus/Loki connectivity verified)
2. **I7.T5:** Implement CI/CD pipeline (can proceed independently)
3. **I7.T6:** End-to-end testing of monitoring and CI/CD (blocked until I7.T3 fully complete)

---

## Configuration Files Created/Modified

### Created
- `ansible/playbooks/monitoring.yaml` - Monitoring agent deployment playbook

### Modified
- `ansible/inventory/group_vars/dev.yaml` - Added monitoring configuration variables:
  ```yaml
  # Monitoring configuration
  loki_url: "http://srv-01:3100"
  node_exporter_port: 9100
  promtail_port: 9080
  monitoring_enable_firewall: true
  ```

### Requires Modification
- `modules/nixos/monitoring.nix` - Fix test-1 IP address (10.0.0.20 → 10.0.0.4)

---

## Lessons Learned

1. **VPN is essential:** The monitoring plan correctly identified that VPN is required for srv-01 to communicate with Hetzner VPS. This should have been deployed BEFORE starting I7.T2 (monitoring stack deployment).

2. **IP address validation:** Inventory files are the source of truth for IP addresses. Cross-reference all hardcoded IPs in NixOS configs against Ansible inventory.

3. **Check-mode limitations:** Ansible check-mode cannot validate tasks that depend on previous tasks (e.g., download → extract). This is expected behavior but should be documented.

4. **Hostname resolution:** Using hostnames (srv-01) requires DNS or /etc/hosts entries. For monitoring, using IP addresses is more reliable.

---

## Recommendations

1. **Prioritize VPN deployment:** Before continuing with I7.T4 (dashboards), deploy Tailscale to all systems for reliable connectivity.

2. **Update Prometheus configs to use IPs:** Replace all hostname-based targets with IP addresses to avoid DNS dependencies:
   - xbook → local IP or Tailscale IP
   - xmsi → local IP or Tailscale IP
   - srv-01 → localhost (already correct)
   - mail-1, syncthing-1, test-1 → use private IPs (10.0.0.x)

3. **Create VPN deployment task:** Add a task between I7.T2 and I7.T3 in future iterations for VPN setup.

4. **Add connectivity pre-check:** Before deploying monitoring agents, verify network connectivity:
   ```bash
   ssh test-1 "curl -v --connect-timeout 5 http://srv-01:3100/ready"
   ```

---

## Conclusion

Task I7.T3 successfully deployed monitoring agents to test-1.dev.nbg using Ansible. The node_exporter agent is fully operational, but Promtail log shipping and Prometheus metric scraping are blocked by network connectivity issues.

**To complete this task:**
1. Fix the IP address mismatch in monitoring.nix (10.0.0.20 → 10.0.0.4)
2. Deploy VPN (Tailscale recommended) to connect srv-01 to Hetzner network
3. Re-verify Prometheus targets and Grafana after connectivity established

**Current status: DEPLOYABLE but NOT VERIFIED due to network blockers.**
