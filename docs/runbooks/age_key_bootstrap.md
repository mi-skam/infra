# Age Key Bootstrap Procedure

🔴 **CRITICAL SECURITY WARNING** 🔴

**NEVER commit age private keys (`keys.txt`) to version control. Always verify the key file is in `.gitignore` before committing any changes. A compromised age private key means ALL secrets are compromised.**

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Understanding Age Keys in This Project](#3-understanding-age-keys-in-this-project)
4. [Scenario 1: First-Time Operator Setup](#4-scenario-1-first-time-operator-setup)
5. [Scenario 2: Adding New Operator to Existing Infrastructure](#5-scenario-2-adding-new-operator-to-existing-infrastructure)
6. [Scenario 3: New NixOS System Bootstrap](#6-scenario-3-new-nixos-system-bootstrap)
7. [Scenario 4: Darwin (macOS) System Bootstrap](#7-scenario-4-darwin-macos-system-bootstrap)
8. [Key Backup Procedures](#8-key-backup-procedures)
9. [Testing and Verification](#9-testing-and-verification)
10. [Troubleshooting](#10-troubleshooting)
11. [Security Best Practices](#11-security-best-practices)
12. [Related Documentation](#12-related-documentation)

---

## 1. Overview

### Purpose

This runbook provides step-by-step procedures for bootstrapping age encryption keys for SOPS secrets management. Age keys are the foundation of secrets security in this infrastructure - they protect user passwords, API tokens, SSH keys, and all other sensitive data.

### When to Use This Runbook

- **First-time operator setup**: Setting up your workstation to work with encrypted secrets
- **Adding new operator**: Granting another team member access to secrets
- **New NixOS system**: Adding a new server that needs to decrypt secrets
- **New Darwin system**: Setting up age keys on macOS machines

### What Problem This Solves

NixOS and Darwin systems using sops-nix require an age private key to decrypt secrets during system activation. However, **age private keys are never stored in the git repository** for security reasons. This creates a "chicken-and-egg" problem: the system configuration references encrypted secrets, but cannot activate without the key to decrypt them.

This runbook documents the **manual bootstrap procedure** required to deploy age keys before first system activation.

### Security Model

- **Public keys** (age1...) are stored in `.sops.yaml` in git (safe to commit)
- **Private keys** (AGE-SECRET-KEY-1...) are NEVER committed to git
- **Multi-recipient encryption**: Multiple operators can decrypt the same secrets with their own keys
- **Manual deployment**: Keys must be manually copied to target systems (intentional security trade-off)

---

## 2. Prerequisites

### Required Access

- [x] Nix development shell access (`nix develop` or `direnv allow`)
- [x] SSH access to target systems (for remote deployment)
- [x] Git repository write access (for updating `.sops.yaml`)
- [x] Root/sudo access (for system-level key deployment)

### Required Tools

All tools are available in the nix development shell:

```bash
# Enter development shell
nix develop

# Or use direnv (recommended)
direnv allow
```

Tools included:
- `age` - Encryption key generation and management
- `age-keygen` - Key generation utility
- `sops` - Secrets editing and decryption
- `git` - Version control
- `ssh`, `scp` - Remote system access and file transfer

### Environment Setup

```bash
# Verify you're in the repository root
pwd
# Expected: /Users/plumps/Share/git/mi-skam/infra

# Verify age is available
which age age-keygen
# Expected: /nix/store/.../bin/age

# Verify SOPS is available
which sops
# Expected: /nix/store/.../bin/sops
```

---

## 3. Understanding Age Keys in This Project

### Age Key Anatomy

An age key pair consists of:

1. **Public key** (58 characters, starts with `age1`):
   ```
   age16uelq9w6kw6wt0e5srm3vu8nsf0zqjkc9esdv4mynslf0quw93vqdp2ksj
   ```
   - Safe to commit to git (stored in `.sops.yaml`)
   - Used by SOPS to encrypt secrets
   - Multiple public keys = multi-recipient encryption

2. **Private key** (AGE-SECRET-KEY format):
   ```
   # created: 2025-10-29T10:00:00Z
   # public key: age16uelq9w6kw6wt0e5srm3vu8nsf0zqjkc9esdv4mynslf0quw93vqdp2ksj
   AGE-SECRET-KEY-1ABCDEFGHIJKLMNOPQRSTUVWXYZ234567890ABCDEFGHIJKLMNOP
   ```
   - **NEVER commit to git** (extremely sensitive)
   - Used by SOPS to decrypt secrets
   - Must be deployed manually to target systems

### Age Key Locations by Platform

This project uses standardized locations for age private keys:

| Platform | Key Location | Owner | Permissions |
|----------|--------------|-------|-------------|
| **Operator workstation** (user key) | `~/.config/sops/age/keys.txt` | Current user | `600` (-rw-------) |
| **NixOS systems** (system key) | `/etc/sops/age/keys.txt` | `root:root` | `600` (-rw-------) |
| **Darwin systems** (system key) | `/opt/homebrew/etc/sops/age/keys.txt` | `root:wheel` | `600` (-rw-------) |

### How SOPS Finds Keys

SOPS searches for age private keys in this order (first found is used):

1. `$SOPS_AGE_KEY_FILE` environment variable (if set)
2. `~/.config/sops/age/keys.txt` (user key)
3. `/etc/sops/age/keys.txt` (system key)

This search order is defined in `scripts/validate-secrets.sh:17-33`.

### Multi-Recipient Encryption

This project uses **SOPS multi-recipient encryption**, which means:
- Multiple operators can decrypt the same secrets using their own age keys
- Each operator's public key is listed in `.sops.yaml`
- When secrets are edited, SOPS re-encrypts for all recipients
- Adding a new recipient requires `sops updatekeys` to re-encrypt existing secrets

**Example `.sops.yaml` with multiple recipients:**
```yaml
keys:
  - &operator1 age16uelq9w6kw6wt0e5srm3vu8nsf0zqjkc9esdv4mynslf0quw93vqdp2ksj
  - &operator2 age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *operator1
          - *operator2
```

---

## 4. Scenario 1: First-Time Operator Setup

**Use case**: You're setting up your workstation to work with this infrastructure for the first time.

**Estimated time**: 15-20 minutes

### 4.1 Generate Age Key Pair

**Step 1**: Create age key directory
```bash
mkdir -p ~/.config/sops/age
```

**Step 2**: Generate age key pair
```bash
age-keygen -o ~/.config/sops/age/keys.txt
```

**Expected output**:
```
Public key: age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

**IMPORTANT**: Copy this public key immediately - you'll need it for the next step.

**Step 3**: Secure the private key
```bash
chmod 600 ~/.config/sops/age/keys.txt
```

**Step 4**: Verify key generation
```bash
# Check file exists with correct permissions
ls -la ~/.config/sops/age/keys.txt

# Expected output:
# -rw------- 1 username group 184 Oct 29 10:00 /Users/username/.config/sops/age/keys.txt

# View key file (private key visible - never share this output)
cat ~/.config/sops/age/keys.txt

# Expected format:
# # created: 2025-10-29T10:00:00Z
# # public key: age1abc123...
# AGE-SECRET-KEY-1...
```

### 4.2 Extract Public Key for SOPS Configuration

**Step 5**: Extract public key for sharing
```bash
# Extract public key from private key file
age-keygen -y ~/.config/sops/age/keys.txt
```

**Expected output**:
```
age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

**This is your public key** - save it for adding to `.sops.yaml` (next scenario).

### 4.3 Backup Private Key (CRITICAL)

🔴 **BACKUP YOUR KEY NOW - Key loss = permanent secrets loss**

**Step 6**: Create encrypted backup (choose one method)

**Method A: Password Manager** (recommended)
- Copy contents of `~/.config/sops/age/keys.txt`
- Save as secure note in 1Password, Bitwarden, etc.
- Title: "Infrastructure Age Private Key - YYYY-MM-DD"

**Method B: Encrypted USB Drive**
```bash
# Encrypt key file with age (using passphrase)
age -p -o ~/Desktop/age-key-backup-$(date +%Y%m%d).age < ~/.config/sops/age/keys.txt

# You'll be prompted for a passphrase (use strong passphrase)
# Store the .age file on encrypted USB drive
# Delete ~/Desktop/age-key-backup-*.age after copying
```

**Method C: Paper Backup** (disaster recovery)
```bash
# Print key file for physical safe storage
cat ~/.config/sops/age/keys.txt | lpr

# Or save to PDF for printing:
cat ~/.config/sops/age/keys.txt > ~/Desktop/age-key-backup.txt
# Print ~/Desktop/age-key-backup.txt, store in safe
# Shred ~/Desktop/age-key-backup.txt after printing
```

🚫 **DO NOT**:
- Store unencrypted key in cloud storage (Dropbox, Google Drive, iCloud)
- Email key to yourself or others
- Share key in Slack, Discord, or other messaging platforms
- Commit key to any git repository (public or private)

---

## 5. Scenario 2: Adding New Operator to Existing Infrastructure

**Use case**: You've generated your age key and need to be added as a recipient to decrypt existing secrets.

**Estimated time**: 20-30 minutes

**Prerequisites**: You must have completed [Scenario 1](#4-scenario-1-first-time-operator-setup) and have your public key ready.

### 5.1 Provide Public Key to Existing Operator

**Step 1**: Extract your public key
```bash
# Your public key
age-keygen -y ~/.config/sops/age/keys.txt
```

**Step 2**: Send public key to existing operator via secure channel
- Slack/email is OK (public keys are safe to share)
- Format: "My age public key: age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"

### 5.2 Existing Operator: Add New Recipient to SOPS Configuration

**The following steps are performed by an existing operator with git write access.**

**Step 3**: Edit `.sops.yaml` configuration
```bash
vim .sops.yaml
# Or use your preferred editor
```

**Step 4**: Add new operator's public key
```yaml
# Before:
keys:
  - &mi-skam age16uelq9w6kw6wt0e5srm3vu8nsf0zqjkc9esdv4mynslf0quw93vqdp2ksj

# After:
keys:
  - &mi-skam age16uelq9w6kw6wt0e5srm3vu8nsf0zqjkc9esdv4mynslf0quw93vqdp2ksj
  - &new-operator age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz

creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *mi-skam
          - *new-operator  # Add this line
  - path_regex: secrets/.*\.json$
    key_groups:
      - age:
          - *mi-skam
          - *new-operator  # Add this line
```

**Step 5**: Re-encrypt all secrets for new recipient

**CRITICAL**: This step re-encrypts all secret files so the new operator can decrypt them.

```bash
# Re-encrypt each secret file
sops updatekeys secrets/hetzner.yaml
sops updatekeys secrets/storagebox.yaml

# Or batch re-encrypt all secrets
for file in secrets/*.yaml; do
  echo "Re-encrypting $file..."
  sops updatekeys "$file"
done
```

**Expected output for each file**:
```
The following changes will be made to the file's groups:
Group 1
	age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz

Is this okay? (y/n): y
```

**Note**: No output after typing "y" means success. The file is re-encrypted in place.

**Step 6**: Verify re-encryption succeeded
```bash
# Verify git shows encrypted changes
git diff secrets/hetzner.yaml

# Expected: Binary/encrypted diff (no plaintext visible)

# Verify secrets still decrypt with your existing key
sops -d secrets/hetzner.yaml | head -3

# Expected: Decrypted content displayed
```

**Step 7**: Commit changes
```bash
# Stage changes
git add .sops.yaml secrets/*.yaml

# Commit with descriptive message
git commit -m "feat(secrets): add new-operator as age recipient"

# Push to remote (if applicable)
git push
```

### 5.3 New Operator: Verify Access

**The following steps are performed by the new operator.**

**Step 8**: Pull latest changes
```bash
git pull
```

**Step 9**: Test decryption with new key
```bash
# Attempt to decrypt a secret file
sops -d secrets/hetzner.yaml

# Expected: Decrypted YAML content displayed
# If error "no key could decrypt the data": Re-encryption failed, contact existing operator
```

**Step 10**: Verify SOPS can edit secrets
```bash
# Open secret for editing (don't make changes, just verify)
sops secrets/hetzner.yaml

# Expected: Editor opens with decrypted content
# Exit without saving: Ctrl+X (nano) or :q (vim)
```

**Success indicator**: You can now decrypt and edit all secrets in the repository.

---

## 6. Scenario 3: New NixOS System Bootstrap

**Use case**: You're adding a new NixOS system (server or workstation) that needs to decrypt secrets during activation.

**Estimated time**: 15-25 minutes

**Prerequisites**:
- NixOS system is accessible via SSH
- You have root access to the target system
- Age private key exists on your operator workstation (`~/.config/sops/age/keys.txt`)

🔴 **CRITICAL REQUIREMENT**: Age private key MUST be deployed to `/etc/sops/age/keys.txt` BEFORE running `nixos-rebuild switch`. Otherwise, NixOS activation will fail with sops-nix decryption errors.

### 6.1 Prepare Target System

**Step 1**: Verify SSH access to target system
```bash
# Test SSH connection
ssh root@srv-02

# Expected: Successful login
# If fails: Check network, firewall rules, SSH key authentication
```

**Step 2**: Create age key directory on target system
```bash
ssh root@srv-02 "mkdir -p /etc/sops/age && chmod 755 /etc/sops/age"

# Verify directory created
ssh root@srv-02 "ls -ld /etc/sops/age"

# Expected output:
# drwxr-xr-x 2 root root 4096 Oct 29 10:00 /etc/sops/age
```

### 6.2 Deploy Age Private Key

**Step 3**: Copy age private key to target system

```bash
# Copy key from operator workstation to NixOS system
scp ~/.config/sops/age/keys.txt root@srv-02:/etc/sops/age/keys.txt
```

**Expected output**:
```
keys.txt                                    100%  184     5.2KB/s   00:00
```

**Step 4**: Set correct permissions on deployed key
```bash
# Set permissions to 600 (owner read/write only)
ssh root@srv-02 "chmod 600 /etc/sops/age/keys.txt"

# Set ownership to root
ssh root@srv-02 "chown root:root /etc/sops/age/keys.txt"
```

**Step 5**: Verify key deployment
```bash
# Check file permissions
ssh root@srv-02 "ls -la /etc/sops/age/keys.txt"

# Expected output:
# -rw------- 1 root root 184 Oct 29 10:00 /etc/sops/age/keys.txt

# Verify key file content (basic check)
ssh root@srv-02 "head -1 /etc/sops/age/keys.txt"

# Expected output:
# # created: 2025-10-29T10:00:00Z
```

### 6.3 Test Decryption Before System Activation

🔴 **CRITICAL**: Always test decryption BEFORE running `nixos-rebuild`. This saves time by catching key deployment issues early.

**Step 6**: Test SOPS decryption on target system
```bash
# Copy a secret file to target system for testing
scp secrets/hetzner.yaml root@srv-02:/tmp/test-secret.yaml

# Attempt decryption on target system
ssh root@srv-02 "sops -d /tmp/test-secret.yaml"

# Expected output: Decrypted YAML content
# If error "no key could decrypt the data": Key deployment failed, check Steps 3-5

# Clean up test file
ssh root@srv-02 "rm /tmp/test-secret.yaml"
```

**Alternative test** (if system configuration already references secrets):
```bash
# If NixOS configuration is already deployed (but not activated)
ssh root@srv-02 "sops -d /etc/nixos/secrets/users.yaml 2>&1 | head -5"

# Expected: Decrypted content or "file not found" (not a decryption error)
```

### 6.4 Deploy NixOS Configuration

**Step 7**: Deploy NixOS configuration with secrets

```bash
# From operator workstation, deploy to target system
nixos-rebuild switch --flake .#srv-02 --target-host root@srv-02

# Or if building locally on the target system:
ssh root@srv-02
cd /path/to/infra/repo
sudo nixos-rebuild switch --flake .#srv-02
```

**Expected output** (abbreviated):
```
building the system configuration...
activating the configuration...
setting up /etc...
reloading user units for mi-skam...
setting up /run/secrets...
installing secrets...
```

**Success indicators**:
- No errors about "failed to decrypt" or "no key could decrypt"
- Activation completes successfully
- Secrets deployed to `/run/secrets/` or `/run/secrets-for-users/`

**Step 8**: Verify secrets deployed correctly
```bash
# Check secret files exist
ssh root@srv-02 "ls -la /run/secrets-for-users/"

# Expected output:
# lrwxrwxrwx 1 root root 39 Oct 29 10:00 mi-skam -> /run/agenix.d/1/mi-skam
# lrwxrwxrwx 1 root root 39 Oct 29 10:00 plumps -> /run/agenix.d/1/plumps

# Verify secret content (check it decrypted correctly)
ssh root@srv-02 "cat /run/secrets-for-users/mi-skam | head -c 10"

# Expected output: Password hash prefix (e.g., "$6$" or "$2b$")
```

### 6.5 Security Cleanup

**Step 9**: Verify key is not accessible to non-root users
```bash
# Attempt to read key as non-root user (should fail)
ssh mi-skam@srv-02 "cat /etc/sops/age/keys.txt"

# Expected output: Permission denied
# If succeeds: Permissions incorrect, re-run Step 4
```

**Step 10**: Document deployment
```bash
# Add note to commit message or infrastructure documentation
# Example: "Deployed age key to srv-02 on 2025-10-29"
```

---

## 7. Scenario 4: Darwin (macOS) System Bootstrap

**Use case**: You're setting up age keys on a macOS system (Darwin) using nix-darwin.

**Estimated time**: 15-20 minutes

**Prerequisites**:
- Darwin (macOS) system with nix-darwin installed
- Homebrew installed (`/opt/homebrew` on Apple Silicon, `/usr/local` on Intel)
- Root/sudo access

**Key difference from NixOS**: Darwin systems use `/opt/homebrew/etc/sops/age/keys.txt` (Homebrew prefix) instead of `/etc/sops/age/keys.txt`.

### 7.1 Create Age Key Directory

**Step 1**: Create Homebrew age key directory
```bash
# For Apple Silicon Macs (M1/M2/M3)
sudo mkdir -p /opt/homebrew/etc/sops/age

# For Intel Macs
sudo mkdir -p /usr/local/etc/sops/age
```

**Step 2**: Set directory permissions
```bash
# Apple Silicon
sudo chmod 755 /opt/homebrew/etc/sops/age

# Intel
sudo chmod 755 /usr/local/etc/sops/age
```

### 7.2 Deploy Age Private Key

**Step 3**: Copy age key to system location

**If this is your current workstation** (key already exists at `~/.config/sops/age/keys.txt`):
```bash
# Copy user key to system location (Apple Silicon)
sudo cp ~/.config/sops/age/keys.txt /opt/homebrew/etc/sops/age/keys.txt

# Intel Macs
sudo cp ~/.config/sops/age/keys.txt /usr/local/etc/sops/age/keys.txt
```

**If deploying to a remote Darwin system**:
```bash
# Copy from operator workstation to remote Mac
scp ~/.config/sops/age/keys.txt username@mac-hostname:/tmp/keys.txt

# SSH to remote Mac and move to system location
ssh username@mac-hostname
sudo mv /tmp/keys.txt /opt/homebrew/etc/sops/age/keys.txt
```

**Step 4**: Set correct permissions
```bash
# Apple Silicon
sudo chmod 600 /opt/homebrew/etc/sops/age/keys.txt
sudo chown root:wheel /opt/homebrew/etc/sops/age/keys.txt

# Intel
sudo chmod 600 /usr/local/etc/sops/age/keys.txt
sudo chown root:wheel /usr/local/etc/sops/age/keys.txt
```

**Step 5**: Verify deployment
```bash
# Check permissions (Apple Silicon example)
ls -la /opt/homebrew/etc/sops/age/keys.txt

# Expected output:
# -rw------- 1 root wheel 184 Oct 29 10:00 /opt/homebrew/etc/sops/age/keys.txt
```

### 7.3 Test Decryption

**Step 6**: Test SOPS can decrypt with system key
```bash
# Test decryption (SOPS should auto-detect system key location)
sops -d secrets/hetzner.yaml | head -3

# Expected: Decrypted YAML content

# If error: Check key file location and permissions
```

### 7.4 Deploy Darwin Configuration

**Step 7**: Build and activate Darwin configuration
```bash
# Build configuration (dry-run)
darwin-rebuild build --flake .#xbook

# Expected: Build succeeds, no sops-nix errors

# Activate configuration
darwin-rebuild switch --flake .#xbook
```

**Expected output** (abbreviated):
```
building the system configuration...
activating the configuration...
setting up /etc...
installing secrets...
```

**Step 8**: Verify secrets deployed
```bash
# Check if secrets are accessible
sops -d secrets/users.yaml | head -5

# Expected: Decrypted content
```

### 7.5 Maintain User Key (Optional but Recommended)

**Best practice**: Keep both user key (`~/.config/sops/age/keys.txt`) and system key (`/opt/homebrew/etc/sops/age/keys.txt`) on Darwin systems.

**Rationale**:
- **User key**: For editing secrets as your user account
- **System key**: For nix-darwin activation (root-level operations)

**Step 9**: Verify user key exists
```bash
ls -la ~/.config/sops/age/keys.txt

# If missing: Follow Scenario 1 to create user key
# Or copy system key to user location:
sudo cp /opt/homebrew/etc/sops/age/keys.txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

---

## 8. Key Backup Procedures

🔴 **CRITICAL**: Age private key loss = permanent secrets loss. No recovery is possible without the key or a backup.

### 8.1 Backup Methods (Choose Multiple)

**Method 1: Password Manager (Primary Backup)**

Recommended for: Daily access, secure storage, cross-device sync

**Steps**:
1. Open your password manager (1Password, Bitwarden, etc.)
2. Create new secure note titled "Infrastructure Age Private Key"
3. Copy entire contents of `~/.config/sops/age/keys.txt`
4. Paste into secure note
5. Add tags: "age-key", "infrastructure", "critical"
6. Add metadata: Date generated, systems using this key

**Verify**:
```bash
# Verify you can retrieve the key from password manager
# Copy from password manager, save to /tmp/test-key.txt
diff ~/.config/sops/age/keys.txt /tmp/test-key.txt
rm /tmp/test-key.txt

# Expected: No differences
```

**Method 2: Encrypted USB Drive (Offline Backup)**

Recommended for: Disaster recovery, offline storage

**Steps**:
```bash
# Encrypt key with age using passphrase
age -p -o ~/Desktop/age-key-backup-$(date +%Y%m%d).age < ~/.config/sops/age/keys.txt

# You'll be prompted for passphrase:
# Enter passphrase (leave empty to autogenerate a secure one): [use strong passphrase]
# Confirm passphrase: [repeat passphrase]

# Copy encrypted file to USB drive
cp ~/Desktop/age-key-backup-*.age /Volumes/USBDrive/

# Verify copy succeeded
diff ~/Desktop/age-key-backup-*.age /Volumes/USBDrive/age-key-backup-*.age

# Delete from Desktop (keep only on USB)
rm ~/Desktop/age-key-backup-*.age
```

**Verify backup** (test decryption):
```bash
# Test decrypt from USB backup
age -d /Volumes/USBDrive/age-key-backup-$(date +%Y%m%d).age

# Enter passphrase when prompted
# Expected output: Key file contents displayed
```

**Method 3: Paper Backup (Disaster Recovery)**

Recommended for: Ultimate disaster recovery (fire, ransomware, total device loss)

**Steps**:
```bash
# Option A: Print directly
cat ~/.config/sops/age/keys.txt | lpr

# Option B: Save to temporary file for printing
cat ~/.config/sops/age/keys.txt > ~/Desktop/age-key-print.txt

# Print ~/Desktop/age-key-print.txt

# After printing, SECURELY DELETE temporary file
shred -vfz -n 10 ~/Desktop/age-key-print.txt
# Or on macOS without shred:
rm -P ~/Desktop/age-key-print.txt
```

**Storage**:
- Place in sealed envelope labeled "Infrastructure Age Key - DO NOT DISCARD"
- Store in fireproof safe or bank safety deposit box
- Add note: "Decrypt with: age -d -i /path/to/this/key secrets/*.yaml"

**Method 4: Secure Team Shared Storage** (Multi-Operator Environments)

Recommended for: Team environments with shared responsibility

**Options**:
- **HashiCorp Vault**: Store in KV secrets engine with access policies
- **Team password manager**: 1Password Teams, Bitwarden Organizations (shared vault)
- **Encrypted git repository**: Separate private repo with encrypted backup (age-encrypted with different key)

**Not recommended**:
- Shared Dropbox/Google Drive folder (unencrypted)
- Team wiki or documentation (visible to too many people)
- Email distribution to team members (insecure transmission)

### 8.2 Backup Verification Checklist

After creating backups, verify:

```markdown
## Age Key Backup Verification

**Date**: YYYY-MM-DD
**Key generated**: YYYY-MM-DD
**Backups created**:

- [ ] Password manager backup
  - [ ] Key contents copied correctly (diff verified)
  - [ ] Can retrieve from password manager
  - [ ] Metadata added (date, purpose, systems)

- [ ] Encrypted USB backup
  - [ ] Encrypted with strong passphrase
  - [ ] Passphrase stored separately (not on USB)
  - [ ] Decryption test successful
  - [ ] USB stored in secure location

- [ ] Paper backup
  - [ ] Printed clearly (readable)
  - [ ] Temporary files securely deleted (shredded)
  - [ ] Stored in fireproof safe/deposit box
  - [ ] Location documented (but not with key)

- [ ] Team shared storage (if applicable)
  - [ ] Appropriate access controls configured
  - [ ] Audit logging enabled
  - [ ] Team members notified

**Recovery test date**: YYYY-MM-DD (test annually)
```

### 8.3 Key Recovery Testing

**Test key recovery annually** to ensure backups are functional:

```bash
# Step 1: Rename current key (don't delete yet)
mv ~/.config/sops/age/keys.txt ~/.config/sops/age/keys-original.txt

# Step 2: Restore from backup (choose one method)

# From password manager:
# - Copy key from password manager
# - Save to ~/.config/sops/age/keys.txt
# - chmod 600 ~/.config/sops/age/keys.txt

# From encrypted USB:
age -d /Volumes/USBDrive/age-key-backup-*.age > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# From paper backup:
# - Type key contents into ~/.config/sops/age/keys.txt (carefully)
# - chmod 600 ~/.config/sops/age/keys.txt

# Step 3: Test decryption with restored key
sops -d secrets/hetzner.yaml | head -3

# Expected: Successful decryption

# Step 4: Verify restored key matches original
diff ~/.config/sops/age/keys.txt ~/.config/sops/age/keys-original.txt

# Expected: No differences

# Step 5: Clean up
rm ~/.config/sops/age/keys-original.txt
```

---

## 9. Testing and Verification

After deploying an age key (any scenario), verify it works correctly before relying on it.

### 9.1 Test Suite: Operator Workstation

**Test 1**: Verify key file exists and has correct permissions
```bash
ls -la ~/.config/sops/age/keys.txt

# Expected output:
# -rw------- 1 username group 184 Oct 29 10:00 /Users/username/.config/sops/age/keys.txt
```

**Test 2**: Extract public key from private key
```bash
age-keygen -y ~/.config/sops/age/keys.txt

# Expected output:
# age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
# (58-character string starting with "age1")
```

**Test 3**: Decrypt secrets with SOPS
```bash
# Test decryption
sops -d secrets/hetzner.yaml

# Expected output: Decrypted YAML content
# hcloud: "AbCdEf1234567890..."

# If error "no key could decrypt the data":
# - Public key not in .sops.yaml (run Scenario 2)
# - Secrets not re-encrypted for your key (contact existing operator)
```

**Test 4**: Edit secrets with SOPS
```bash
# Open secret for editing (don't make changes)
sops secrets/hetzner.yaml

# Expected: Editor opens with decrypted content
# Exit without saving: Ctrl+X or :q
```

**Test 5**: Verify public key matches .sops.yaml
```bash
# Extract your public key
YOUR_PUBKEY=$(age-keygen -y ~/.config/sops/age/keys.txt)

# Check if it's in .sops.yaml
grep "$YOUR_PUBKEY" .sops.yaml

# Expected output: Line containing your public key
# If no output: Your public key not in .sops.yaml (run Scenario 2)
```

### 9.2 Test Suite: NixOS System

**Test 1**: Verify age key file exists on system
```bash
ssh root@srv-02 "ls -la /etc/sops/age/keys.txt"

# Expected output:
# -rw------- 1 root root 184 Oct 29 10:00 /etc/sops/age/keys.txt
```

**Test 2**: Test SOPS decryption on system
```bash
# Copy test secret to system
scp secrets/hetzner.yaml root@srv-02:/tmp/test.yaml

# Decrypt on system
ssh root@srv-02 "sops -d /tmp/test.yaml"

# Expected: Decrypted content
# Clean up
ssh root@srv-02 "rm /tmp/test.yaml"
```

**Test 3**: Verify sops-nix deployed secrets correctly
```bash
# Check secrets directory exists
ssh root@srv-02 "ls -la /run/secrets-for-users/"

# Expected output:
# lrwxrwxrwx 1 root root 39 Oct 29 10:00 mi-skam -> /run/agenix.d/1/mi-skam
# (Symbolic links to decrypted secrets)

# Verify secret content
ssh root@srv-02 "cat /run/secrets-for-users/mi-skam | head -c 10"

# Expected: Password hash prefix (e.g., "$6$" or "$2b$")
```

**Test 4**: Test NixOS rebuild succeeds
```bash
# Dry-run rebuild (doesn't activate, just builds)
ssh root@srv-02 "cd /etc/nixos && nixos-rebuild build --flake .#srv-02"

# Expected: Build succeeds with no sops-nix errors
```

**Test 5**: Verify non-root users cannot access key
```bash
# Attempt to read key as non-root user
ssh mi-skam@srv-02 "cat /etc/sops/age/keys.txt"

# Expected output: Permission denied
# If succeeds: Permissions incorrect, key is compromised
```

### 9.3 Test Suite: Darwin System

**Test 1**: Verify age key file exists (system location)
```bash
# Apple Silicon
ls -la /opt/homebrew/etc/sops/age/keys.txt

# Intel
ls -la /usr/local/etc/sops/age/keys.txt

# Expected output:
# -rw------- 1 root wheel 184 Oct 29 10:00 /opt/homebrew/etc/sops/age/keys.txt
```

**Test 2**: Test SOPS decryption
```bash
sops -d secrets/hetzner.yaml | head -3

# Expected: Decrypted content
```

**Test 3**: Test darwin-rebuild succeeds
```bash
# Dry-run rebuild
darwin-rebuild build --flake .#xbook

# Expected: Build succeeds with no sops-nix errors
```

**Test 4**: Verify user key also exists (optional but recommended)
```bash
ls -la ~/.config/sops/age/keys.txt

# Expected: File exists with 600 permissions
# If missing: Not critical for system operation, but useful for editing secrets
```

### 9.4 Validation Script

Run the automated secrets validation script:

```bash
# Run validation script
scripts/validate-secrets.sh

# Expected output:
# Infrastructure Secrets Validation
#
# ℹ Starting validation...
#
# ℹ Validating: hetzner.yaml
# ✓   All checks passed
# ℹ Validating: storagebox.yaml
# ✓   All checks passed
#
# Validation Summary
# ─────────────────────────────────────
# ✓ All secrets validated successfully
```

**If validation fails**:
- Check age key location and permissions
- Verify SOPS can decrypt secrets manually
- See [Troubleshooting](#10-troubleshooting) section

---

## 10. Troubleshooting

### 10.1 Error: "no key could decrypt the data"

**Symptom**: `sops -d secrets/file.yaml` fails with:
```
Failed to get the data key required to decrypt the SOPS file.

Group 1: FAILED
  age16uelq9w6kw6wt0e5srm3vu8nsf0zqjkc9esdv4mynslf0quw93vqdp2ksj: FAILED
    - | no key could decrypt the data
```

**Cause 1**: Age private key not accessible

**Solution**:
```bash
# Verify key file exists
ls -la ~/.config/sops/age/keys.txt
ls -la /etc/sops/age/keys.txt

# If missing: Restore from backup or deploy from operator workstation
# See Scenario 1 or Scenario 3
```

**Cause 2**: Public key mismatch (wrong key encrypted secrets)

**Solution**:
```bash
# Extract public key from your private key
age-keygen -y ~/.config/sops/age/keys.txt

# Check if it matches .sops.yaml
grep "age1" .sops.yaml

# If different: Your key is not authorized to decrypt
# Contact existing operator to add you as recipient (Scenario 2)
```

**Cause 3**: Secrets encrypted for different key

**Solution**:
```bash
# Check SOPS_AGE_KEY_FILE environment variable
echo $SOPS_AGE_KEY_FILE

# If set to wrong key: Unset or correct it
unset SOPS_AGE_KEY_FILE

# Retry decryption
sops -d secrets/hetzner.yaml
```

### 10.2 Error: Permission Denied (Key File)

**Symptom**: `sops` fails with "permission denied" when accessing key file

**Cause**: Incorrect file permissions on age private key

**Solution**:
```bash
# Fix permissions on key file
chmod 600 ~/.config/sops/age/keys.txt

# Verify permissions
ls -la ~/.config/sops/age/keys.txt

# Expected: -rw------- (owner read/write only)

# For system keys (NixOS):
ssh root@hostname "chmod 600 /etc/sops/age/keys.txt"
ssh root@hostname "chown root:root /etc/sops/age/keys.txt"

# For system keys (Darwin):
sudo chmod 600 /opt/homebrew/etc/sops/age/keys.txt
sudo chown root:wheel /opt/homebrew/etc/sops/age/keys.txt
```

### 10.3 NixOS Rebuild Fails with "activation script sops-install-secrets failed"

**Symptom**: `nixos-rebuild switch` fails during activation:
```
error: activation script 'sops-install-secrets' failed (exit code 1)
```

**Cause**: Age private key not deployed to `/etc/sops/age/keys.txt` before activation

**Solution**:
```bash
# Step 1: Deploy age key manually (Scenario 3)
scp ~/.config/sops/age/keys.txt root@hostname:/etc/sops/age/keys.txt
ssh root@hostname "chmod 600 /etc/sops/age/keys.txt && chown root:root /etc/sops/age/keys.txt"

# Step 2: Verify decryption works
ssh root@hostname "sops -d /tmp/test-secret.yaml"

# Step 3: Retry NixOS rebuild
nixos-rebuild switch --flake .#hostname --target-host root@hostname
```

### 10.4 Key File Exists but Decryption Still Fails

**Symptom**: Key file exists with correct permissions, but SOPS still cannot decrypt

**Cause 1**: Key file corrupted or incomplete

**Solution**:
```bash
# Verify key file format
head -1 ~/.config/sops/age/keys.txt

# Expected output:
# # created: 2025-10-29T10:00:00Z

# Check key file has 3 lines
wc -l ~/.config/sops/age/keys.txt

# Expected: 3 lines (header comments + private key)

# If corrupted: Restore from backup
```

**Cause 2**: Wrong key deployed (public key instead of private key)

**Solution**:
```bash
# Check if key file contains private key
grep "AGE-SECRET-KEY-1" ~/.config/sops/age/keys.txt

# Expected: AGE-SECRET-KEY-1... (private key)
# If no output: File contains public key instead of private key
# Deploy correct private key from backup
```

### 10.5 Darwin: Key Deployed but darwin-rebuild Fails

**Symptom**: Darwin rebuild fails with sops-nix errors even after deploying key

**Cause**: Key deployed to wrong location (NixOS path instead of Darwin path)

**Solution**:
```bash
# Verify key at correct Darwin location
# Apple Silicon:
ls -la /opt/homebrew/etc/sops/age/keys.txt

# Intel:
ls -la /usr/local/etc/sops/age/keys.txt

# If missing: Deploy to correct location (Scenario 4)

# Check modules/darwin/secrets.nix for expected path
grep "keyFile" modules/darwin/secrets.nix

# Expected output:
# age.keyFile = "/opt/homebrew/etc/sops/age/keys.txt";
```

### 10.6 Multiple Operators: Cannot Decrypt After updatekeys

**Symptom**: After adding new operator with `sops updatekeys`, original operator can still decrypt but new operator cannot

**Cause**: `sops updatekeys` completed for some files but not all

**Solution**:
```bash
# Existing operator: Re-run updatekeys for ALL secret files
for file in secrets/*.yaml secrets/*.json; do
  echo "Re-encrypting $file..."
  sops updatekeys "$file"
done

# Verify all files updated
git status secrets/

# Expected: All secret files show as modified

# Commit changes
git add secrets/
git commit -m "fix(secrets): re-encrypt all secrets for new recipient"
git push

# New operator: Pull and test
git pull
sops -d secrets/hetzner.yaml
```

### 10.7 Lost Age Private Key

**Symptom**: Age private key deleted, no backup available

**Impact**: 🔴 **CRITICAL** - All secrets are permanently inaccessible

**Recovery Options**:

**Option 1**: Restore from backup (if available)
- Password manager backup (Scenario 8.1)
- Encrypted USB backup
- Paper backup
- Team shared storage

**Option 2**: If no backup exists and this is the ONLY key:
1. **All secrets are lost** - no recovery possible with age encryption
2. Must regenerate all secrets:
   - New age key pair (Scenario 1)
   - New Hetzner API token (regenerate in Hetzner Console)
   - New user passwords (generate new password hashes)
   - New SSH keys (generate new key pairs)
3. Update all systems with new secrets
4. Update `.sops.yaml` with new age public key
5. Re-encrypt all secret files with new key

**Option 3**: If other operators have age keys (multi-recipient):
1. Contact another operator who can decrypt secrets
2. Generate new age key pair (Scenario 1)
3. Have other operator add you as recipient (Scenario 2)
4. Other operator runs `sops updatekeys` to re-encrypt for you
5. Pull updated secrets and verify decryption

**Prevention**: **ALWAYS maintain multiple backups** (see Scenario 8)

### 10.8 Git Refuses to Stage Secrets (Security Warning)

**Symptom**: `git add secrets/` triggers pre-commit hook warning or error about secrets

**Cause**: Pre-commit hook detecting potential secret leak (over-aggressive detection)

**Solution**:
```bash
# Verify files are encrypted
file secrets/hetzner.yaml

# Expected: "data" or "binary" (encrypted)
# If "ASCII text": File is NOT encrypted - DO NOT COMMIT

# If files are encrypted, override hook (one-time)
git add secrets/ --no-verify

# Or update pre-commit hook to allow encrypted SOPS files
# Edit .git/hooks/pre-commit to exclude *.yaml files with SOPS encryption markers
```

---

## 11. Security Best Practices

### 11.1 Key Generation

✅ **DO**:
- Generate keys on secure, trusted systems (your encrypted workstation)
- Use `age-keygen` (official tool) for key generation
- Immediately backup keys after generation (multiple methods)
- Set `600` permissions on private keys immediately after creation

🚫 **DO NOT**:
- Generate keys on shared systems or untrusted networks
- Use online key generators or web-based tools
- Generate keys without immediately backing them up
- Leave keys with default permissions (potentially world-readable)

### 11.2 Key Storage

✅ **DO**:
- Store private keys with `600` permissions (owner read/write only)
- Use full-disk encryption on systems storing keys (FileVault, LUKS)
- Store backups encrypted (password manager, age-encrypted USB)
- Maintain multiple backup locations (password manager + USB + paper)

🚫 **DO NOT**:
- Store unencrypted keys in cloud storage (Dropbox, Google Drive, iCloud)
- Email keys (even to yourself)
- Store keys in git repositories (public or private)
- Store keys with permissions > `600` (group/other readable)

### 11.3 Key Transmission

✅ **DO**:
- Transmit private keys over encrypted channels only (SSH/SCP)
- Verify recipient before sharing keys (even in encrypted form)
- Use secure methods for backup encryption (age with passphrase, password manager)

🚫 **DO NOT**:
- Transmit keys over unencrypted channels (HTTP, FTP, plain email)
- Share keys in team chat (Slack, Discord, Teams) even in DMs
- Share keys via physical media without encryption (USB drives)
- Share private keys when public keys would suffice

### 11.4 Key Lifecycle

✅ **DO**:
- Rotate age keys annually or after suspected compromise
- Test key backups annually (recovery drill)
- Remove old keys from systems after rotation completes
- Document key generation, deployment, and rotation in git commits

🚫 **DO NOT**:
- Reuse age keys across multiple unrelated projects
- Keep old keys accessible after rotation (except encrypted backups)
- Skip testing backups (assume backups work without verification)
- Forget to re-encrypt secrets after adding new recipients

### 11.5 Access Control

✅ **DO**:
- Limit age key access to minimum required personnel (least privilege)
- Use separate age keys for different environments (prod/dev) if required by policy
- Audit who has age keys (maintain list of operators with public keys)
- Remove operator access when team members leave (Scenario 2 in reverse)

🚫 **DO NOT**:
- Share age keys with contractors without proper vetting
- Grant age key access to automated systems (prefer scoped service accounts)
- Allow age keys on developer workstations without full-disk encryption

### 11.6 Incident Response

✅ **DO**:
- Have documented key rotation procedure (see `docs/runbooks/secrets_rotation.md`)
- Know how to quickly rotate all secrets if key compromised
- Practice emergency rotation procedure (annual drill)
- Document incidents involving age keys (postmortem)

🚫 **DO NOT**:
- Delay rotation after suspected compromise (rotate immediately)
- Skip rotation steps to save time (follow procedure completely)
- Forget to rotate secrets along with age key (both must be rotated)

---

## 12. Related Documentation

### Infrastructure Documentation

- **[CLAUDE.md](../../CLAUDE.md)** - Main project documentation, SOPS usage overview
- **[secrets_rotation.md](./secrets_rotation.md)** - Procedures for rotating age keys and other secrets
- **[GETTING_STARTED.md](../../GETTING_STARTED.md)** - Initial setup guide (references this runbook)

### Configuration Files

- **[.sops.yaml](../../.sops.yaml)** - SOPS configuration with age public keys
- **[modules/nixos/secrets.nix](../../modules/nixos/secrets.nix)** - NixOS sops-nix configuration (key location: `/etc/sops/age/keys.txt`)
- **[modules/darwin/secrets.nix](../../modules/darwin/secrets.nix)** - Darwin sops-nix configuration (key location: `/opt/homebrew/etc/sops/age/keys.txt`)

### Scripts and Schemas

- **[scripts/validate-secrets.sh](../../scripts/validate-secrets.sh)** - Automated secrets validation (tests age key accessibility)
- **[docs/schemas/secrets_schema.yaml](../schemas/secrets_schema.yaml)** - JSON schema for secrets validation

### External Resources

- **SOPS Documentation**: https://github.com/mozilla/sops
- **Age Encryption**: https://github.com/FiloSottile/age
- **sops-nix Integration**: https://github.com/Mic92/sops-nix

### Operational Procedures

When you need to:
- **Rotate an age key after compromise**: See `docs/runbooks/secrets_rotation.md` Section 6
- **Add a new operator to decrypt secrets**: See Scenario 2 in this runbook
- **Add a new NixOS system**: See Scenario 3 in this runbook
- **Troubleshoot decryption issues**: See Section 10 in this runbook

---

## Appendix: Quick Reference Commands

### Key Generation
```bash
# Generate new age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Extract public key from private key
age-keygen -y ~/.config/sops/age/keys.txt
```

### Key Deployment (NixOS)
```bash
# Deploy to NixOS system
scp ~/.config/sops/age/keys.txt root@hostname:/etc/sops/age/keys.txt
ssh root@hostname "chmod 600 /etc/sops/age/keys.txt && chown root:root /etc/sops/age/keys.txt"
```

### Key Deployment (Darwin)
```bash
# Deploy to Darwin system (Apple Silicon)
sudo cp ~/.config/sops/age/keys.txt /opt/homebrew/etc/sops/age/keys.txt
sudo chmod 600 /opt/homebrew/etc/sops/age/keys.txt
sudo chown root:wheel /opt/homebrew/etc/sops/age/keys.txt
```

### Testing
```bash
# Test decryption
sops -d secrets/hetzner.yaml

# Run validation script
scripts/validate-secrets.sh

# Test on remote system
ssh root@hostname "sops -d /tmp/test.yaml"
```

### Adding New Recipient
```bash
# Edit SOPS configuration
vim .sops.yaml

# Re-encrypt all secrets
for file in secrets/*.yaml; do sops updatekeys "$file"; done

# Commit changes
git add .sops.yaml secrets/
git commit -m "feat(secrets): add new-operator as age recipient"
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-29
**Maintained By**: Infrastructure Team
**Review Cycle**: Quarterly or after any age key-related incidents
