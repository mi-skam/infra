{ pkgs }:
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # Cross-platform packages
  commonPackages = with pkgs; [
    nixos-rebuild # Works on both platforms for managing NixOS configs
    home-manager
    git
    direnv
    nodejs_22 # For npm global package management
    sops # Secrets management
    age # Modern encryption
    opentofu # Infrastructure as Code
    ansible # Configuration management
    hcloud # Hetzner Cloud CLI
    jq # JSON processing for scripts
    just # Task runner
  ];

  # Platform-specific packages
  darwinPackages =
    with pkgs;
    lib.optionals isDarwin [
      # darwin-rebuild is provided by nix-darwin installation, not as a package
    ];

  linuxPackages =
    with pkgs;
    lib.optionals isLinux [
      # nixos-rebuild is already included in commonPackages
    ];

in
pkgs.mkShell {
  # Add build dependencies
  packages =
    commonPackages
    ++ darwinPackages
    ++ linuxPackages;

  # Add environment variables
  env = {
    # Ensure nix commands have flake support
    NIX_CONFIG = "experimental-features = nix-command flakes";
  };

  # Load custom bash code
  shellHook = ''
    # Helper function to load Hetzner API token
    load-hetzner-token() {
      export HCLOUD_TOKEN="$(${pkgs.sops}/bin/sops -d secrets/hetzner.yaml | ${pkgs.gnugrep}/bin/grep 'hcloud:' | ${pkgs.coreutils}/bin/cut -d: -f2 | ${pkgs.coreutils}/bin/tr -d ' ')"
      echo "✓ Loaded HCLOUD_TOKEN from secrets/hetzner.yaml"
    }

    echo "🚀 Infrastructure Development Shell"
    echo ""
    echo "Available tools:"
    echo "  • nixos-rebuild  - Build NixOS configurations"
    ${if isDarwin then ''echo "  • darwin-rebuild - Build Darwin configurations"'' else ""}
    echo "  • home-manager   - Build Home Manager configurations"
    echo "  • opentofu       - Infrastructure as Code (terraform)"
    echo "  • ansible        - Configuration management"
    echo "  • hcloud         - Hetzner Cloud CLI"
    echo "  • just           - Task runner (see justfile)"
    echo "  • sops/age       - Secrets management"
    echo ""
    echo "Common tasks (use 'just' to see all):"
    echo "  just tf-plan              # Preview infrastructure changes"
    echo "  just tf-apply             # Apply infrastructure changes"
    echo "  just ansible-ping         # Test server connectivity"
    echo "  just ansible-deploy       # Deploy configurations"
    echo ""
    echo "NixOS/Darwin:"
    echo "  sudo nixos-rebuild switch --flake .#xmsi"
    echo "  darwin-rebuild switch --flake .#xbook"
    echo "  home-manager switch --flake .#mi-skam@xmsi"
    echo ""
    echo "Secrets:"
    echo "  sops secrets/hetzner.yaml       # Edit API tokens"
    echo "  load-hetzner-token              # Load HCLOUD_TOKEN env var"
    echo ""
    echo "Hetzner Cloud (requires load-hetzner-token):"
    echo "  hcloud server list              # List all servers"
    echo "  hcloud network list             # List networks"
    echo ""
    echo "Infrastructure:"
    echo "  • Local: xbook (Darwin), xmsi (NixOS), srv-01 (NixOS)"
    echo "  • Hetzner: 3 VPS (mail, syncthing, test) + private network"
    echo ""
  '';
}
