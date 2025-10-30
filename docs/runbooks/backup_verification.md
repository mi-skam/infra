# Backup Verification Runbook

This runbook provides procedures for verifying, testing, and restoring backups from the restic-based backup system deployed on production mail servers.

## Overview

- **Backup System**: Restic with Hetzner Storage Box backend
- **Schedule**: Daily at 02:00 UTC (with 30-minute randomized delay)
- **Retention Policy**: 7 daily, 4 weekly, 12 monthly snapshots
- **Storage Location**: `/mnt/storagebox/restic-mail-backups`
- **Backed Up Paths**:
  - `/var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data` (mail data)
  - `/var/lib/docker/volumes/mailcowdockerized_mysql-vol-1/_data` (database)
  - `/opt/mailcow-dockerized/data` (mailcow configuration)

## Prerequisites

Before performing backup verification operations, ensure:

1. SSH access to the mail server (mail-1.prod.nbg)
2. Root privileges or sudo access
3. Storage Box is mounted at `/mnt/storagebox`
4. Restic repository password (stored in secrets/backup.yaml)

## Setting Up Environment

On the mail server, set the restic password environment variable:

```bash
# Load restic password from systemd environment file
export RESTIC_PASSWORD=$(grep RESTIC_PASSWORD /etc/restic/backup.env | cut -d= -f2)

# Or manually set it (get password from secrets/backup.yaml)
export RESTIC_PASSWORD="your-restic-password-here"

# Set repository path
export RESTIC_REPOSITORY="/mnt/storagebox/restic-mail-backups"
```

## Immediate Verification After Backup Creation

**Always verify snapshot immediately after backup completes** (before connection is lost):

```bash
# Set restic environment
export RESTIC_REPOSITORY="/mnt/storagebox/restic-dev-backups"
export RESTIC_PASSWORD="..." # From /usr/local/bin/restic_backup.sh

# Verify latest snapshot was created
restic snapshots --last 1

# Check snapshot details
restic stats latest

# List files in latest snapshot (verify expected files are present)
restic ls latest | head -20

# Expected output: snapshot ID, timestamp, file count, total size
```

**Rationale**: Previous test (DRT-2025-10-30-003) created backup successfully but experienced SSH timeout before verification. Immediate verification captures snapshot details while connection is stable.

**What to verify**:
- ✅ Snapshot ID generated (confirms backup completed)
- ✅ Timestamp matches current time (confirms backup is recent, not stale)
- ✅ File count matches expected (e.g., 3 files for test data: hostname, hosts, syslog)
- ✅ Total size is reasonable (not 0 bytes - would indicate backup failure)
- ✅ File paths are correct (backed up intended directories)

---

## Verification Procedures

### 1. List All Backup Snapshots

List all available backup snapshots with timestamps:

```bash
restic --repo /mnt/storagebox/restic-mail-backups snapshots
```

**Expected output:**
```
repository 3f5c8d4b opened successfully, password is correct
ID        Time                 Host             Tags        Paths
--------------------------------------------------------------------------------
a1b2c3d4  2025-10-30 02:15:23  mail-1.prod.nbg              /var/lib/docker/volumes/...
e5f6g7h8  2025-10-29 02:12:45  mail-1.prod.nbg              /var/lib/docker/volumes/...
...
```

### 2. Verify Backup Integrity

Check repository integrity and verify all snapshot data:

```bash
# Quick check (only repository structure)
restic --repo /mnt/storagebox/restic-mail-backups check

# Full check (verify all data)
restic --repo /mnt/storagebox/restic-mail-backups check --read-data

# Check specific snapshot
restic --repo /mnt/storagebox/restic-mail-backups check --read-data <snapshot-id>
```

**Expected output:**
```
repository 3f5c8d4b opened successfully, password is correct
created new cache in /root/.cache/restic
create exclusive lock for repository
load indexes
check all packs
check snapshots, trees and blobs
no errors were found
```

### 3. List Files in a Snapshot

Browse the contents of a specific snapshot:

```bash
# List all files in the latest snapshot
restic --repo /mnt/storagebox/restic-mail-backups ls latest

# List files in a specific snapshot
restic --repo /mnt/storagebox/restic-mail-backups ls <snapshot-id>

# List only mail data files
restic --repo /mnt/storagebox/restic-mail-backups ls latest | grep vmail

# Search for specific file
restic --repo /mnt/storagebox/restic-mail-backups find mailcow.conf
```

### 4. Check Backup Statistics

View detailed statistics about backup snapshots:

```bash
# Show repository statistics
restic --repo /mnt/storagebox/restic-mail-backups stats

# Show statistics for specific snapshot
restic --repo /mnt/storagebox/restic-mail-backups stats <snapshot-id>

# Show statistics by file
restic --repo /mnt/storagebox/restic-mail-backups stats --mode files-by-contents
```

## Restoration Procedures

### 1. Restore a Test File (Verification)

Restore a single file to verify backup integrity without affecting production:

```bash
# Create restore test directory
mkdir -p /tmp/restore-test

# Restore a specific file from latest snapshot
restic --repo /mnt/storagebox/restic-mail-backups restore latest \
  --target /tmp/restore-test \
  --include /opt/mailcow-dockerized/data/conf/dovecot/dovecot.conf

# Verify the restored file
ls -lh /tmp/restore-test/opt/mailcow-dockerized/data/conf/dovecot/dovecot.conf
cat /tmp/restore-test/opt/mailcow-dockerized/data/conf/dovecot/dovecot.conf

# Clean up after verification
rm -rf /tmp/restore-test
```

### 2. Restore Entire Mail Directory (Production Recovery)

**WARNING**: This procedure stops mail services and replaces production data. Only use during actual disaster recovery.

