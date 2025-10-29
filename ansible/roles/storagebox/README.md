# Ansible Role: storagebox

Configure and mount Hetzner Storage Box via CIFS/SMB protocol. This role handles package installation, credential management, and persistent mounting of Hetzner Storage Boxes for backup and shared storage purposes.

## Requirements

- Ansible 2.12 or higher
- Target systems running Debian (11/12), Ubuntu (20.04/22.04/24.04), or RHEL-based (8/9)
- Root or sudo access on target systems
- Active Hetzner Storage Box account with credentials
- Network connectivity to Hetzner Storage Box servers
- `ansible.posix` collection installed (`ansible-galaxy collection install ansible.posix`)

## Role Variables

### Required Variables

These variables **must** be provided, typically through encrypted secrets (SOPS):

| Variable | Default | Description |
|----------|---------|-------------|
| `storagebox_username` | `""` (required) | Hetzner Storage Box username (e.g., u123456) |
| `storagebox_password` | `""` (required) | Hetzner Storage Box password |
| `storagebox_host` | `""` (required) | Storage Box hostname (e.g., u123456.your-storagebox.de) |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `storagebox_mount_point` | `/mnt/storagebox` | Local directory where Storage Box will be mounted |
| `storagebox_credentials_file` | `/root/.storagebox-credentials` | Path to store CIFS credentials file |
| `storagebox_uid` | `1000` | User ID for mounted files (determines file ownership) |
| `storagebox_gid` | `1000` | Group ID for mounted files (determines group ownership) |

## Dependencies

- **common** role - Provides base system configuration (automatically included)

The common role is applied first to ensure the target system has necessary packages and configuration before mounting the Storage Box.

## Example Playbook

### Basic Usage

```yaml
---
- hosts: backup_servers
  vars_files:
    - secrets/storagebox.yaml  # Contains encrypted credentials
  roles:
    - storagebox
```

### Advanced Usage with Custom Configuration

```yaml
---
- hosts: backup_servers
  vars_files:
    - secrets/storagebox.yaml
  roles:
    - role: storagebox
      vars:
        storagebox_mount_point: /backup/hetzner
        storagebox_uid: 1001
        storagebox_gid: 1001
```

### Using with SOPS Encrypted Secrets

**1. Create encrypted secrets file:**

```bash
# Create/edit encrypted secrets
sops secrets/storagebox.yaml
```

**Content of `secrets/storagebox.yaml`:**

```yaml
storagebox_username: u123456
storagebox_password: your-secure-password-here
storagebox_host: u123456.your-storagebox.de
```

**2. Run playbook with SOPS:**

```bash
# Load secrets as environment variables
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Run playbook
ansible-playbook playbooks/deploy.yaml --limit backup_servers
```

**3. Or use vars_files in playbook:**

```yaml
---
- hosts: backup_servers
  vars_files:
    - "{{ lookup('pipe', 'sops -d secrets/storagebox.yaml | yq -r') }}"
  roles:
    - storagebox
```

## What This Role Does

1. **Install CIFS utilities**: Installs `cifs-utils` package for CIFS/SMB mounting
2. **Create mount point**: Creates the target directory if it doesn't exist
3. **Manage credentials**: Deploys CIFS credentials file with secure permissions (0600)
4. **Mount Storage Box**: Configures and mounts the Storage Box with appropriate options
5. **Persist mount**: Adds entry to `/etc/fstab` for automatic mounting on boot

## Mount Options Explained

The role uses these CIFS mount options:

- `credentials=/root/.storagebox-credentials` - Path to credentials file
- `vers=3.0` - Use SMBv3.0 protocol (secure and modern)
- `file_mode=0777` - Files are world-readable/writable (adjust as needed)
- `dir_mode=0777` - Directories are world-readable/writable (adjust as needed)
- `uid=1000` - Files owned by UID 1000 (typically first user)
- `gid=1000` - Files owned by GID 1000 (typically first user group)

## Idempotency

This role is fully idempotent:

- Package installation checks if already installed
- Mount point creation is skipped if directory exists
- Credentials file is only updated if content changes
- Mount state is managed, not recreated if already mounted
- `/etc/fstab` entry is added once and maintained

## Security Considerations

### Credentials Protection

