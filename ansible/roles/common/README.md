# Ansible Role: common

Base system configuration for all managed servers in the homelab infrastructure. This role provides foundational setup including system updates, directory structure, package installation, and shell configuration.

## Requirements

- Ansible 2.12 or higher
- Target systems running Debian (11/12), Ubuntu (20.04/22.04/24.04), or RHEL-based (8/9)
- Root or sudo access on target systems

## Role Variables

All variables have sensible defaults and can be overridden in `group_vars`, `host_vars`, or playbook variables.

### Package Management

| Variable | Default | Description |
|----------|---------|-------------|
| `common_packages` | `[vim, htop, curl, wget, git, tmux, jq]` | List of essential packages to install on all servers |
| `common_additional_packages` | `[]` | Additional packages to install (useful for host-specific additions) |
| `common_update_cache` | `true` | Whether to update package cache before installing |
| `common_upgrade_packages` | `false` | Whether to upgrade all installed packages |
| `common_upgrade_dist` | `false` | Whether to perform distribution upgrade (use with caution) |

### Filesystem Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `common_scripts_dir` | `/opt/scripts` | Directory for custom scripts shared across systems |
| `common_log_dir` | `/var/log/homelab` | Central logging directory for homelab services |
| `common_directory_mode` | `0755` | Default permissions for created directories |

### Bash Aliases Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `bash_aliases_path` | `/root/.bash_aliases` | Path to bash aliases file |
| `bash_aliases_owner` | `root` | Owner of the aliases file |
| `bash_aliases_group` | `root` | Group of the aliases file |
| `bash_aliases_mode` | `0644` | Permissions for the aliases file |
| `custom_bash_aliases` | `[]` | List of custom aliases (see example below) |

## Dependencies

None. This is the foundational role that other roles depend on.

## Example Playbook

### Basic Usage

```yaml
---
- hosts: all
  roles:
    - common
```

### Advanced Usage with Custom Variables

```yaml
---
- hosts: webservers
  roles:
    - role: common
      vars:
        common_additional_packages:
          - nginx
          - certbot
        common_scripts_dir: /opt/homelab/scripts
        custom_bash_aliases:
          - name: deploy
            command: /opt/scripts/deploy.sh
          - name: logs-nginx
            command: tail -f /var/log/nginx/access.log
```

### Integration with Group Variables

In `group_vars/all.yaml`:

```yaml
---
common_packages:
  - vim
  - htop
  - curl
  - wget
  - git
  - tmux
  - jq
  - net-tools

common_log_dir: /var/log/homelab

custom_bash_aliases:
  - name: myip
    command: curl -s ifconfig.me
  - name: ports
    command: netstat -tulanp
```

## Built-in Bash Aliases

The role installs the following default aliases for all systems:

- `ll` - List files with details (`ls -lah`)
- `disk` - Show disk usage (`df -h`)
- `logs` - Tail all logs in the homelab log directory
- `ports` - Show network ports (`netstat -tulanp`)
- `meminfo` - Display memory information
- `psmem` - Show processes sorted by memory usage
- `pscpu` - Show processes sorted by CPU usage

### OS-Specific Aliases

**Debian/Ubuntu:**
- `update-system` - Update and upgrade packages (`apt update && apt upgrade -y`)
- `search-package` - Search for packages (`apt search`)

**RHEL/Rocky/AlmaLinux:**
- `update-system` - Update packages (`dnf update -y`)
- `search-package` - Search for packages (`dnf search`)

## Custom Aliases

You can add custom aliases using the `custom_bash_aliases` variable:

```yaml
custom_bash_aliases:
  - name: deploy
    command: /opt/scripts/deploy.sh
  - name: backup
    command: rsync -avz /data /mnt/backup/
  - name: docker-clean
    command: docker system prune -af
```

## Idempotency

This role is fully idempotent and can be run multiple times safely:

- Package installation uses state `present` (won't reinstall if already installed)
- Directory creation checks for existence before creating
- Bash aliases are templated, so only updated if content changes
- System updates are conditional based on variables

## Platform Support

The role automatically detects the OS family and applies appropriate package management:

- **Debian/Ubuntu**: Uses `apt` module
- **RHEL/Rocky/AlmaLinux**: Uses `dnf` module

## Directory Structure

```
common/
├── defaults/
│   └── main.yaml       # Default variables
├── handlers/
│   └── main.yaml       # Service handlers (empty for now)
├── meta/
│   └── main.yaml       # Role metadata and dependencies
├── tasks/
│   └── main.yaml       # Main task list
├── templates/
│   └── bash_aliases.j2 # Bash aliases template
└── README.md           # This file
```

## Testing

Test the role in check mode before applying:

```bash
# Syntax check
ansible-playbook playbooks/deploy.yaml --syntax-check

# Dry run (check mode)
ansible-playbook playbooks/deploy.yaml --check --diff

# Apply to test environment only
ansible-playbook playbooks/deploy.yaml --limit test-1.dev.nbg
```

## Troubleshooting

### Package Installation Fails

If package installation fails, check:
- Network connectivity on target system
- Package repository configuration
- Package name spelling (may differ between Debian/RHEL)

### Bash Aliases Not Loading

Ensure your shell sources the aliases file. Add to `/root/.bashrc`:

```bash
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
```

Most distributions include this by default.

### Permission Issues

If you encounter permission errors:
- Verify the role runs with root privileges
- Check `bash_aliases_owner` and `bash_aliases_group` match the target user
- Ensure `common_directory_mode` provides appropriate access

## Security Considerations

- System updates are opt-in via `common_upgrade_packages` to prevent unexpected changes
- Distribution upgrades are disabled by default for stability
- All created directories use restrictive `0755` permissions by default
- Bash aliases file is world-readable but only writable by owner

## License

MIT

## Author Information

This role was created by mi-skam for the homelab infrastructure project.

## Changelog

### Version 1.0.0 (2025-01-XX)
- Initial release with Galaxy structure
- Extracted hardcoded values to variables
- Added Jinja2 template for bash aliases
- Support for Debian, Ubuntu, and RHEL-based distributions
