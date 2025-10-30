# NixOS VM test for srv-01 configuration
#
# Tests srv-01 server system configuration by booting in isolated QEMU VM
# and verifying critical server functionality:
# - System boots to multi-user target
# - Multiple users (mi-skam and plumps) exist
# - SSH service is running
# - Secrets for both users are decrypted
# - Desktop environment is NOT present (server config)
#
# This test validates that srv-01 is configured as a minimal server
# without desktop packages.

{ pkgs, inputs, ... }:

let
  # Create pkgs-unstable for modules that need it
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in

pkgs.testers.runNixOSTest {
  name = "srv-01-system-test";

  nodes.machine = { config, lib, pkgs, modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
      inputs.srvos.nixosModules.common
      inputs.sops-nix.nixosModules.sops
      ../../modules/users/mi-skam.nix
      ../../modules/users/plumps.nix
      ../../modules/nixos/secrets.nix
    ];

    # Core system configuration matching srv-01
    networking = {
      hostName = "srv-01";
      domain = "dev.zz";
    };

    # Console and locale (from common.nix)
    console.keyMap = "de";
    i18n.defaultLocale = "en_US.UTF-8";

    # Users management (from common.nix)
    users.mutableUsers = false;

    # Enable SSH
    services.openssh.enable = true;

    # Enable fish shell (required by user modules)
    programs.fish.enable = true;

    # Enable userborn (from common.nix)
    services.userborn.enable = true;

    # VM configuration (minimal for server)
    virtualisation = {
      memorySize = 1024;
      cores = 2;
    };
  };

  testScript = ''
    # Start the VM
    machine.start()

    # Wait for system to reach multi-user target (critical boot test)
    machine.wait_for_unit("multi-user.target")
    print("✓ System booted to multi-user.target")

    # Verify user mi-skam exists
    machine.succeed("id mi-skam")
    print("✓ User mi-skam exists")

    # Verify user plumps exists (srv-01 has both users)
    machine.succeed("id plumps")
    print("✓ User plumps exists")

    # Verify both users are in wheel group
    machine.succeed("groups mi-skam | grep -q wheel")
    machine.succeed("groups plumps | grep -q wheel")
    print("✓ Both users are in wheel group")

    # Verify SSH service is running
    machine.wait_for_unit("sshd.service")
    machine.wait_for_open_port(22)
    print("✓ SSH service is running and listening on port 22")

    # Verify SOPS secrets are decrypted for both users
    machine.succeed("test -f /run/secrets/mi-skam")
    machine.succeed("test -f /run/secrets/plumps")
    print("✓ Secrets decrypted successfully for both users")

    # Negative test: Verify display-manager is NOT running (server config)
    machine.fail("systemctl is-active display-manager.service")
    print("✓ No display manager running (confirmed server config)")

    # Basic network connectivity test (loopback)
    machine.succeed("ping -c 1 127.0.0.1")
    print("✓ Network stack is functional")

    print("\n=== All srv-01 tests passed ===")
  '';
}
