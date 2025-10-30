{
  description = "Sharing home-manager modules between nixos and darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    srvos.url = "github:numtide/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      flake = {
        # NixOS configurations
        nixosConfigurations = {
          xmsi = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { 
              inherit inputs;
              pkgs-unstable = import inputs.nixpkgs-unstable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            };
            modules = [
              ./hosts/xmsi/configuration.nix
              inputs.sops-nix.nixosModules.sops
            ];
          };
          
          srv-01 = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { 
              inherit inputs;
              pkgs-unstable = import inputs.nixpkgs-unstable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            };
            modules = [
              ./hosts/srv-01/configuration.nix
              inputs.sops-nix.nixosModules.sops
            ];
          };
        };

        # Darwin configurations
        darwinConfigurations = {
          xbook = inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            specialArgs = { 
              inherit inputs;
              pkgs-unstable = import inputs.nixpkgs-unstable {
                system = "aarch64-darwin";
                config.allowUnfree = true;
              };
            };
            modules = [
              ./hosts/xbook/darwin-configuration.nix
              inputs.sops-nix.darwinModules.sops
            ];
          };
        };

        # Home Manager configurations
        homeConfigurations = {
          "mi-skam@xmsi" = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = import inputs.nixpkgs {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
            extraSpecialArgs = { 
              inherit inputs;
              pkgs-unstable = import inputs.nixpkgs-unstable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            };
            modules = [
              ./modules/hm/users/mi-skam.nix
              ./modules/hm/desktop.nix
              ./modules/hm/dev.nix
              inputs.sops-nix.homeManagerModules.sops
            ];
          };

          "plumps@xbook" = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = import inputs.nixpkgs {
              system = "aarch64-darwin";
              config.allowUnfree = true;
            };
            extraSpecialArgs = { 
              inherit inputs;
              pkgs-unstable = import inputs.nixpkgs-unstable {
                system = "aarch64-darwin";
                config.allowUnfree = true;
              };
            };
            modules = [
              ./modules/hm/users/plumps.nix
              ./modules/hm/desktop.nix
              ./modules/hm/dev.nix
              inputs.sops-nix.homeManagerModules.sops
            ];
          };
          
          "plumps@srv-01" = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = import inputs.nixpkgs {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
            extraSpecialArgs = { 
              inherit inputs;
              pkgs-unstable = import inputs.nixpkgs-unstable {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            };
            modules = [
              ./modules/hm/users/plumps.nix
              ./modules/hm/common.nix
              inputs.sops-nix.homeManagerModules.sops
            ];
          };
        };
      };

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          devShells.default = import ./devshell.nix { inherit pkgs; };

          # NixOS VM tests (only available on x86_64-linux)
          checks = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
            xmsi-test = import ./tests/nixos/xmsi-test.nix {
              inherit pkgs;
              inherit inputs;
            };
            srv-01-test = import ./tests/nixos/srv-01-test.nix {
              inherit pkgs;
              inherit inputs;
            };
          };
        };
    };
}
