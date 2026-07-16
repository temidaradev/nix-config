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
    ../../modules/nixos/desktop/window-managers/plasma.nix
  ];

  networking.hostName = "server";
  system.stateVersion = "26.05";

  programs.firefox.enable = lib.mkForce false;

  # Plasma session for KRDP remote access — krdp shares a running
  # session, so log in automatically instead of waiting at sddm
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.autoLogin = {
    enable = true;
    user = "temidaradev";
  };
  networking.firewall.allowedTCPPorts = [ 3389 ];

  # GTX 1050 Ti (Pascal) — 580 is the last driver branch that supports it
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  environment.systemPackages = packages.system ++ [ pkgs.kdePackages.krdp ];
}
