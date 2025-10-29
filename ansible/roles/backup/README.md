# Ansible Role: backup

Configure automated restic backups to Hetzner Storage Box with systemd timers and retention policies.

## Description

This role deploys a complete backup solution using restic, a fast and secure backup program with built-in deduplication and encryption. It configures:

- restic installation via package manager
- Automated daily backups via systemd timer
- Configurable retention policies (daily/weekly/monthly/yearly)
- Repository initialization and validation
- Backup script with pre/post hooks
- Integration with Hetzner Storage Box or other backends

Backups are encrypted at rest and deduplicated for efficient storage usage.

## Requirements

- Ansible 2.12 or higher
- Supported platforms: Debian 11+, Ubuntu 20.04+, RHEL/Rocky 8+
- systemd-based system
- Sufficient storage space in backup repository
- Network connectivity to backup destination
- Root privileges for system-wide backups

## Role Variables

### restic Installation

| Variable | Default | Description |
|----------|---------|-------------|
| `restic_install_method` | `package` | Installation method (package or binary) |
| `restic_version` | `latest` | restic version (latest or specific version) |

### Repository Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `restic_repository_type` | `sftp` | Backend type (sftp, s3, rest, local, etc.) |
| `restic_repository_path` | `{{ storagebox_mount_point }}/restic-repo` | Repository location |
| `restic_repository_password` | `""` | **REQUIRED** - Repository encryption password |

### Backup Schedule

| Variable | Default | Description |
|----------|---------|-------------|
| `backup_schedule_time` | `"02:00"` | Daily backup time (HH:MM format) |
| `backup_schedule_randomized_delay` | `"1h"` | Random delay for systemd timer |

### Retention Policy

| Variable | Default | Description |
|----------|---------|-------------|
| `backup_retention_daily` | `7` | Number of daily backups to keep |
| `backup_retention_weekly` | `4` | Number of weekly backups to keep |
| `backup_retention_monthly` | `12` | Number of monthly backups to keep |
| `backup_retention_yearly` | `2` | Number of yearly backups to keep |

### Backup Paths and Exclusions

| Variable | Default | Description |
|----------|---------|-------------|
| `backup_paths` | `[]` | **REQUIRED** - List of paths to backup |
| `backup_exclude_patterns` | See below | Patterns to exclude from backup |

Default exclusions:
```yaml
backup_exclude_patterns:
  - "*.tmp"
  - "*.cache"
  - "/tmp/*"
  - "/var/tmp/*"
```

### Script and Service Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `backup_script_path` | `/usr/local/bin/restic_backup.sh` | Path to backup script |
| `backup_service_name` | `restic-backup` | Systemd service name |
| `backup_timer_name` | `restic-backup.timer` | Systemd timer name |

### Optional Hooks

| Variable | Default | Description |
|----------|---------|-------------|
| `backup_pre_hook` | `""` | Shell commands to run before backup |
| `backup_post_hook` | `""` | Shell commands to run after backup |

### Notifications (Future Enhancement)

| Variable | Default | Description |
|----------|---------|-------------|
| `backup_enable_notifications` | `false` | Enable email notifications (not implemented) |
| `backup_notification_email` | `""` | Email address for notifications |

## Dependencies

- `common` role (provides base system configuration)

## Example Playbook

### Basic Usage

```yaml
- hosts: backup_servers
  roles:
    - role: backup
      vars:
        restic_repository_password: "{{ vault_restic_password }}"
        backup_paths:
          - /etc
          - /home
          - /var/www
```

### Mail Server Backup

```yaml
- hosts: mail_servers
  roles:
    - role: common
    - role: storagebox
    - role: backup
      vars:
        restic_repository_password: "{{ vault_restic_password }}"
        backup_paths:
          - /etc/postfix
          - /etc/dovecot
          - /var/mail
          - /var/vmail
        backup_exclude_patterns:
          - "*.tmp"
          - "*.cache"
          - "/var/mail/*/Trash/*"
        backup_schedule_time: "03:00"
        backup_retention_daily: 14
        backup_retention_weekly: 8
        backup_retention_monthly: 24
```

### Production Setup with Hooks

```yaml
- hosts: prod_servers
  roles:
    - role: backup
      vars:
        restic_repository_password: "{{ vault_restic_password }}"
        backup_paths:
          - /opt/applications
          - /var/lib/postgresql
        backup_pre_hook: |
          # Dump PostgreSQL databases before backup
          pg_dumpall -U postgres > /opt/backups/postgres_dump.sql
        backup_post_hook: |
          # Cleanup old dumps after backup
          find /opt/backups -name "postgres_dump.sql" -mtime +1 -delete
        backup_schedule_time: "01:00"
```

## Idempotency

This role is fully idempotent. Running it multiple times will not change the system state after the initial deployment, unless configuration variables are modified.

**Important notes:**
- Repository initialization only runs if repository doesn't exist
- Backup script and systemd units are updated when templates change
- Timer remains enabled across runs

**Testing idempotency:**
```bash
# First run - should make changes
ansible-playbook playbooks/deploy.yaml --limit test-server

# Second run - should show changed=0
ansible-playbook playbooks/deploy.yaml --limit test-server
```

## Tags

The following tags are available for selective execution:

- `backup` - All backup tasks
- `install` - Installation tasks only
- `configure` - Configuration tasks only
- `validate` - Validation tasks only
- `test` - Test tasks only

**Examples:**
```bash
# Install restic only
ansible-playbook playbooks/deploy.yaml --tags "backup,install"

# Update backup configuration only
ansible-playbook playbooks/deploy.yaml --tags "backup,configure"

# Test backup setup
ansible-playbook playbooks/deploy.yaml --tags "backup,test"
```

