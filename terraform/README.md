# Terraform/OpenTofu Infrastructure

This directory contains OpenTofu configurations for managing Hetzner Cloud infrastructure.

## Quick Start

### 1. Setup Hetzner API Token

First, encrypt your Hetzner API token with SOPS:

```bash
# Edit the secrets file (opens in your editor)
sops ../secrets/hetzner.yaml

# Replace the placeholder with your actual token from:
# https://console.hetzner.cloud/projects → Security → API Tokens
```

### 2. Initialize OpenTofu

```bash
# Using justfile (from root directory)
just tf-init

# Or directly
cd terraform && tofu init
```

### 3. Import Existing Resources

If you have existing Hetzner resources (recommended first-time setup):

```bash
# Using justfile (from root directory)
just tf-import

# Or directly
cd terraform && ./import.sh
```

This will import:
- Private network: `homelab`
- Network subnet
- 3 existing servers (mail, syncthing, test)

### 4. Verify Configuration

```bash
# Plan should show no changes if import was successful
just tf-plan
```

## Common Operations

### View Current Infrastructure

```bash
# Show all outputs (IPs, server details, etc.)
just tf-output

# View specific output
cd terraform && tofu output mail_server
```

### Make Changes

```bash
# Preview changes
just tf-plan

# Apply changes
just tf-apply
```

### Generate Ansible Inventory

```bash
# Update Ansible inventory from Terraform outputs
just ansible-inventory-update
```

## File Structure

- `providers.tf` - Hetzner provider configuration
- `variables.tf` - Input variables (API token, network config)
- `network.tf` - Private network and subnet
- `ssh_keys.tf` - SSH key data source
- `servers.tf` - Server definitions (mail, syncthing, test)
- `outputs.tf` - Outputs including Ansible inventory
- `import.sh` - Helper script to import existing resources

## Important Notes

### State Management
- State is stored locally in `terraform.tfstate`
- **Never commit state files** - they're in `.gitignore`
- State files may contain sensitive information
- Consider remote state backend for production

### Lifecycle Protection
- Production servers have `prevent_destroy = true`
- This prevents accidental deletion
- To destroy, first remove this lifecycle block

### Server Modifications
When modifying servers, be aware:
- Changing `image` will destroy and recreate the server
- Changing `server_type` will stop, resize, and restart
- Changing `location` will destroy and recreate
- Review `tofu plan` carefully before applying

## Troubleshooting

### "Resource already exists" error
The resource exists in Hetzner but not in Terraform state. Import it:
```bash
tofu import hcloud_server.mail_prod_nbg 58455669
```

### "API token invalid" error
Check that your SOPS secret is correctly configured:
```bash
sops -d ../secrets/hetzner.yaml
```

### State lock issues
If state is locked from a failed operation:
```bash
# DANGER: Only use if you're sure no other operation is running
tofu force-unlock <lock-id>
```

## Security

- API token stored in SOPS-encrypted file (`../secrets/hetzner.yaml`)
- Token loaded as environment variable at runtime
- Never commit `.tfvars` files with secrets
- Use example file: `terraform.tfvars.example`

## Adding New Servers

1. Add server definition to `servers.tf`:
```hcl
resource "hcloud_server" "new_server" {
  name        = "new-server.env.loc"
  server_type = "cax11"
  image       = "ubuntu-24.04"
  location    = "nbg1"
  ssh_keys    = [data.hcloud_ssh_key.homelab.id]

  network {
    network_id = hcloud_network.homelab.id
    ip         = "10.0.0.5"  # Choose next available IP
  }

  labels = {
    environment = "dev"
    role        = "new-role"
  }
}
```

2. Add output to `outputs.tf`
3. Plan and apply: `infra tf plan && infra tf apply`
4. Update Ansible inventory: `just ansible-inventory-update`
