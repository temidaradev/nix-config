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

  # The custom top bar (modules/darwin/sketchybar). false = plain macOS menu
  # bar; apply with `nh switch`.
  services.sketchybar.enable = true;

  environment.systemPackages = packages.system ++ shared;
}
