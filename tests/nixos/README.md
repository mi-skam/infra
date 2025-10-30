# NixOS VM Tests

## Purpose
This directory contains NixOS VM tests that validate system configurations using the nixosTest framework. Tests run in isolated QEMU VMs to verify critical functionality without affecting running systems.

## Implemented Tests

### xmsi-test.nix
Tests the xmsi desktop configuration critical path:
- System boots to multi-user.target
- User mi-skam exists with wheel group membership
- SSH service runs and listens on port 22
- SOPS secrets decrypt successfully
- Network stack is functional

### srv-01-test.nix
Tests the srv-01 server configuration critical path:
- System boots to multi-user.target
- Both users (mi-skam and plumps) exist with wheel group
- SSH service runs and listens on port 22
- SOPS secrets decrypt for both users
- No display manager running (negative test for server config)
- Network stack is functional

## Running Tests

### Via justfile (recommended):
```bash
just test-nixos
```
This runs both tests and provides formatted output. Automatically skips on non-x86_64-linux platforms.

### Via nix commands:
```bash
# Run all checks (includes tests)
nix flake check

# Build specific test
nix build .#checks.x86_64-linux.xmsi-test
nix build .#checks.x86_64-linux.srv-01-test

# Build with logs
nix build .#checks.x86_64-linux.xmsi-test --print-build-logs
```

## Test Design

### Approach
Tests import core modules directly (users, secrets, srvos.common) rather than full host configurations. This avoids desktop module complexity in headless VM tests while still validating critical functionality.

### Why Not Full Host Configurations?
Full host configurations (especially xmsi with KDE Plasma) include desktop environment modules that:
- Require graphical display not available in headless VMs
- Add complexity and build time
- Are not critical path for infrastructure validation

The tests focus on "will the system boot and be accessible?" rather than "does every package work?".

### Test Coverage
Tests validate the acceptance criteria from the testing strategy:
- ✅ System boots to multi-user target
- ✅ Users exist with correct groups
- ✅ SSH daemon starts and listens
- ✅ Secrets decrypt successfully
- ✅ Network configuration works
- ⚠️  Desktop environment tests skipped (headless VM limitation)
- ⚠️  External network tests use loopback only (isolated VM)

## Implementation Notes

### SOPS in Tests
Tests use the project's test fixtures (secrets/users.yaml) which contain encrypted placeholder data. The SOPS module handles decryption automatically in the VM.

### Module Imports
Tests use `pkgs.testers.runNixOSTest` (modern API) and import:
- `(modulesPath + "/profiles/minimal.nix")` - Base NixOS minimal profile
- `inputs.srvos.nixosModules.common` - Common server configuration
- `inputs.sops-nix.nixosModules.sops` - Secrets management
- User modules (mi-skam.nix, plumps.nix)
- Secrets module (secrets.nix)

### Performance
Tests complete in approximately 2-5 minutes total (both tests). VM memory is limited:
- xmsi: 2GB RAM, 2 cores
- srv-01: 1GB RAM, 2 cores

## Standards
- Use `pkgs.testers.runNixOSTest` framework
- Test critical path only (boot, users, SSH, secrets)
- One configuration per test file
- Descriptive test names matching host names
- Include clear print statements for test progress
- Verify both service status and actual functionality
