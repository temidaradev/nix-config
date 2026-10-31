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
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

  outputs = inputs@{ self, nixpkgs, nix-darwin, hjem, nvf, zen-browser, helium, kopuz, caelestia-shell, ... }:
    let
      lib = nixpkgs.lib;

      overlays = [
        (final: prev: {
          avrdude = prev.avrdude.override { docSupport = false; };
          terminal-wakatime = final.callPackage ./modules/shared/pkgs/terminal-wakatime.nix { };
          cmf-buds = final.callPackage ./modules/shared/pkgs/cmf-buds { };
          sony-xm5 = final.callPackage ./modules/shared/pkgs/sony-xm5 { };
          mouse-battery = final.callPackage ./modules/shared/pkgs/mouse-battery { };
        } // lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
          # Remove once nixpkgs uses the platform's library extension in Bear's install hook.
          bear = prev.bear.overrideAttrs (old: {
            postInstall = builtins.replaceStrings
              [ "libexec.so" ]
              [ "libexec${prev.stdenv.hostPlatform.extensions.sharedLibrary}" ]
              old.postInstall;
          });
        } // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isx86_64) {
          # patchelf 0.19.2 corrupts vmnet-natd's ELF layout, crashing the loader.
          # Keep VMware on the patcher used by the previous working package.
          vmware-workstation = prev.vmware-workstation.overrideAttrs (old: {
            nativeBuildInputs = [
              (prev.patchelf.overrideAttrs {
                version = "0.15.2";
                src = prev.fetchurl {
                  url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
                  hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
                };
              })
            ] ++ (old.nativeBuildInputs or [ ]);
          });

          # speechd's configure needs a native Python interpreter under strictDeps.
          # Match Calibre's Python so its speechd bindings are built and importable.
          calibre = prev.calibre.override {
            speechd-minimal = prev.speechd-minimal.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.python314 ];
            });
          };

          # Remove once pyopenjtalk-plus accepts Cython's type-error wording.
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (_pythonFinal: pythonPrev: {
              pyopenjtalk-plus = pythonPrev.pyopenjtalk-plus.overridePythonAttrs (old: {
                postPatch = (old.postPatch or "") + ''
                  substituteInPlace tests/test_frontend.py \
                    --replace-fail 'match="must be str"' 'match="must be str|Expected str, got int"'
                '';
              });
            })
          ];

          # Remove once trunk's bundled libdeflate supports GCC 16 (evex512 was removed).
          trunk = prev.trunk.overrideAttrs (old: {
            env = (old.env or { }) // {
              # cc-rs prefers this target-specific setting over the Rust hooks' HOST_CC.
              CC_x86_64_unknown_linux_gnu = "${prev.gcc15}/bin/cc";
            };
          });
        })
      ];

      mkPkgs = system: import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
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
          ./modules/home
        ];
        specialArgs = {
          system = linuxSystem;
          flakeInputs = inputs;
        };
      };
      nixosConfigurations.thinkpad = lib.nixosSystem {
        modules = [
          ./hosts/thinkpad/machine.nix
          (nixpkgs + "/nixos/modules/misc/nixpkgs/read-only.nix")
          { nixpkgs.pkgs = mkPkgs linuxSystem; }
          hjem.nixosModules.hjem
          ./modules/home
        ];
        specialArgs = {
          system = linuxSystem;
          flakeInputs = inputs;
        };
      };
      darwinConfigurations.temidaradev-darwin = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/darwin/machine.nix
          { nixpkgs.pkgs = mkPkgs darwinSystem; }
          hjem.darwinModules.hjem
          ./modules/home
        ];
        specialArgs = {
          system = darwinSystem;
          flakeInputs = inputs;
        };
      };
    };
}
