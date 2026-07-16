{ config, lib, pkgs, ... }:

let
  packages = import ./packages.nix { inherit pkgs; };
in
{
  imports = [
    ./hardware.nix
    ../../modules/home/git.nix
    ../../modules/nixos/boot
    ../../modules/nixos/system/locale
    ../../modules/nixos/system/nix
    ../../modules/nixos/users
    ../../modules/nixos/services/ssh
    ../../modules/nixos/virtualization/docker
  ];

  networking.hostName = "server";
  system.stateVersion = "26.05";

  # No desktop on this machine
  programs.firefox.enable = lib.mkForce false;

  # GTX 1050 Ti (Pascal) — 580 is the last driver branch that supports it
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  environment.systemPackages = packages.system;
}