- Credentials file stored at `/root/.storagebox-credentials` with mode `0600`
- Only root user can read/write the credentials file
- **Never commit unencrypted credentials to version control**
- Use SOPS or Ansible Vault for encrypting secrets

### Recommended Secrets Management

```yaml
# Use SOPS with age encryption
sops secrets/storagebox.yaml

# Or use Ansible Vault
ansible-vault create secrets/storagebox.yaml
```

### Network Security

- Storage Box connection uses SMBv3.0 (encrypted protocol)
- Consider firewall rules to restrict Storage Box access
- Use Hetzner private network if available

## Troubleshooting

### Mount Fails with "Permission Denied"

Check credentials:
```bash
# Verify credentials file exists and has correct permissions
ls -la /root/.storagebox-credentials

# Test manual mount
mount -t cifs //u123456.your-storagebox.de/u123456 /mnt/test \
  -o credentials=/root/.storagebox-credentials,vers=3.0
```

### Mount Fails with "No Route to Host"

Check network connectivity:
```bash
# Test DNS resolution
host u123456.your-storagebox.de

# Test connectivity
ping u123456.your-storagebox.de

# Check firewall rules
iptables -L -n | grep 445
```

### Files Show Wrong Owner

Adjust UID/GID to match your user:
```bash
# Find your user's UID/GID
id username

# Update in group_vars
storagebox_uid: 1001
storagebox_gid: 1001
```

### Mount Point Shows as "Stale"

Unmount and remount:
```bash
umount /mnt/storagebox
systemctl daemon-reload
mount -a
```

## Testing

### Pre-deployment Testing

```bash
# Syntax check
ansible-playbook playbooks/deploy.yaml --syntax-check

# Dry run
ansible-playbook playbooks/deploy.yaml --limit backup_servers --check --diff

# Test connectivity
ansible backup_servers -m ping
```

### Post-deployment Verification

```bash
# Verify mount
ansible backup_servers -m shell -a "df -h | grep storagebox"

# Test write access
ansible backup_servers -m shell -a "touch /mnt/storagebox/test-file && rm /mnt/storagebox/test-file"

# Verify fstab entry
ansible backup_servers -m shell -a "grep storagebox /etc/fstab"
```

## Platform Support

Tested and supported on:

- **Debian**: 11 (Bullseye), 12 (Bookworm)
- **Ubuntu**: 20.04 (Focal), 22.04 (Jammy), 24.04 (Noble)
- **RHEL/Rocky/AlmaLinux**: 8, 9

## Directory Structure

```
storagebox/
├── defaults/
│   └── main.yaml           # Default variables
├── handlers/
│   └── main.yaml           # Service handlers (empty for now)
├── meta/
│   └── main.yaml           # Role metadata and dependencies
├── tasks/
│   └── main.yaml           # Main task list
├── templates/
│   └── credentials.j2      # CIFS credentials template
└── README.md               # This file
```

## Common Use Cases

### Backup Server

```yaml
- hosts: backup_servers
  vars_files:
    - secrets/storagebox.yaml
  roles:
    - role: storagebox
      vars:
        storagebox_mount_point: /backup/remote
        storagebox_uid: 0  # Root ownership for backup files
        storagebox_gid: 0
```

### Shared Storage for Web Servers

```yaml
- hosts: webservers
  vars_files:
    - secrets/storagebox.yaml
  roles:
    - role: storagebox
      vars:
        storagebox_mount_point: /var/www/shared
        storagebox_uid: 33  # www-data user
        storagebox_gid: 33
```

## Tags

This role supports the following tags:

- `storagebox` - Run all storagebox tasks
- `mount` - Only mount-related tasks
- `packages` - Only package installation

Usage:
```bash
ansible-playbook playbooks/deploy.yaml --tags storagebox
```

## Performance Considerations

- CIFS mounts have higher latency than local storage
- Use for backups and infrequent access, not high-performance applications
- Consider caching strategies for frequently accessed files
- Monitor network bandwidth when transferring large files

## License

MIT

## Author Information

This role was created by mi-skam for the homelab infrastructure project.

## Changelog

### Version 1.0.0 (2025-01-XX)
- Initial release with Galaxy structure
- Support for Debian, Ubuntu, and RHEL-based distributions
- SOPS integration for secrets management
- Comprehensive documentation and examples
