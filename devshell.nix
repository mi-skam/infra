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
  ];

  # Platform-specific packages
  darwinPackages =
    with pkgs;
    lib.optionals isDarwin [
      darwin-rebuild
    ];

  linuxPackages =
    with pkgs;
    lib.optionals isLinux [
      # nixos-rebuild is already included in commonPackages
    ];

  # Simplified infrastructure management script
  infraScript = pkgs.writeShellScriptBin "infra" ''
    #!/usr/bin/env bash
    set -euo pipefail

    COMMAND="''${1:-}"
    HOST="''${2:-$(hostname)}"

    # Get system type for a specific host
    get_host_system_type() {
      case "$1" in
        "xbook")
          echo "darwin"
          ;;
        "xmsi")
          echo "nixos"
          ;;
        *)
          echo "unknown"
          ;;
      esac
    }

    # Get user configuration for host
    get_user_config() {
      case "$HOST" in
        "xmsi")
          echo "mi-skam@xmsi"
          ;;
        "xbook")
          echo "plumps@xbook"
          ;;
        *)
          echo "Error: Unknown host '$HOST'. Supported hosts: xmsi, xbook"
          exit 1
          ;;
      esac
    }

    case "$COMMAND" in
      "update")
        echo "🔄 Updating flake inputs..."
        nix flake update
        ;;
      "build")
        SYSTEM_TYPE=$(get_host_system_type "$HOST")
        USER_CONFIG=$(get_user_config)
        
        echo "🔧 Building $HOST ($SYSTEM_TYPE) configuration..."
        
        case "$SYSTEM_TYPE" in
          "nixos")
            echo "Running: nixos-rebuild build --flake .#$HOST"
            nixos-rebuild build --flake ".#$HOST"
            ;;
          "darwin")
            echo "Running: nix build .#darwinConfigurations.$HOST.system"
            nix build ".#darwinConfigurations.$HOST.system"
            ;;
          *)
            echo "Error: Unable to determine system type for $HOST"
            exit 1
            ;;
        esac
        
        echo "Running: home-manager build --flake .#$USER_CONFIG"
        home-manager build --flake ".#$USER_CONFIG"
        ;;
      "upgrade")
        SYSTEM_TYPE=$(get_host_system_type "$HOST")
        USER_CONFIG=$(get_user_config)
        
        echo "🚀 Upgrading $HOST ($SYSTEM_TYPE)..."
        
        case "$SYSTEM_TYPE" in
          "nixos")
            echo "Running: sudo nixos-rebuild switch --flake .#$HOST"
            sudo nixos-rebuild switch --flake ".#$HOST"
            ;;
          "darwin")
            echo "Running: darwin-rebuild switch --flake .#$HOST"
            darwin-rebuild switch --flake ".#$HOST"
            ;;
          *)
            echo "Error: Unable to determine system type for $HOST"
            exit 1
            ;;
        esac
        
        echo "Running: home-manager switch --flake .#$USER_CONFIG"
        home-manager switch --flake ".#$USER_CONFIG"
        ;;
      "home")
        USER_CONFIG=$(get_user_config)
        
        echo "🏠 Updating home configuration for $USER_CONFIG..."
        echo "Running: home-manager switch --flake .#$USER_CONFIG"
        home-manager switch --flake ".#$USER_CONFIG"
        ;;
      *)
        echo "Usage: infra <command> [host]"
        echo ""
        echo "Commands:"
        echo "  update   - Update flake inputs"
        echo "  build    - Build system + home configuration (no activation)"
        echo "  upgrade  - Rebuild and switch system + home configuration"
        echo "  home     - Update only home-manager configuration"
        echo ""
        echo "Examples:"
        echo "  infra update           # Update flake inputs"
        echo "  infra build xbook      # Build configurations for testing"
        echo "  infra upgrade          # Upgrade current host (auto-detected)"
        echo "  infra upgrade xbook    # Upgrade specific host"
        echo "  infra home             # Update home-manager only (auto-detected)"
        echo ""
        echo "Supported hosts: xbook (Darwin), xmsi (NixOS)"
        exit 1
        ;;
    esac
  '';

in
pkgs.mkShell {
  # Add build dependencies
  packages =
    commonPackages
    ++ darwinPackages
    ++ linuxPackages
    ++ [
      infraScript
    ];

  # Add environment variables
  env = {
    # Ensure nix commands have flake support
    NIX_CONFIG = "experimental-features = nix-command flakes";
  };

  # Load custom bash code
  shellHook = ''
    echo "🚀 Infrastructure Development Shell"
    echo ""
    echo "Available tools:"
    echo "  • nixos-rebuild  - Build NixOS configurations"
    ${if isDarwin then ''echo "  • darwin-rebuild - Build Darwin configurations"'' else ""}
    echo "  • home-manager   - Build Home Manager configurations"
    echo "  • infra          - Simplified infrastructure management"
    echo ""
    echo "Quick commands:"
    echo "  infra update      # Update flake inputs"
    echo "  infra build xbook # Build configurations (cross-platform)"
    echo "  infra upgrade     # Upgrade current host (auto-detected)"
    echo "  infra home        # Update home-manager only"
    echo ""
    echo "Host configurations:"
    echo "  • xbook (Darwin) - plumps@xbook"
    echo "  • xmsi (NixOS)   - mi-skam@xmsi"
    echo ""
  '';
}
