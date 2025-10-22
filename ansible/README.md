# Ansible Configuration Management

This directory contains Ansible playbooks and roles for managing Hetzner VPS infrastructure.

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   ├── hosts.yaml           # Main inventory (generated from Terraform)
│   └── group_vars/          # Variables for host groups
├── playbooks/
│   ├── bootstrap.yaml       # Initial server setup
│   └── deploy.yaml          # Main deployment playbook
└── roles/
    ├── common/              # Base configuration for all servers
    └── monitoring/          # (Optional) Monitoring setup
```

## Quick Start

### 1. Update inventory from Terraform
```bash
just ansible-inventory-update
```

### 2. Test connectivity
```bash
ansible all -m ping
```

### 3. Bootstrap new servers
```bash
ansible-playbook playbooks/bootstrap.yaml
```

### 4. Deploy configurations
```bash
ansible-playbook playbooks/deploy.yaml
```

## Common Commands

```bash
# Run on specific environment
ansible-playbook playbooks/deploy.yaml --limit prod
ansible-playbook playbooks/deploy.yaml --limit dev

# Run on specific host
ansible-playbook playbooks/deploy.yaml --limit mail-1.prod.nbg

# Check what would change (dry run)
ansible-playbook playbooks/deploy.yaml --check --diff

# List all hosts
ansible all --list-hosts

# Get facts from servers
ansible all -m setup
```

## Adding New Playbooks

Create playbooks in `playbooks/` directory:

```yaml
---
- name: Your playbook name
  hosts: all  # or specific group
  become: true

  tasks:
    - name: Your task
      # ... task definition
```

## Adding New Roles

Create role structure:

```bash
mkdir -p roles/your-role/{tasks,handlers,templates,files,vars,defaults}
touch roles/your-role/tasks/main.yaml
```

Then include in `playbooks/deploy.yaml`:

```yaml
roles:
  - common
  - your-role
```
