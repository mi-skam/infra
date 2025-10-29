# Secrets Rotation Runbook

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [User Password Rotation](#3-user-password-rotation)
4. [API Token Rotation (Hetzner)](#4-api-token-rotation-hetzner)
5. [SSH Key Rotation](#5-ssh-key-rotation)
6. [Age Encryption Key Rotation](#6-age-encryption-key-rotation)
7. [Emergency Rotation (Compromised Keys)](#7-emergency-rotation-compromised-keys)
8. [Verification Procedures](#8-verification-procedures)
9. [Rollback Procedures](#9-rollback-procedures)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Overview

### Purpose
This runbook provides step-by-step procedures for rotating all types of secrets managed in the infrastructure repository. Regular rotation reduces the risk of unauthorized access and limits the impact of potential compromises.

### When to Rotate
- **Scheduled rotation**: Every 90 days (recommended minimum)
- **User change**: When team members leave or change roles
- **Compromise suspected**: Immediately if unauthorized access is suspected
- **Post-incident**: After any security incident

### Security Importance
- Limits exposure window if keys are compromised
- Ensures compliance with security policies
- Reduces impact of credential leaks
- Maintains principle of least privilege

**CRITICAL WARNING**: Never commit decrypted secrets or age private keys to git. Always verify files are encrypted before committing.

---

## 2. Prerequisites

### Required Access
- [x] SOPS age private key at `~/.config/sops/age/keys.txt` or `/etc/sops/age/keys.txt`
- [x] Git repository write access
- [x] Root/sudo access to NixOS systems (for password/age key deployment)
- [x] Hetzner Cloud Console access (for API token generation)
- [x] SSH access to all managed servers

### Required Tools
All tools are available in the nix development shell:

```bash
# Enter development shell
nix develop

# Or use direnv (recommended)
direnv allow
```

Tools included:
- `sops` - Secrets editing and decryption
- `age` - Encryption key management
- `mkpasswd` - Password hash generation
- `ssh-keygen` - SSH key generation
- `git` - Version control
- `nixos-rebuild` / `darwin-rebuild` - System deployment
- `just` - Task automation

### Environment Setup

```bash
# Verify SOPS can access age key
sops -d secrets/hetzner.yaml

# Expected output: Decrypted YAML content
# If error: Check age key location and permissions

# Verify git status
git status

# Expected: Working directory clean (or only intended changes)
```

---

## 3. User Password Rotation

**Estimated time**: 15-30 minutes per user

User passwords are stored as hashes in `secrets/users.yaml` and deployed to NixOS systems via sops-nix.

### 3.1 Prerequisites
- mkpasswd tool (available in devshell)
- Root access to target NixOS systems
- User accounts already exist in `modules/users/`

### 3.2 Generate New Password Hash

**Step 1**: Generate new password hash using one of these methods:

**Option A: SHA-512 (recommended for compatibility)**
```bash
NEW_HASH=$(mkpasswd -m sha-512)
# Prompts for password twice
# Output format: $6$<salt>$<hash> (106 characters total)
```

**Option B: Bcrypt (recommended for security)**
```bash
NEW_HASH=$(mkpasswd -m bcrypt)
# Prompts for password twice
# Output format: $2b$<cost>$<salt+hash> (60 characters total)
```

**Step 2**: Verify hash format
```bash
echo "$NEW_HASH"

# Expected SHA-512 format:
# $6$SomeRandomSalt$VeryLongHashStringWith86Characters...

# Expected Bcrypt format:
# $2b$12$SomeRandomSaltAndHashWith53Characters...
```

### 3.3 Update Secrets File

**Step 3**: Edit the users secrets file
```bash
sops secrets/users.yaml
```

**Step 4**: Update the password hash for the target user
```yaml
# Example structure (edit in SOPS editor)
users:
  mi-skam:
    password_hash: "$6$NewSaltHere$NewHashHere..."
  plumps:
    password_hash: "$2b$12$AnotherHashHere..."
```

**Step 5**: Save and exit SOPS editor (Ctrl+X for nano, :wq for vim)

### 3.4 Validate Changes

**Step 6**: Run secrets validation script
```bash
scripts/validate-secrets.sh

# Expected output:
# ✓ Validating secrets/users.yaml...
# ✓ All secrets valid
```

**Step 7**: Verify git diff shows only encrypted changes
```bash
git diff secrets/users.yaml

# Expected: Binary/encrypted diff (no plaintext passwords visible)
```

### 3.5 Deploy New Password

**Step 8**: Commit the encrypted secrets
```bash
git add secrets/users.yaml
git commit -m "chore(secrets): rotate password for <username>"
```

**Step 9**: Deploy to NixOS systems
```bash
# For specific host
sudo nixos-rebuild switch --flake .#xmsi

# Expected output:
# building the system configuration...
# activating the configuration...
# setting up /etc...
```

**Step 10**: Verify deployment (see [Section 8.1](#81-user-password-verification))

### 3.6 Timing Considerations
- **Grace period**: Old password remains valid until system rebuild completes
- **Downtime**: None (users can continue working during deployment)
- **Propagation**: Immediate after `nixos-rebuild switch` completes

### 3.7 Rollback (if needed)
See [Section 9.1](#91-user-password-rollback)

---

## 4. API Token Rotation (Hetzner)

**Estimated time**: 10-20 minutes

Hetzner Cloud API token is stored in `secrets/hetzner.yaml` and used by OpenTofu for infrastructure provisioning.

### 4.1 Prerequisites
- Hetzner Cloud Console access
- OpenTofu installed (available in devshell)
- No active `tofu apply` operations in progress

### 4.2 Generate New Token

**Step 1**: Access Hetzner Cloud Console
```bash
# Open in browser
open https://console.hetzner.cloud/

# Navigate to: Project → Security → API Tokens → Generate API Token
```

**Step 2**: Create new token
- **Description**: `homelab-tofu-<YYYY-MM-DD>` (e.g., `homelab-tofu-2025-10-29`)
- **Permissions**: Read & Write (required for infrastructure management)
- **Click**: Generate API Token

**Step 3**: Copy the 64-character token immediately
```
Example format: AbCdEf1234567890AbCdEf1234567890AbCdEf1234567890AbCdEf123456
```

**IMPORTANT**: Token is only shown once. Store temporarily in secure location (password manager).

### 4.3 Update Secrets File

**Step 4**: Edit the Hetzner secrets file
```bash
sops secrets/hetzner.yaml
```

**Step 5**: Replace the token value
```yaml
# Example structure (edit in SOPS editor)
hcloud: "AbCdEf1234567890AbCdEf1234567890AbCdEf1234567890AbCdEf123456"
```

**Step 6**: Save and exit SOPS editor

### 4.4 Validate Changes

**Step 7**: Run secrets validation script
```bash
scripts/validate-secrets.sh

# Expected output:
# ✓ Validating secrets/hetzner.yaml...
# ✓ hcloud token format valid (64 characters)
# ✓ All secrets valid
```

**Step 8**: Verify token format
```bash
sops -d secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs | wc -c

# Expected output: 65 (64 characters + newline)
```

### 4.5 Test New Token

**Step 9**: Test token with OpenTofu
```bash
cd terraform
just tf-plan

# Expected output:
# No changes. Your infrastructure matches the configuration.
# (If infrastructure changes are pending, output will show planned changes)
```

**Step 10**: Verify Hetzner API access
```bash
# Set token temporarily (for testing)
export HCLOUD_TOKEN="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"

hcloud server list

# Expected output: List of managed servers (mail-1, syncthing-1, test-1)
```

### 4.6 Revoke Old Token

**Step 11**: Return to Hetzner Cloud Console
```bash
# Navigate to: Project → Security → API Tokens
```

**Step 12**: Delete the old token
- Find token with previous date in description
- Click trash icon → Confirm deletion

**CRITICAL**: Do not delete the new token by mistake. Verify description matches old date.

### 4.7 Commit Changes

**Step 13**: Commit the encrypted secrets
```bash
git add secrets/hetzner.yaml
git commit -m "chore(secrets): rotate Hetzner Cloud API token"
```

### 4.8 Timing Considerations
- **Grace period**: Old token remains valid until revoked (Step 12)
- **Downtime**: None (infrastructure continues running)
- **Propagation**: Immediate (next `just tf-plan` or `just tf-apply` uses new token)

### 4.9 Rollback (if needed)
See [Section 9.2](#92-api-token-rollback)

---

## 5. SSH Key Rotation

**Estimated time**: 30-45 minutes

SSH keys are stored in `secrets/ssh-keys.yaml` and deployed to systems for authentication.

### 5.1 Prerequisites
- ssh-keygen tool (available in devshell)
- Access to all systems using the key
- Knowledge of which systems use which keys

### 5.2 Generate New SSH Key Pair

**Step 1**: Generate new SSH key
```bash
# For Ed25519 (recommended - modern, secure, fast)
ssh-keygen -t ed25519 -C "homelab-<purpose>-<YYYY-MM-DD>" -f ~/.ssh/id_homelab_new

# For RSA (legacy compatibility if needed)
ssh-keygen -t rsa -b 4096 -C "homelab-<purpose>-<YYYY-MM-DD>" -f ~/.ssh/id_homelab_new

# Example for Hetzner SSH key:
ssh-keygen -t ed25519 -C "homelab-hetzner-2025-10-29" -f ~/.ssh/id_homelab_hetzner_new
```

**Step 2**: Review generated keys
```bash
ls -la ~/.ssh/id_homelab_new*

# Expected output:
# -rw------- 1 user user  411 Oct 29 10:00 id_homelab_new (private key)
# -rw-r--r-- 1 user user   98 Oct 29 10:00 id_homelab_new.pub (public key)
```

**Step 3**: Extract public key for deployment
```bash
cat ~/.ssh/id_homelab_new.pub

# Example output:
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbCdEfGhIjKlMnOpQrStUvWxYz homelab-hetzner-2025-10-29
```

### 5.3 Update Secrets File

**Step 4**: Edit the SSH keys secrets file
```bash
sops secrets/ssh-keys.yaml
```

**Step 5**: Add or update the SSH key entry
```yaml
# Example structure (edit in SOPS editor)
ssh_keys:
  homelab-hetzner:
    private_key: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
      QyNTUxOQAAACAABsCdEfGhIjKlMnOpQrStUvWxYzAAAAAABG5vbmUAAAAEbm9uZQAAAAAA
      ... (full private key content)
      -----END OPENSSH PRIVATE KEY-----
    key_type: ed25519
    key_size: 256
    public_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbCdEfGhIjKlMnOpQrStUvWxYz homelab-hetzner-2025-10-29"
```

**Step 6**: Copy private key content
```bash
cat ~/.ssh/id_homelab_new

# Copy entire output including:
# -----BEGIN OPENSSH PRIVATE KEY-----
# ... (key content) ...
# -----END OPENSSH PRIVATE KEY-----
```

### 5.4 Deploy Public Key

**Step 7**: Add public key to target systems

**For Hetzner Cloud (via Console or CLI):**
```bash
# Upload new SSH key to Hetzner
export HCLOUD_TOKEN="$(sops -d secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
hcloud ssh-key create --name homelab-hetzner-new --public-key-from-file ~/.ssh/id_homelab_new.pub

# Expected output:
# SSH key 123456 created
```

**For existing servers (manual deployment):**
```bash
# Copy public key to server
ssh-copy-id -i ~/.ssh/id_homelab_new.pub user@server

# Or manually append to authorized_keys
cat ~/.ssh/id_homelab_new.pub | ssh user@server "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**Step 8**: Test new key authentication
```bash
ssh -i ~/.ssh/id_homelab_new user@server whoami

# Expected output: username (successful login)
```

### 5.5 Update Infrastructure Configuration

**Step 9**: Update OpenTofu configuration (if SSH key used for infrastructure)
```bash
cd terraform
# Edit servers.tf to reference new Hetzner SSH key ID
# Or update terraform.tfvars if SSH key is parameterized
```

**Step 10**: Apply infrastructure changes
```bash
just tf-plan
just tf-apply

# Expected: SSH key associations updated on servers
```

### 5.6 Remove Old Key

**Step 11**: Remove old public key from systems
```bash
# SSH to each server and edit authorized_keys
ssh user@server "sed -i '/OLD_KEY_COMMENT/d' ~/.ssh/authorized_keys"

# For Hetzner Cloud, delete old SSH key
hcloud ssh-key delete homelab-hetzner-old
```

**Step 12**: Validate and commit secrets
```bash
scripts/validate-secrets.sh
git add secrets/ssh-keys.yaml
git commit -m "chore(secrets): rotate SSH key for <purpose>"
```

### 5.7 Secure Old Key

**Step 13**: Backup and remove old private key
```bash
# Backup to encrypted storage (optional)
cp ~/.ssh/id_homelab_old ~/.ssh/backup/id_homelab_old.$(date +%Y%m%d)

# Remove from active SSH directory
rm ~/.ssh/id_homelab_old ~/.ssh/id_homelab_old.pub
```

### 5.8 Timing Considerations
- **Grace period**: Both keys valid during deployment (Step 7-10)
- **Downtime**: None (old key remains functional until removal)
- **Propagation**: Immediate after public key deployment

### 5.9 Rollback (if needed)
See [Section 9.3](#93-ssh-key-rollback)

---

## 6. Age Encryption Key Rotation

**Estimated time**: 60-90 minutes (most complex rotation)

Age encryption keys protect all SOPS-encrypted secrets. Rotating the age key requires re-encrypting ALL secret files.

**CRITICAL**: This is the most sensitive rotation. Plan for maintenance window and coordinate with team.

### 6.1 Prerequisites
- age tool (available in devshell)
- Access to ALL NixOS systems for private key deployment
- Backup of current age private key (encrypted storage)
- No active SOPS editing sessions

### 6.2 Generate New Age Key Pair

**Step 1**: Generate new age key
```bash
# Generate to temporary location
age-keygen -o ~/.config/sops/age/keys-new.txt

# Expected output:
# Public key: age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
# (This is your NEW public key - save it)
```

**Step 2**: Extract new public key
```bash
NEW_PUBKEY=$(age-keygen -y ~/.config/sops/age/keys-new.txt)
echo "New public key: $NEW_PUBKEY"

# Example output:
# New public key: age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

**Step 3**: Backup current age key (CRITICAL)
```bash
# Create encrypted backup
cp ~/.config/sops/age/keys.txt ~/.config/sops/age/keys-backup-$(date +%Y%m%d).txt
chmod 600 ~/.config/sops/age/keys-backup-*.txt

# Verify backup
ls -la ~/.config/sops/age/keys-backup-*

# Expected: File exists with 600 permissions
```

### 6.3 Update SOPS Configuration

**Step 4**: Edit SOPS configuration
```bash
vim .sops.yaml
# Or use your preferred editor
```

**Step 5**: Replace age public key
```yaml
# Before:
keys:
  - &mi-skam age16uelq9w6kw6wt0e5srm3vu8nsf0zqjkc9esdv4mynslf0quw93vqdp2ksj

# After:
keys:
  - &mi-skam age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

**Step 6**: Verify SOPS configuration syntax
```bash
grep "age1" .sops.yaml

# Expected output: Shows new age public key
```

### 6.4 Re-encrypt All Secrets

**CRITICAL**: This step re-encrypts all secrets with the new age key.

**Step 7**: Temporarily set SOPS to use new key for decryption
```bash
# Keep old key accessible for decryption, new key for encryption
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt:~/.config/sops/age/keys-new.txt
```

**Step 8**: Re-encrypt each secret file
```bash
# Re-encrypt all secrets
sops updatekeys secrets/hetzner.yaml
sops updatekeys secrets/storagebox.yaml
# Add commands for each secret file as they are created:
# sops updatekeys secrets/users.yaml
# sops updatekeys secrets/ssh-keys.yaml
# sops updatekeys secrets/pgp-keys.yaml

# Expected output for each file:
# The following changes will be made to the file's groups:
# [... shows key changes ...]
# Is this okay? (y/n): y
```

**Alternative: Batch re-encryption**
```bash
for secret in secrets/*.yaml; do
  echo "Re-encrypting $secret..."
  sops updatekeys "$secret"
done
```

**Step 9**: Verify re-encryption with new key
```bash
# Test decryption with NEW key only
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys-new.txt

sops -d secrets/hetzner.yaml

# Expected: Successful decryption (output shows plaintext content)
# If error: Re-encryption failed, see rollback procedure
```

### 6.5 Deploy New Private Key to Systems

**CRITICAL**: All NixOS systems need the new private key before they can decrypt secrets.

**Step 10**: Deploy new age private key to each NixOS system
```bash
# For each NixOS host (xmsi, srv-01, etc.)
scp ~/.config/sops/age/keys-new.txt root@xmsi:/etc/sops/age/keys.txt

# Set secure permissions
ssh root@xmsi "chmod 600 /etc/sops/age/keys.txt && chown root:root /etc/sops/age/keys.txt"

# Verify deployment
ssh root@xmsi "ls -la /etc/sops/age/keys.txt"

# Expected output:
# -rw------- 1 root root 184 Oct 29 10:00 /etc/sops/age/keys.txt
```

**Step 11**: Test decryption on each system
```bash
ssh root@xmsi "sops -d /run/secrets-for-users/mi-skam 2>&1 | head -5"

# Expected: Decrypted content (or specific secret value)
# If error: Check key file permissions and content
```

### 6.6 Activate New Key Locally

**Step 12**: Replace old key with new key
```bash
# Verify backup exists
ls -la ~/.config/sops/age/keys-backup-*

# Replace old key
mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Verify new key is active
unset SOPS_AGE_KEY_FILE  # Use default location
sops -d secrets/hetzner.yaml | head -3

# Expected: Successful decryption
```

### 6.7 Validate and Commit

**Step 13**: Run full secrets validation
```bash
scripts/validate-secrets.sh

# Expected output:
# ✓ Validating secrets/hetzner.yaml...
# ✓ Validating secrets/storagebox.yaml...
# ✓ All secrets valid
```

**Step 14**: Commit changes
```bash
git add .sops.yaml secrets/*.yaml
git commit -m "chore(secrets): rotate age encryption key"
```

### 6.8 Cleanup

**Step 15**: Securely archive old key
```bash
# Move backup to secure location (encrypted USB, password manager, etc.)
# DO NOT leave old key in repository or home directory

# Verify old key removed from active locations
find ~ -name "keys.txt" -o -name "keys-old.txt" 2>/dev/null

# Expected: Only new key at ~/.config/sops/age/keys.txt
```

### 6.9 Timing Considerations
- **Grace period**: None (hard cutover)
- **Downtime**: Brief window during Step 10-11 (systems cannot decrypt secrets)
- **Propagation**: All systems must be updated simultaneously
- **Recommended**: Perform during maintenance window

### 6.10 Rollback (if needed)
See [Section 9.4](#94-age-key-rollback)

---

## 7. Emergency Rotation (Compromised Keys)

**Estimated time**: 2-4 hours (depending on scope)

Emergency rotation is required when secrets are compromised or suspected to be compromised (e.g., laptop stolen, accidental git commit, unauthorized access detected).

### 7.1 Immediate Actions (First 15 Minutes)

**CRITICAL**: Speed is essential. Follow this exact order.

**Step 1**: Assess compromise scope
```bash
# Questions to answer:
# - Which secrets are compromised? (age key, API tokens, passwords, SSH keys, all?)
# - How were secrets exposed? (git commit, stolen device, unauthorized access?)
# - When did compromise occur? (within 24h, 1 week, 1 month, unknown?)
# - Are systems currently under attack? (check logs, monitoring)
```

**Step 2**: Revoke compromised credentials immediately

**If Hetzner API token compromised:**
```bash
# Access Hetzner Cloud Console
open https://console.hetzner.cloud/
# Navigate to: Security → API Tokens → Delete compromised token
```

**If SSH keys compromised:**
```bash
# Remove public keys from all servers
for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
  echo "=== $server ==="
  ssh root@$server "sed -i '/COMPROMISED_KEY_COMMENT/d' ~/.ssh/authorized_keys"
done

# Delete from Hetzner Cloud
hcloud ssh-key delete compromised-key-name
```

**Step 3**: Block unauthorized access
```bash
# If specific user account compromised (NixOS systems)
ssh root@xmsi "passwd -l compromised-username"  # Lock account

# Monitor for suspicious activity
ssh root@xmsi "journalctl -u sshd --since '1 hour ago' | grep 'Failed password'"
```

### 7.2 Rotation Priority Order

**CRITICAL**: Rotate in this specific order to ensure new secrets are protected:

1. **Age encryption keys** (FIRST - protects all new secrets)
2. **API tokens** (within 1 hour - prevents infrastructure abuse)
3. **User passwords** (within 4 hours - prevents system access)
4. **SSH keys** (within 24 hours - prevents remote access)
5. **PGP keys** (if applicable)

### 7.3 Age Key Emergency Rotation

**Step 4**: Rotate age key immediately (see [Section 6](#6-age-encryption-key-rotation))

**Critical differences in emergency rotation:**
- Skip backup of compromised key (already compromised)
- Prioritize speed over coordination
- Deploy to all systems before continuing

```bash
# Fast track age rotation
age-keygen -o ~/.config/sops/age/keys-new.txt
NEW_PUBKEY=$(age-keygen -y ~/.config/sops/age/keys-new.txt)

# Update .sops.yaml
sed -i "s/age16uelq9.*/$NEW_PUBKEY/" .sops.yaml

# Re-encrypt all secrets (non-interactive)
for secret in secrets/*.yaml; do
  SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt:~/.config/sops/age/keys-new.txt sops updatekeys --yes "$secret"
done

# Deploy to all systems immediately
for host in xmsi srv-01; do
  scp ~/.config/sops/age/keys-new.txt root@$host:/etc/sops/age/keys.txt
  ssh root@$host "chmod 600 /etc/sops/age/keys.txt"
done

# Activate new key
mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt
```

### 7.4 API Token Emergency Rotation

**Step 5**: Rotate Hetzner API token (see [Section 4](#4-api-token-rotation-hetzner))

**Fast track:**
```bash
# Generate new token in Hetzner Console (already done in Step 2)
# Update secrets
sops secrets/hetzner.yaml  # Paste new token

# Test immediately
just tf-plan

# If successful, delete old token in Hetzner Console
```

### 7.5 User Password Emergency Rotation

**Step 6**: Rotate all user passwords (see [Section 3](#3-user-password-rotation))

**Fast track (multiple users):**
```bash
# Generate hashes for all users
sops secrets/users.yaml

# Update all password_hash fields in SOPS editor
# Save and exit

# Deploy to all NixOS systems
nixos-rebuild switch --flake .#xmsi

# Notify users of password change
# Force password change at next login (if required)
```

### 7.6 SSH Key Emergency Rotation

**Step 7**: Rotate all SSH keys (see [Section 5](#5-ssh-key-rotation))

**Fast track:**
```bash
# Generate new keys
ssh-keygen -t ed25519 -f ~/.ssh/id_homelab_emergency -N ""

# Deploy to all systems
for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
  ssh-copy-id -i ~/.ssh/id_homelab_emergency.pub root@$server
done

# Update Hetzner Cloud
hcloud ssh-key create --name homelab-emergency --public-key-from-file ~/.ssh/id_homelab_emergency.pub

# Remove old keys
for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
  ssh root@$server "grep -v 'OLD_KEY_COMMENT' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.new && mv ~/.ssh/authorized_keys.new ~/.ssh/authorized_keys"
done
```

### 7.7 Post-Rotation Security Audit

**Step 8**: Review git history for accidental commits
```bash
# Search for potential secret leaks in git history
git log --all --full-history --source -p -S "BEGIN OPENSSH PRIVATE KEY"
git log --all --full-history --source -p -S "BEGIN AGE ENCRYPTED FILE"

# If private keys found in history
git filter-repo --path-glob 'secrets/*.txt' --invert-paths  # Requires git-filter-repo
# WARNING: This rewrites history. Coordinate with team.
```

**Step 9**: Review backup locations
```bash
# Check for unencrypted backups
find ~ -name "*.yaml" -o -name "keys.txt" -o -name "*.key" 2>/dev/null | grep -v ".git"

# Verify backups are encrypted (SOPS files should be encrypted)
file secrets/hetzner.yaml

# Expected: Binary data (encrypted)
# If "ASCII text": File is NOT encrypted (CRITICAL ISSUE)
```

**Step 10**: Review access logs
```bash
# Check SSH access logs on all systems
for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
  echo "=== $server ==="
  ssh root@$server "journalctl -u sshd --since '7 days ago' | grep 'Accepted publickey' | tail -20"
done

# Check Hetzner API access logs (via Hetzner Console)
# Navigate to: Project → Audit Log
```

### 7.8 Documentation and Reporting

**Step 11**: Document the incident
```bash
# Create incident report
cat > docs/incidents/incident-$(date +%Y%m%d).md <<'EOF'
# Security Incident Report

**Date**: $(date +%Y-%m-%d)
**Reporter**: <Your Name>
**Severity**: <Critical/High/Medium/Low>

## Summary
<Brief description of compromise>

## Compromised Secrets
- [ ] Age encryption key
- [ ] Hetzner API token
- [ ] User passwords (list usernames)
- [ ] SSH keys (list key names)

## Timeline
- **Discovery**: <When compromise was discovered>
- **Compromise occurred**: <Estimated time of compromise>
- **Revocation**: <When credentials were revoked>
- **Rotation completed**: <When all rotations completed>

## Actions Taken
1. <List all actions taken>

## Lessons Learned
<What to improve to prevent recurrence>

## Follow-up Actions
- [ ] <Action items>
EOF
```

**Step 12**: Notify team and stakeholders
- Inform team members of password changes
- Update runbooks based on lessons learned
- Schedule post-incident review meeting

### 7.9 Timing Considerations

**Target timelines:**
- **Discovery to revocation**: < 15 minutes
- **Age key rotation**: < 30 minutes
- **API token rotation**: < 60 minutes
- **Password rotation**: < 4 hours
- **SSH key rotation**: < 24 hours
- **Full audit and documentation**: < 48 hours

---

## 8. Verification Procedures

After any rotation, verify secrets are deployed correctly and systems function normally.

### 8.1 User Password Verification

**Test 1**: SSH login with new password
```bash
# From workstation
ssh mi-skam@xmsi

# Expected: Password prompt, successful login with new password
# If fails: Check password hash in secrets file, verify nixos-rebuild completed
```

**Test 2**: Verify user can authenticate locally
```bash
# On the NixOS system
ssh localhost

# Expected: Password prompt, successful login
```

**Test 3**: Check sops-nix secret deployment
```bash
# On the NixOS system
sudo ls -la /run/secrets-for-users/

# Expected output:
# lrwxrwxrwx 1 root root 39 Oct 29 10:00 mi-skam -> /run/agenix.d/1/mi-skam
# (Symbolic link to age-decrypted secret)

# Verify secret can be read by activation script
sudo cat /run/secrets-for-users/mi-skam | head -c 10

# Expected: Password hash prefix (e.g., "$6$" or "$2b$")
```

### 8.2 API Token Verification

**Test 1**: OpenTofu plan succeeds
```bash
just tf-plan

# Expected output:
# No changes. Your infrastructure matches the configuration.
# (Or shows pending changes if infrastructure updates exist)
# No authentication errors
```

**Test 2**: Hetzner CLI access
```bash
hcloud server list

# Expected output: List of managed servers
# NAME                TYPE    STATUS    IPV4             IPV6
# mail-1.prod.nbg     cax21   running   <IP>             <IP>
# syncthing-1.prod... cax11   running   <IP>             <IP>
# test-1.dev.nbg      cax11   running   <IP>             <IP>
```

**Test 3**: API operations
```bash
# Test read operation
hcloud network describe homelab

# Expected: Network details (10.0.0.0/16)

# Test write operation (create test firewall rule)
hcloud firewall create --name test-rotation-$(date +%s)

# Expected: Firewall created (delete after test)
# hcloud firewall delete test-rotation-<timestamp>
```

### 8.3 SSH Key Verification

**Test 1**: SSH authentication with new key
```bash
ssh -i ~/.ssh/id_homelab_new user@server whoami

# Expected output: username
```

**Test 2**: Verify old key no longer works
```bash
ssh -i ~/.ssh/id_homelab_old user@server whoami

# Expected: Permission denied (publickey)
# If succeeds: Old key still deployed, repeat removal steps
```

**Test 3**: Check authorized_keys on servers
```bash
ssh user@server "cat ~/.ssh/authorized_keys | grep -c 'ssh-'"

# Expected output: Number of active SSH keys
# Verify old key comment not present
ssh user@server "grep 'OLD_KEY_COMMENT' ~/.ssh/authorized_keys"

# Expected: No output (old key removed)
```

**Test 4**: Hetzner Cloud SSH key status
```bash
hcloud ssh-key list

# Expected: New key listed, old key absent
# ID    NAME                  FINGERPRINT
# 123   homelab-hetzner-new   aa:bb:cc:...
```

### 8.4 Age Key Verification

**Test 1**: Decrypt secrets with new key
```bash
# Test each secret file
sops -d secrets/hetzner.yaml | head -5
sops -d secrets/storagebox.yaml | head -5

# Expected: Decrypted YAML content
# If error "no valid decryption key": Re-encryption failed, see rollback
```

**Test 2**: Verify old key cannot decrypt
```bash
# Use old key explicitly (from backup)
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys-backup-*.txt sops -d secrets/hetzner.yaml

# Expected: Error (no valid decryption key)
# If succeeds: Re-encryption incomplete, secrets still encrypted with old key
```

**Test 3**: NixOS systems can decrypt
```bash
# Test on each NixOS host
ssh root@xmsi "sops -d /run/current-system/secrets.yaml 2>&1 | head -5"

# Expected: Decrypted content or system secrets
# If error: Private key not deployed correctly to /etc/sops/age/keys.txt
```

**Test 4**: Verify SOPS configuration
```bash
grep "age1" .sops.yaml

# Expected output: Shows new age public key (age1abc123...)
# Verify matches output from: age-keygen -y ~/.config/sops/age/keys.txt
```

### 8.5 Full System Verification

**Test 1**: Run secrets validation script
```bash
scripts/validate-secrets.sh

# Expected output:
# ✓ Validating secrets/hetzner.yaml...
# ✓ Validating secrets/storagebox.yaml...
# ✓ All secrets valid
```

**Test 2**: NixOS system rebuild
```bash
# Full system rebuild to verify all secrets accessible
sudo nixos-rebuild switch --flake .#xmsi

# Expected: Successful build and activation
# No errors about missing secrets or decryption failures
```

**Test 3**: Ansible playbook execution
```bash
just ansible-ping

# Expected: All hosts respond successfully
# mail-1.prod.nbg | SUCCESS => {"changed": false, "ping": "pong"}
# syncthing-1.prod.hel | SUCCESS => {"changed": false, "ping": "pong"}
# test-1.dev.nbg | SUCCESS => {"changed": false, "ping": "pong"}
```

**Test 4**: Application functionality
- Test services that depend on rotated secrets
- For Hetzner token: Create test resource, delete test resource
- For user passwords: Login to systems, run sudo commands
- For SSH keys: Connect to all managed servers
- For storage box: Mount/unmount storage (if applicable)

### 8.6 Verification Checklist

Use this checklist after each rotation:

```markdown
## Post-Rotation Verification

**Rotation type**: <User Password / API Token / SSH Key / Age Key>
**Date**: <YYYY-MM-DD>
**Rotated by**: <Name>

### Secrets File Validation
- [ ] `scripts/validate-secrets.sh` passes
- [ ] Git diff shows only encrypted changes
- [ ] Secrets committed to git

### Decryption Tests
- [ ] New secrets decrypt successfully
- [ ] Old secrets cannot decrypt (if applicable)
- [ ] All target systems can decrypt

### Functional Tests
- [ ] Authentication works with new credentials
- [ ] Applications function normally
- [ ] Infrastructure operations succeed (Terraform, Ansible)

### Cleanup
- [ ] Old credentials revoked/removed
- [ ] Old private keys removed from active locations
- [ ] Backups stored securely (encrypted)

### Documentation
- [ ] Rotation documented in git commit message
- [ ] Team notified of changes (if applicable)
- [ ] Runbook updated (if issues found)
```

---

## 9. Rollback Procedures

If rotation fails or causes issues, rollback to previous secrets quickly.

### 9.1 User Password Rollback

**Scenario**: New password doesn't work, users locked out.

**Step 1**: Identify last working commit
```bash
git log --oneline secrets/users.yaml | head -5

# Example output:
# abc1234 chore(secrets): rotate password for mi-skam
# def5678 chore(secrets): rotate password for plumps
# ghi9012 Initial secrets setup
```

**Step 2**: Restore previous secrets file
```bash
# Restore from previous commit
git checkout HEAD~1 -- secrets/users.yaml

# Or restore from specific commit
git checkout def5678 -- secrets/users.yaml
```

**Step 3**: Verify restoration
```bash
git diff HEAD secrets/users.yaml

# Expected: Shows binary/encrypted diff (reverting to old version)
```

**Step 4**: Re-deploy to NixOS systems
```bash
sudo nixos-rebuild switch --flake .#xmsi

# Expected: Old password hashes deployed
```

**Step 5**: Test old password works
```bash
ssh mi-skam@xmsi

# Expected: Login succeeds with old password
```

**Step 6**: Document rollback and investigate
```bash
# Commit rollback
git add secrets/users.yaml
git commit -m "rollback(secrets): revert password rotation for mi-skam (deployment failed)"

# Investigate why rotation failed
# Common causes:
# - Incorrect password hash format
# - Typo in password during mkpasswd
# - NixOS module configuration error
```

### 9.2 API Token Rollback

**Scenario**: New Hetzner API token doesn't work, infrastructure operations fail.

**Step 1**: Restore old token from git
```bash
git checkout HEAD~1 -- secrets/hetzner.yaml
```

**Step 2**: Test restored token
```bash
just tf-plan

# Expected: Succeeds with old token
# If fails: Old token may have been revoked in Hetzner Console
```

**Step 3**: If old token revoked, create emergency token
```bash
# Generate new token in Hetzner Console
# Update secrets immediately
sops secrets/hetzner.yaml

# Test
just tf-plan
```

**Step 4**: Commit rollback
```bash
git add secrets/hetzner.yaml
git commit -m "rollback(secrets): revert Hetzner token rotation (authentication failed)"
```

**Alternative: Restore old token in Hetzner Console**

If old token still exists (not yet revoked):
- No rollback needed in secrets file
- Old token automatically works again
- Investigate why new token failed (incorrect copy, wrong permissions level)

### 9.3 SSH Key Rollback

**Scenario**: New SSH key doesn't work, cannot access servers.

**Step 1**: Re-deploy old public key to servers
```bash
# If old private key still accessible
ssh-copy-id -i ~/.ssh/id_homelab_old.pub user@server

# If old private key deleted, use password authentication
ssh user@server
# Manually paste old public key into ~/.ssh/authorized_keys
```

**Step 2**: Verify old key works
```bash
ssh -i ~/.ssh/id_homelab_old user@server whoami

# Expected: Successful login
```

**Step 3**: Restore secrets file (if updated)
```bash
git checkout HEAD~1 -- secrets/ssh-keys.yaml
git add secrets/ssh-keys.yaml
git commit -m "rollback(secrets): revert SSH key rotation (authentication failed)"
```

**Step 4**: Remove problematic new key
```bash
# Remove from servers
for server in mail-1.prod.nbg syncthing-1.prod.hel test-1.dev.nbg; do
  ssh -i ~/.ssh/id_homelab_old user@$server "sed -i '/NEW_KEY_COMMENT/d' ~/.ssh/authorized_keys"
done

# Remove from Hetzner Cloud
hcloud ssh-key delete homelab-hetzner-new
```

### 9.4 Age Key Rollback

**Scenario**: New age key doesn't decrypt secrets, systems cannot access secrets.

**CRITICAL**: This is the most complex rollback. Act quickly to minimize downtime.

**Step 1**: Restore old age private key
```bash
# Copy from backup
cp ~/.config/sops/age/keys-backup-$(date +%Y%m%d).txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

**Step 2**: Test decryption with old key
```bash
sops -d secrets/hetzner.yaml | head -5

# Expected: Successful decryption
# If fails: Secrets already re-encrypted with new key, continue to Step 3
```

**Step 3**: If secrets re-encrypted, restore from git
```bash
# Restore all secret files
git checkout HEAD~1 -- secrets/*.yaml

# Restore SOPS configuration
git checkout HEAD~1 -- .sops.yaml

# Verify restoration
git status

# Expected: Shows modified files (restored to previous commit)
```

**Step 4**: Deploy old key to all NixOS systems
```bash
# Deploy old key to each system
for host in xmsi srv-01; do
  scp ~/.config/sops/age/keys.txt root@$host:/etc/sops/age/keys.txt
  ssh root@$host "chmod 600 /etc/sops/age/keys.txt"
done
```

**Step 5**: Verify systems can decrypt
```bash
ssh root@xmsi "sops -d /run/current-system/secrets.yaml | head -5"

# Expected: Successful decryption
```

**Step 6**: Rebuild NixOS systems
```bash
sudo nixos-rebuild switch --flake .#xmsi

# Expected: Successful build with old age key
```

**Step 7**: Commit rollback
```bash
git add .sops.yaml secrets/*.yaml
git commit -m "rollback(secrets): revert age key rotation (decryption failed)"
```

**Step 8**: Investigate failure
```bash
# Common causes:
# 1. New key not deployed to all systems before activation
# 2. Incorrect public key in .sops.yaml
# 3. Re-encryption incomplete (some files missed)
# 4. Permissions issue on private key file

# Review rotation steps and try again with corrected procedure
```

### 9.5 Emergency Rollback (All Secrets)

**Scenario**: Multiple rotations failed, systems unstable.

**Step 1**: Identify last known-good commit
```bash
git log --oneline --all | head -20

# Find commit before rotation started
# Example: "abc1234 feat: add new feature" (before rotation)
```

**Step 2**: Restore all secrets to known-good state
```bash
# Restore all secrets and SOPS config
git checkout abc1234 -- secrets/ .sops.yaml

# Verify restoration
git diff HEAD
```

**Step 3**: Deploy old age key to all systems
```bash
# Copy old key from backup
cp ~/.config/sops/age/keys-backup-*.txt ~/.config/sops/age/keys.txt

# Deploy to all NixOS systems
for host in xmsi srv-01; do
  scp ~/.config/sops/age/keys.txt root@$host:/etc/sops/age/keys.txt
done
```

**Step 4**: Rebuild all systems
```bash
# Rebuild each NixOS system
sudo nixos-rebuild switch --flake .#xmsi

# Test Terraform
just tf-plan

# Test Ansible
just ansible-ping
```

**Step 5**: Verify all systems operational
```bash
# Run full verification checklist (Section 8.5)
scripts/validate-secrets.sh
```

**Step 6**: Commit emergency rollback
```bash
git add secrets/ .sops.yaml
git commit -m "rollback(secrets): emergency rollback to last known-good state (abc1234)"

# Document incident
# Create incident report (see Section 7.8)
```

---

## 10. Troubleshooting

Common issues and solutions during secrets rotation.

### 10.1 SOPS Decryption Failures

**Symptom**: `error: no valid decryption key`

**Causes and solutions:**

**Cause 1**: Age private key not accessible
```bash
# Check age key location
ls -la ~/.config/sops/age/keys.txt
ls -la /etc/sops/age/keys.txt

# Expected: File exists with 600 permissions
# If missing: Restore from backup or use SOPS_AGE_KEY_FILE env var

# Verify key format
head -1 ~/.config/sops/age/keys.txt

# Expected: # created: <timestamp>
# Or: AGE-SECRET-KEY-1...
```

**Cause 2**: Public key mismatch in .sops.yaml
```bash
# Extract public key from private key
age-keygen -y ~/.config/sops/age/keys.txt

# Compare with .sops.yaml
grep "age1" .sops.yaml

# If different: Update .sops.yaml with correct public key
```

**Cause 3**: Secret encrypted with different key
```bash
# Check which keys can decrypt the file
sops --decrypt --verbose secrets/hetzner.yaml 2>&1 | grep "age"

# If shows different age key: Need correct private key or re-encrypt
```

### 10.2 Password Hash Validation Failures

**Symptom**: `scripts/validate-secrets.sh` reports invalid password hash

**Causes and solutions:**

**Cause 1**: Incorrect hash format
```bash
# Verify hash format
sops -d secrets/users.yaml | grep "password_hash"

# Expected SHA-512 format: $6$<16chars>$<86chars>
# Expected Bcrypt format: $2b$12$<53chars>

# If format wrong: Regenerate hash with mkpasswd
mkpasswd -m sha-512  # Or mkpasswd -m bcrypt
```

**Cause 2**: Hash truncated or malformed
```bash
# Check hash length
sops -d secrets/users.yaml | grep "password_hash" | wc -c

# SHA-512 should be ~106 characters (including $6$ prefix)
# Bcrypt should be ~60 characters (including $2b$ prefix)

# If too short: Hash was truncated during editing, regenerate
```

**Cause 3**: YAML quoting issues
```yaml
# Correct (quoted):
password_hash: "$6$salt$hash"

# Incorrect (unquoted - may be interpreted as comment):
password_hash: $6$salt$hash

# Fix: Always quote password hashes in YAML
```

### 10.3 NixOS Deployment Failures

**Symptom**: `nixos-rebuild switch` fails with secret-related errors

**Causes and solutions:**

**Cause 1**: Age key not deployed to system
```bash
# Check if age key exists on target system
ssh root@xmsi "ls -la /etc/sops/age/keys.txt"

# If missing: Deploy key manually
scp ~/.config/sops/age/keys.txt root@xmsi:/etc/sops/age/keys.txt
ssh root@xmsi "chmod 600 /etc/sops/age/keys.txt && chown root:root /etc/sops/age/keys.txt"
```

**Cause 2**: sops-nix configuration mismatch
```bash
# Verify sops-nix configuration in modules/nixos/secrets.nix
cat modules/nixos/secrets.nix | grep "sops.secrets"

# Ensure secret names match keys in secrets/*.yaml
sops -d secrets/users.yaml | grep "^  " | sed 's/://g'

# If mismatch: Update secrets.nix or secrets/*.yaml to align
```

**Cause 3**: Git changes not staged
```bash
# Nix flakes require files to be tracked by git
git status

# If secrets/*.yaml shows as modified but not staged:
git add secrets/*.yaml

# Retry rebuild
sudo nixos-rebuild switch --flake .#xmsi
```

### 10.4 Hetzner API Authentication Failures

**Symptom**: `just tf-plan` fails with authentication error

**Causes and solutions:**

**Cause 1**: Token format incorrect
```bash
# Verify token is exactly 64 characters
sops -d secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs | wc -c

# Expected: 65 (64 + newline)
# If different: Token incomplete or malformed, regenerate in Hetzner Console
```

**Cause 2**: Token extraction command fails
```bash
# Test token extraction manually
export TF_VAR_hcloud_token="$(sops -d ../secrets/hetzner.yaml | grep 'hcloud:' | cut -d: -f2 | xargs)"
echo "$TF_VAR_hcloud_token" | wc -c

# Expected: 65
# If error: Check SOPS decryption, yaml structure, extraction command
```

**Cause 3**: Token permissions insufficient
```bash
# Verify token has Read & Write permissions
# Access Hetzner Cloud Console → Security → API Tokens
# Check token permissions

# If Read-only: Create new token with Read & Write permissions
```

**Cause 4**: Token revoked in Hetzner Console
```bash
# Check if token still exists in Hetzner Console
# Navigate to: Security → API Tokens

# If deleted: Create new token, update secrets/hetzner.yaml
```

### 10.5 SSH Key Authentication Failures

**Symptom**: `ssh -i ~/.ssh/id_homelab_new user@server` fails with "Permission denied"

**Causes and solutions:**

**Cause 1**: Public key not deployed to server
```bash
# Check if public key exists in authorized_keys
ssh user@server "grep 'homelab-new' ~/.ssh/authorized_keys"

# If no output: Deploy public key
ssh-copy-id -i ~/.ssh/id_homelab_new.pub user@server
```

**Cause 2**: Private key permissions incorrect
```bash
# Check private key permissions
ls -la ~/.ssh/id_homelab_new

# Expected: -rw------- (600)
# If different: Fix permissions
chmod 600 ~/.ssh/id_homelab_new
```

**Cause 3**: SSH key format incompatible
```bash
# Verify key format
ssh-keygen -l -f ~/.ssh/id_homelab_new

# Expected: Shows key type (ED25519, RSA, etc.) and fingerprint
# If error: Key corrupted or wrong format, regenerate
```

**Cause 4**: Server sshd configuration restrictive
```bash
# Check server sshd_config
ssh user@server "sudo grep 'PubkeyAuthentication' /etc/ssh/sshd_config"

# Expected: PubkeyAuthentication yes
# If no: Enable in sshd_config and restart sshd
```

### 10.6 Age Key Re-encryption Failures

**Symptom**: `sops updatekeys` fails or secrets cannot be decrypted after rotation

**Causes and solutions:**

**Cause 1**: Old key not accessible during re-encryption
```bash
# Ensure both old and new keys accessible
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt:~/.config/sops/age/keys-new.txt

# Retry re-encryption
sops updatekeys secrets/hetzner.yaml
```

**Cause 2**: Public key in .sops.yaml incorrect
```bash
# Extract public key from new private key
age-keygen -y ~/.config/sops/age/keys-new.txt

# Compare with .sops.yaml
grep "age1" .sops.yaml

# If different: Update .sops.yaml with correct public key, retry updatekeys
```

**Cause 3**: Partial re-encryption (some files missed)
```bash
# Re-encrypt all secrets systematically
for secret in secrets/*.yaml; do
  echo "Re-encrypting $secret..."
  sops updatekeys "$secret" || echo "FAILED: $secret"
done

# Address any failures individually
```

**Cause 4**: SOPS version mismatch
```bash
# Check SOPS version
sops --version

# Expected: v3.8.0 or later (supports age encryption)
# If older: Update SOPS via nix development shell
nix develop
```

### 10.7 Validation Script Failures

**Symptom**: `scripts/validate-secrets.sh` fails with errors

**Causes and solutions:**

**Cause 1**: Missing dependencies (jq, sops)
```bash
# Ensure running in nix development shell
nix develop

# Verify tools available
which jq sops

# Expected: Paths to jq and sops binaries
```

**Cause 2**: Schema file missing or invalid
```bash
# Verify schema file exists
ls -la docs/schemas/secrets_schema.yaml

# Validate schema structure
head -20 docs/schemas/secrets_schema.yaml

# If missing or malformed: Restore from git
```

**Cause 3**: Temporary file cleanup issues
```bash
# Check for leftover temporary files
ls -la /tmp/*secrets* 2>/dev/null

# If exist: Remove manually
rm -f /tmp/*secrets*

# Retry validation
scripts/validate-secrets.sh
```

**Cause 4**: Secrets file encrypted with wrong key
```bash
# Verify age key can decrypt secrets
sops -d secrets/hetzner.yaml | head -3

# If fails: Check age key location and content
# May need to use correct key via SOPS_AGE_KEY_FILE
```

### 10.8 Git Commit Issues

**Symptom**: Cannot commit secrets or changes not detected

**Causes and solutions:**

**Cause 1**: .gitignore excludes secrets
```bash
# Check if secrets are ignored
git check-ignore secrets/hetzner.yaml

# Expected: No output (secrets should be committed)
# If output: Remove secrets/ from .gitignore (encrypted secrets should be committed)
```

**Cause 2**: Binary diff not showing changes
```bash
# Git diff may not show encrypted file changes clearly
git diff --stat secrets/

# Expected: Shows modified files
# To see actual binary diff:
git diff --binary secrets/hetzner.yaml
```

**Cause 3**: Pre-commit hooks blocking commit
```bash
# Check for pre-commit hooks
ls -la .git/hooks/pre-commit

# If exists: Review hook logic
# May need to update hook to allow encrypted secrets
```

### 10.9 Performance Issues

**Symptom**: Age key rotation takes excessively long (> 2 hours)

**Causes and solutions:**

**Cause 1**: Large number of secret files
```bash
# Count secret files
find secrets/ -name "*.yaml" | wc -l

# If > 20 files: Consider batch processing with parallel execution
find secrets/ -name "*.yaml" | parallel sops updatekeys {}
```

**Cause 2**: Network latency to NixOS systems
```bash
# Test network connectivity
for host in xmsi srv-01; do
  ping -c 3 $host
done

# If high latency: Consider parallel deployment
for host in xmsi srv-01; do
  (scp ~/.config/sops/age/keys-new.txt root@$host:/etc/sops/age/keys.txt && echo "$host done") &
done
wait
```

**Cause 3**: Large secret file sizes
```bash
# Check secret file sizes
ls -lh secrets/*.yaml

# If > 1MB per file: Consider splitting large secrets into multiple files
# Or: Use sops --in-place for faster updates
```

### 10.10 Common Error Messages

**Error**: `Failed to get the data key required to decrypt the SOPS file`

**Solution**: Age private key missing or incorrect. Check `~/.config/sops/age/keys.txt` or `SOPS_AGE_KEY_FILE`.

**Error**: `cannot unmarshal !!str` (YAML parsing error)

**Solution**: YAML syntax error in secrets file. Check quotes, indentation, special characters.

**Error**: `gpg: decryption failed: No secret key`

**Solution**: Project uses age encryption, not GPG. Ensure age key is configured, not GPG key.

**Error**: `permission denied (publickey)`

**Solution**: SSH key not deployed or wrong key being used. Verify `~/.ssh/authorized_keys` on server.

**Error**: `401 Unauthorized` (Hetzner API)

**Solution**: API token invalid or revoked. Generate new token in Hetzner Console.

**Error**: `activation script sops-install-secrets failed`

**Solution**: NixOS cannot decrypt secrets. Check `/etc/sops/age/keys.txt` exists and matches encrypted secrets.

---

## Appendix A: Quick Reference Commands

### SOPS Operations
```bash
# Edit encrypted secrets
sops secrets/hetzner.yaml

# View decrypted secrets (debugging only)
sops -d secrets/hetzner.yaml

# Re-encrypt with new age key
sops updatekeys secrets/hetzner.yaml

# Validate all secrets
scripts/validate-secrets.sh
```

### Password Generation
```bash
# SHA-512 password hash
mkpasswd -m sha-512

# Bcrypt password hash
mkpasswd -m bcrypt
```

### SSH Key Operations
```bash
# Generate Ed25519 key
ssh-keygen -t ed25519 -C "description" -f ~/.ssh/keyname

# Deploy public key
ssh-copy-id -i ~/.ssh/keyname.pub user@server

# Test key authentication
ssh -i ~/.ssh/keyname user@server whoami
```

### Age Key Operations
```bash
# Generate new age key
age-keygen -o ~/.config/sops/age/keys-new.txt

# Extract public key
age-keygen -y ~/.config/sops/age/keys-new.txt
```

### Deployment Commands
```bash
# NixOS rebuild
sudo nixos-rebuild switch --flake .#xmsi

# OpenTofu plan
just tf-plan

# Ansible ping
just ansible-ping
```

### Git Operations
```bash
# Stage secrets
git add secrets/*.yaml

# Commit with message
git commit -m "chore(secrets): rotate <secret-type>"

# Rollback to previous commit
git checkout HEAD~1 -- secrets/users.yaml
```

---

## Appendix B: Rotation Frequency Recommendations

| Secret Type          | Recommended Frequency | Minimum Frequency | Emergency Rotation |
|----------------------|------------------------|-------------------|-------------------|
| Age encryption keys  | Annually              | Every 2 years     | Immediately       |
| API tokens (Hetzner) | Every 90 days         | Every 6 months    | Within 1 hour     |
| User passwords       | Every 90 days         | Every 6 months    | Within 4 hours    |
| SSH keys             | Annually              | Every 2 years     | Within 24 hours   |
| PGP keys             | Every 2 years         | Every 5 years     | Within 48 hours   |

**Notes:**
- Emergency rotation timelines assume compromise is detected immediately
- Adjust frequencies based on:
  - Compliance requirements (e.g., PCI-DSS, SOC 2)
  - Risk assessment (high-value targets may require more frequent rotation)
  - Operational overhead (balance security with practicality)

---

## Appendix C: Contact Information

**In case of emergency:**
- **Security incident**: [Create incident report](docs/incidents/)
- **Team contact**: [Team communication channel]
- **On-call rotation**: [On-call schedule/contact]

**Resources:**
- SOPS documentation: https://github.com/mozilla/sops
- Age encryption: https://github.com/FiloSottile/age
- Hetzner Cloud API: https://docs.hetzner.cloud/
- NixOS sops-nix: https://github.com/Mic92/sops-nix

---

**Document version**: 1.0
**Last updated**: 2025-10-29
**Maintained by**: Infrastructure Team
**Review cycle**: Quarterly
