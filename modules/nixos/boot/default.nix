{ config, pkgs, ... }:

{
  boot.loader.efi.canTouchEfiVariables = true;
  
  boot.kernelPackages = pkgs.linuxPackages_latest;


  boot.loader = {
    timeout = 10;

    efi = {
      efiSysMountPoint = "/boot";
    };

    grub.enable = false;
    systemd-boot.enable = true;
  };
}
