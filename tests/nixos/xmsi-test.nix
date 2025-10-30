# NixOS VM test for xmsi configuration
#
# Tests xmsi desktop system configuration by booting in isolated QEMU VM
# and verifying critical functionality:
# - System boots to multi-user target
# - User mi-skam exists with correct groups
# - SSH service is running
# - Secrets are decrypted correctly
#
# Note: This test imports common.nix which includes users and secrets,
# but does not import the full host configuration to avoid desktop module
# complexity in headless VM tests.

{ pkgs, inputs, ... }:

let
  # Create pkgs-unstable for modules that need it
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in

pkgs.testers.runNixOSTest {
  name = "xmsi-system-test";

  nodes.machine = { config, lib, pkgs, modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
      inputs.srvos.nixosModules.common
      inputs.sops-nix.nixosModules.sops
      ../../modules/users/mi-skam.nix
      ../../modules/nixos/secrets.nix
    ];

    # Core system configuration matching xmsi
    networking.hostName = "xmsi";

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

    # VM configuration
    virtualisation = {
      memorySize = 2048;
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

    # Verify user is in wheel group (sudo access)
    machine.succeed("groups mi-skam | grep -q wheel")
    print("✓ User mi-skam is in wheel group")

    # Verify SSH service is running
    machine.wait_for_unit("sshd.service")
    machine.wait_for_open_port(22)
    print("✓ SSH service is running and listening on port 22")

    # Verify SOPS secrets are decrypted
    machine.succeed("test -f /run/secrets/mi-skam")
    print("✓ Secrets decrypted successfully")

    # Basic network connectivity test (loopback)
    machine.succeed("ping -c 1 127.0.0.1")
    print("✓ Network stack is functional")

    print("\n=== All xmsi tests passed ===")
  '';
}