## Security Considerations

**CRITICAL SECURITY NOTES:**

1. **Password Management**: The `restic_repository_password` variable contains the encryption key for your backups. This MUST be:
   - Stored in ansible-vault encrypted files
   - Never committed to version control in plain text
   - Backed up separately (losing this password means permanent data loss)

2. **Script Security**:
   - Backup script runs as root to access all files
   - Script is created with mode 0750 (owner read/write/execute only)
   - Environment variables contain sensitive passwords (cleared after execution)

3. **Storage Security**:
   - Backups are encrypted at rest with AES-256
   - Repository password never stored on disk (only in memory during backup)
   - Consider TLS for SFTP/REST backends

4. **Access Control**:
   - Only root can execute backup script
   - Log files are world-readable by default (no sensitive data logged)

**Example vault usage:**
```yaml
# group_vars/prod/vault.yaml (encrypted with ansible-vault)
vault_restic_password: "very-secure-random-password-min-32-chars"
```

```bash
# Encrypt the file
ansible-vault encrypt group_vars/prod/vault.yaml

# Edit encrypted file
ansible-vault edit group_vars/prod/vault.yaml
```

## Service Management

Backups are scheduled via systemd timer:

```bash
# Check timer status
systemctl status restic-backup.timer
systemctl list-timers restic-backup.timer

# Check service status
systemctl status restic-backup.service

# View recent backup logs
journalctl -u restic-backup.service -n 50

# Manual backup (for testing)
systemctl start restic-backup.service

# Disable automatic backups
systemctl stop restic-backup.timer
systemctl disable restic-backup.timer
```

## Manual Backup Operations

After deployment, you can perform manual restic operations:

```bash
# List snapshots
export RESTIC_REPOSITORY="/mnt/storagebox/restic-repo"
export RESTIC_PASSWORD="your-password"
restic snapshots

# Restore files
restic restore latest --target /tmp/restore --include /etc/nginx

# Check repository integrity
restic check

# Show repository statistics
restic stats

# Manually prune old snapshots
restic forget --keep-daily 7 --keep-weekly 4 --prune
```

## Backup Verification

The role includes automatic verification:

1. **Repository test**: Runs `restic snapshots` to verify repository access
2. **Weekly integrity check**: Automatically runs `restic check` every Sunday
3. **Retention policy**: Applied after each backup to prune old snapshots

**Manual verification:**
```bash
# SSH to the server
ssh user@server

# Check last backup time
systemctl status restic-backup.service

# View backup logs
tail -n 100 /var/log/restic-backup.log

# Verify latest snapshot
export RESTIC_REPOSITORY="/mnt/storagebox/restic-repo"
export RESTIC_PASSWORD="your-password"
restic snapshots --latest 1
```

## Troubleshooting

### Repository initialization fails

```bash
# Check if repository path exists and is writable
ls -la /mnt/storagebox/restic-repo

# Manually initialize repository
export RESTIC_REPOSITORY="/mnt/storagebox/restic-repo"
export RESTIC_PASSWORD="your-password"
restic init
```

### Backup fails with permission errors

```bash
# Ensure script is executable
chmod 750 /usr/local/bin/restic_backup.sh

# Check backup paths exist
for path in /etc /home; do
  ls -ld "$path"
done

# Review backup logs
journalctl -u restic-backup.service -xe
```

### Timer not running

```bash
# Check timer status
systemctl status restic-backup.timer

# Enable timer if disabled
systemctl enable --now restic-backup.timer

# Verify timer schedule
systemctl list-timers restic-backup.timer
```

### Repository too large

```bash
# Check repository statistics
restic stats --mode restore-size

# Manually prune old snapshots
restic forget --keep-daily 7 --prune

# Check for large files
restic stats --mode files-by-contents
```

### Password errors

```bash
# Verify password is correct
echo "$RESTIC_PASSWORD" | wc -c  # Should be >8 characters

# Check if repository is accessible
restic --repo /mnt/storagebox/restic-repo snapshots

# If password is lost, repository is unrecoverable
# Always backup your restic password separately!
```

## Backup Strategy Best Practices

1. **3-2-1 Rule**:
   - 3 copies of data (original + 2 backups)
   - 2 different storage types
   - 1 offsite copy

2. **Test Restores**:
   - Regularly test backup restoration
   - Verify backup integrity monthly
   - Document restore procedures

3. **Monitor Backup Jobs**:
   - Check backup logs regularly
   - Set up alerts for failed backups
   - Monitor repository size growth

4. **Retention Tuning**:
   - Adjust retention based on recovery requirements
   - Balance storage costs vs. recovery point objectives
   - Consider compliance requirements

## Integration with Storage Box

This role is designed to work with the `storagebox` role for Hetzner Storage Box integration:

1. Deploy `storagebox` role first to mount storage
2. Deploy `backup` role to configure backups
3. Backup repository is created at `{{ storagebox_mount_point }}/restic-repo`

The roles are loosely coupled - you can use different storage backends by overriding `restic_repository_path`.

## Performance Considerations

- **Initial backup**: Takes longer due to full file scan and upload
- **Incremental backups**: Only changed data is backed up (deduplication)
- **CPU usage**: restic uses compression and encryption (CPU-intensive)
- **Network usage**: Backups transfer data to remote repository
- **I/O usage**: Reading all files to be backed up

**Optimization tips:**
- Schedule backups during low-activity periods
- Exclude large temporary or cache directories
- Use systemd timer's `AccuracySec` to randomize start time
- Monitor backup duration and adjust timeout if needed

## License

MIT

## Author Information

This role was created by mi-skam as part of the homelab infrastructure project.

For issues or contributions, please visit the project repository.
