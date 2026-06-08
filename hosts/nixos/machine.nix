{ config, pkgs, inputs, system, zen-browser, ... }:

let
  packages = import ./packages.nix { inherit pkgs; };
in
{
  imports = [
    ./hardware.nix
    ../../modules/nixos
  ];

  networking.hostName = "temidaradev";
  system.stateVersion = "26.05";

  environment.systemPackages = packages.system ++ [
    inputs.helium.packages.${system}.default
    inputs.kopuz.packages.${system}.default
    zen-browser.packages.${system}.default
  ];
}
