{
  description = "NixOS + Darwin Configurations";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kopuz = {
      url = "github:temidaradev/kopuz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, zen-browser, helium, kopuz, caelestia-shell, ... }:
    let
      lib = nixpkgs.lib;

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ ];
      };

      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";
    in {
      nixosConfigurations.temidaradev = lib.nixosSystem {
        modules = [
          ./hosts/nixos/machine.nix
          (nixpkgs + "/nixos/modules/misc/nixpkgs/read-only.nix")
          { nixpkgs.pkgs = mkPkgs linuxSystem; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bak";
            home-manager.users.temidaradev = {
              imports = [
                ./modules/home/home.nix
                ./modules/home/dolphin.nix
                # caelestia-shell.homeManagerModules.default
                # ./modules/home/caelestia
              ];
            };
          }
        ];
        specialArgs = {
          system = linuxSystem;
          inherit zen-browser;
          inputs = { inherit helium kopuz; };
        };
      };

      darwinConfigurations.temidaradev-darwin = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/darwin/machine.nix
          { nixpkgs.pkgs = mkPkgs darwinSystem; }
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bak";
            home-manager.users.lidldev = import ./modules/home/home.nix;
          }
        ];
        specialArgs = {
          system = darwinSystem;
          inputs = { };
        };
      };
    };
}
