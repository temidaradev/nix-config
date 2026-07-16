{
  description = "NixOS + Darwin Configurations";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hjem = {
      url = "github:feel-co/hjem";
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

  outputs = inputs@{ self, nixpkgs, nix-darwin, hjem, zen-browser, helium, kopuz, caelestia-shell, ... }:
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
          hjem.nixosModules.hjem
          ./modules/home/home.nix
        ];
        specialArgs = {
          system = linuxSystem;
          inherit zen-browser;
          inputs = { inherit helium kopuz; };
        };
      };

      nixosConfigurations.server = lib.nixosSystem {
        modules = [
          ./hosts/server/machine.nix
          (nixpkgs + "/nixos/modules/misc/nixpkgs/read-only.nix")
          { nixpkgs.pkgs = mkPkgs linuxSystem; }
          hjem.nixosModules.hjem
          ./modules/home/home.nix
        ];
        specialArgs = {
          system = linuxSystem;
          inputs = { };
        };
      };

      darwinConfigurations.temidaradev-darwin = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/darwin/machine.nix
          { nixpkgs.pkgs = mkPkgs darwinSystem; }
          hjem.darwinModules.hjem
          ./modules/home/home.nix
        ];
        specialArgs = {
          system = darwinSystem;
          inputs = { };
        };
      };
    };
}
