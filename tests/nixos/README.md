# NixOS VM Tests

## Purpose
This directory contains NixOS VM tests that validate system configurations from the hosts/ directory using the nixosTest framework.

## Contents
- VM tests for each host configuration (xmsi, srv-01)
- Integration tests for multi-host scenarios
- Tests for common modules (desktop, server, plasma)
- Secrets mounting and SOPS decryption tests

## Usage
NixOS tests are executed with:
```bash
nix build .#checks.x86_64-linux.test-name
# or
nix flake check
```

Tests verify:
- System boots successfully
- Required services start and respond
- Secrets are properly decrypted and mounted
- SSH access works with configured keys
- Network configuration is correct

## Standards
- Use nixosTest framework from nixpkgs
- Test one concern per test file
- Include assertions for critical functionality
- Use descriptive test names (test-xmsi-desktop.nix)
- Verify both service status and actual functionality
