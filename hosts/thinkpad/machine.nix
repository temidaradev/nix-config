{ config, pkgs, system, flakeInputs, ... }:

let
  packages = import ./packages.nix { inherit pkgs; };
  shared = import ../../modules/shared/packages.nix { inherit pkgs; };
in
{
  imports = [
    ./hardware.nix
    ../../modules/nixos
  ];

  networking.hostName = "thinkpad";
  system.stateVersion = "26.05";
  temidaradev.role = "laptop";

  environment.systemPackages = packages.system ++ shared ++ [
    flakeInputs.helium.packages.${system}.default
    flakeInputs.kopuz.packages.${system}.default
    flakeInputs.zen-browser.packages.${system}.default
  ];
}
