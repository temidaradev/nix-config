{ config, pkgs, inputs, system, ... }:


let
  packages = import ./packages.nix { inherit pkgs; };
  shared = import ../../modules/shared/packages.nix { inherit pkgs; };
in
{
  imports = [
    ../../modules/darwin
  ];

  networking.hostName = "temidaradev-darwin";
  networking.computerName = "temidaradev-darwin";

  nixpkgs.hostPlatform = system;

  system.stateVersion = 5;
  system.primaryUser = "lidldev";

  environment.systemPackages = packages.system ++ shared;
}