```bash
# Stop mailcow services
cd /opt/mailcow-dockerized
docker-compose down

# Backup current state (if any data remains)
mv /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data \
   /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data.backup-$(date +%Y%m%d-%H%M%S)

# Restore from latest snapshot
restic --repo /mnt/storagebox/restic-mail-backups restore latest \
  --target / \
  --include /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data

# Or restore from specific snapshot
restic --repo /mnt/storagebox/restic-mail-backups restore <snapshot-id> \
  --target / \
  --include /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data

# Verify restored data
ls -lh /var/lib/docker/volumes/mailcowdockerized_vmail-vol-1/_data

# Restart mailcow services
cd /opt/mailcow-dockerized
docker-compose up -d

# Monitor service startup
docker-compose ps
docker-compose logs -f
```

### 3. Restore MySQL Database

```bash
# Stop mailcow services
cd /opt/mailcow-dockerized
docker-compose down

# Backup current database (if any)
mv /var/lib/docker/volumes/mailcowdockerized_mysql-vol-1/_data \
   /var/lib/docker/volumes/mailcowdockerized_mysql-vol-1/_data.backup-$(date +%Y%m%d-%H%M%S)

# Restore database from backup
restic --repo /mnt/storagebox/restic-mail-backups restore latest \
  --target / \
  --include /var/lib/docker/volumes/mailcowdockerized_mysql-vol-1/_data

# Restart mailcow services
cd /opt/mailcow-dockerized
docker-compose up -d

# Verify database integrity
docker-compose exec mysql-mailcow mysql -u root -p$(grep DBROOT /opt/mailcow-dockerized/mailcow.conf | cut -d= -f2) -e "SHOW DATABASES;"
```

### 4. Point-in-Time Recovery

Restore data from a specific date/time:

```bash
# List snapshots to find the desired date
restic --repo /mnt/storagebox/restic-mail-backups snapshots

# Restore from specific timestamp
restic --repo /mnt/storagebox/restic-mail-backups restore <snapshot-id> \
  --target /tmp/recovery-$(date +%Y%m%d-%H%M%S)

# Review recovered data before moving to production
ls -lR /tmp/recovery-*/
```

## Monitoring and Maintenance

### Check Backup Timer Status

```bash
# Check systemd timer status
systemctl status restic-backup.timer

# View next scheduled run
systemctl list-timers restic-backup.timer

# Check recent backup logs
journalctl -u restic-backup.service -n 50

# View full backup log
tail -f /var/log/restic-backup.log
```

### Manual Backup Execution

```bash
# Trigger backup manually (useful for testing)
systemctl start restic-backup.service

# Watch backup progress
journalctl -u restic-backup.service -f

# Or run backup script directly
/usr/local/bin/restic_backup.sh
```

### Verify Backup Automation

```bash
# Check that backup timer is enabled
systemctl is-enabled restic-backup.timer

# Check last successful backup time
restic --repo /mnt/storagebox/restic-mail-backups snapshots | tail -n 5
```

## Testing Schedule

Perform the following backup verification tests on a regular schedule:

### Weekly Tests (Every Monday)
- [ ] List backup snapshots and verify daily backups are occurring
- [ ] Check backup timer status and logs
- [ ] Verify retention policy is being applied (check snapshot count)

### Monthly Tests (First Monday of Month)
- [ ] Run repository integrity check (`restic check`)
- [ ] Restore a test file and verify contents
- [ ] Review backup statistics and storage usage

### Quarterly Tests (Every 3 Months)
- [ ] Perform full test restore to test-1.dev.nbg
- [ ] Verify restored mail data is accessible
- [ ] Document any issues and update procedures

## Troubleshooting

### Backup Fails with "Permission Denied"

```bash
# Check storage box mount
mount | grep storagebox
ls -la /mnt/storagebox

# Remount if needed
systemctl restart mnt-storagebox.mount
```

### Backup Fails with "Repository Not Found"

```bash
# Verify repository path
ls -la /mnt/storagebox/restic-mail-backups

# Re-initialize repository if needed (CAUTION: only if repository is truly missing)
restic --repo /mnt/storagebox/restic-mail-backups init
```

### Restore Takes Too Long

```bash
# Use --verify=false to skip verification during restore
restic --repo /mnt/storagebox/restic-mail-backups restore latest \
  --target /tmp/restore \
  --verify=false

# Or restore only specific subdirectories
restic --repo /mnt/storagebox/restic-mail-backups restore latest \
  --target /tmp/restore \
  --include /path/to/specific/directory
```

### Out of Storage Space

```bash
# Check Storage Box usage
df -h /mnt/storagebox

# Manually prune old snapshots (use with caution)
restic --repo /mnt/storagebox/restic-mail-backups forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --prune
```

## Recovery Time Objectives

Based on testing and data volumes:

- **RPO (Recovery Point Objective)**: 1 hour (data loss tolerance)
  - Daily backups at 02:00 UTC
  - Maximum data loss: 24 hours (time since last backup)

- **RTO (Recovery Time Objective)**: 4 hours (recovery time)
  - Restore time: ~30-60 minutes (depending on data size)
  - Service verification: ~30 minutes
  - DNS propagation: ~2-3 hours (if IP changes)

## Emergency Contacts

- **Infrastructure Owner**: Maxime (plumps)
- **Hetzner Support**: https://console.hetzner.cloud/support
- **Storage Box Documentation**: https://docs.hetzner.com/robot/storage-box/

## References

- Restic documentation: https://restic.readthedocs.io/
- Backup role source: `ansible/roles/backup/`
- Backup playbook: `ansible/playbooks/backup.yaml`
- Encrypted secrets: `secrets/backup.yaml`
