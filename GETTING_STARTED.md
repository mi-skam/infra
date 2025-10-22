# Getting Started with Infrastructure Management

This guide will help you set up and manage your infrastructure using OpenTofu and Ansible.

## Prerequisites

- Nix with flakes enabled
- Hetzner Cloud account and API token
- Age key for SOPS encryption (see CLAUDE.md)

## Initial Setup

### 1. Enter Development Shell

```bash
# Clone the repository (if you haven't already)
cd infra

# Allow direnv (first time only)
direnv allow

# The dev shell will activate automatically
# Or manually: nix develop
```

You should see a welcome message with all available tools.

### 2. Configure Hetzner API Token

Get your API token from Hetzner Cloud Console:
1. Go to https://console.hetzner.cloud/projects
2. Select your project
3. Go to Security → API Tokens
4. Create a new token with Read & Write permissions

Then encrypt it with SOPS:

```bash
# Edit the encrypted secrets file
sops secrets/hetzner.yaml

# Replace the placeholder:
hcloud_token: your_actual_token_here

# Save and exit (Ctrl+O, Enter, Ctrl+X in nano)
```

Verify it's encrypted:
```bash
cat secrets/hetzner.yaml  # Should show encrypted content
sops -d secrets/hetzner.yaml  # Should show decrypted token
```

### 3. Initialize OpenTofu

```bash
# Initialize terraform providers
just tf-init
```

### 4. Import Existing Infrastructure

If you have existing Hetzner resources (first-time setup):

```bash
# This will import your 3 servers and network
just tf-import
```

Verify the import:
```bash
# Should show "No changes" if successful
just tf-plan
```

### 5. Verify Infrastructure

```bash
# View all managed resources
just tf-output

# Check with hcloud CLI
hcloud server list
hcloud network list
```

## Basic Workflows

### Managing Infrastructure (OpenTofu)

```bash
# View current state
just tf-output

# Preview changes before applying
just tf-plan

# Apply infrastructure changes
just tf-apply

# View specific output (direct tofu)
cd terraform && tofu output mail_server
```

### Managing Server Configuration (Ansible)

```bash
# Test connectivity to all servers
just ansible-ping

# Bootstrap new servers (first-time setup)
just ansible-bootstrap

# Deploy configurations to all servers
just ansible-deploy

# Deploy only to production
just ansible-deploy-env prod

# Deploy only to development
just ansible-deploy-env dev
```

### Managing NixOS/Darwin Hosts

```bash
# NixOS
sudo nixos-rebuild switch --flake .#xmsi

# Darwin
darwin-rebuild switch --flake .#xbook

# Home Manager
home-manager switch --flake .#mi-skam@xmsi
home-manager switch --flake .#plumps@xbook

# Update flake inputs
nix flake update
```

## Common Tasks

### Adding a New Server

1. **Define infrastructure in OpenTofu:**

Edit `terraform/servers.tf`:
```hcl
resource "hcloud_server" "mynew_server" {
  name        = "mynew-1.prod.nbg"
  server_type = "cax11"
  image       = "debian-12"
  location    = "nbg1"
  ssh_keys    = [data.hcloud_ssh_key.homelab.id]

  network {
    network_id = hcloud_network.homelab.id
    ip         = "10.0.0.5"
  }

  labels = {
    environment = "prod"
    role        = "mynew"
  }
}
```

2. **Apply the changes:**
```bash
just tf-plan   # Review changes
just tf-apply  # Create the server
```

3. **Update Ansible inventory:**
```bash
just ansible-inventory-update
```

4. **Bootstrap the new server:**
```bash
cd ansible
ansible-playbook playbooks/bootstrap.yaml --limit mynew-1.prod.nbg
```

### Modifying Server Configuration

1. **Edit Ansible playbooks/roles:**
- `ansible/playbooks/` - Main playbooks
- `ansible/roles/common/` - Shared configuration
- `ansible/inventory/group_vars/` - Environment variables

2. **Test changes (dry run):**
```bash
cd ansible
ansible-playbook playbooks/deploy.yaml --check --diff
```

3. **Apply changes:**
```bash
just ansible-deploy
```

### Updating Infrastructure

```bash
# Upgrade server type
# Edit terraform/servers.tf, change server_type
just tf-plan   # Review changes (server will be stopped/resized)
just tf-apply

# Add firewall rules
# Create terraform/firewall.tf with firewall rules
just tf-plan
just tf-apply
```

## Troubleshooting

### Can't connect to servers with Ansible

Check SSH connectivity:
```bash
# Test direct connection
ssh root@10.0.0.3  # mail server private IP

# Verify inventory
cd ansible
ansible-inventory --list

# Ping specific host
ansible mail-1.prod.nbg -m ping
```

### OpenTofu shows unexpected changes

```bash
# View detailed diff
cd terraform
tofu plan -out=plan.out
tofu show plan.out

# If changes look wrong, check state
tofu state list
tofu state show hcloud_server.mail_prod_nbg
```

### Secrets not decrypting

```bash
# Verify age key is present
ls -la ~/.config/sops/age/keys.txt

# Test SOPS manually
sops -d secrets/hetzner.yaml

# Re-encrypt if needed
sops secrets/hetzner.yaml
```

### Dev shell not loading tools

```bash
# Rebuild dev shell
nix develop

# Or force rebuild
direnv reload
```

## Advanced Tasks

### Setting Up Hetzner Storage Box Backups

The infrastructure includes automated backup to Hetzner Storage Box for the mail server.

1. **Configure Storage Box credentials:**
```bash
# Edit encrypted secrets
sops secrets/storagebox.yaml

# Add your Storage Box details:
storagebox:
  username: u123456
  password: your_password
  host: u123456.your-storagebox.de
  mount_point: /mnt/storagebox
```

2. **Deploy Storage Box mounting:**
```bash
# Setup Storage Box on all servers
just ansible-deploy setup-storagebox

# Or target specific environment
cd ansible
ansible-playbook playbooks/setup-storagebox.yaml --limit prod
```

3. **Setup Mailcow automated backups:**
```bash
# Deploy mailcow backup configuration (runs backup + creates cron job)
just ansible-deploy mailcow-backup

# Manual backup test
cd ansible
ansible mail -m shell -a "cd /opt/mailcow-dockerized && MAILCOW_BACKUP_LOCATION=/mnt/storagebox/mailcow ./helper-scripts/backup_and_restore.sh backup all"

# Check backup logs
ansible mail -m shell -a "tail -50 /var/log/mailcow-backup.log"

# Verify cron job
ansible mail -m shell -a "crontab -l | grep mailcow"
```

The backup runs automatically every night at 2:00 AM and includes:
- Full mailcow backup to Storage Box
- Mailcow update with garbage collection
- Logging to `/var/log/mailcow-backup.log`

## Next Steps

1. **Customize Ansible roles** - Add your own configurations in `ansible/roles/`
2. **Add monitoring** - Uncomment monitoring role in `ansible/playbooks/deploy.yaml`
3. **Test backup restoration** - Verify backups can be restored successfully
4. **Configure services** - Add Docker containers, web services, etc.
5. **Remote state** - Consider using remote backend for Terraform state

## Getting Help

- Check documentation: `CLAUDE.md` for detailed reference
- View available commands: `just` (lists all recipes)
- Terraform docs: `terraform/README.md`
- Ansible docs: `ansible/README.md`

## Safety Tips

- **Always review** `tofu plan` before `tofu apply`
- **Test Ansible changes** with `--check --diff` first
- **Use version control** - commit working configurations
- **Backup state files** - especially before major changes
- **Tag releases** - when you have stable configurations
