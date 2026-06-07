{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/a4e5954a-d5fd-419a-b5d1-0a86d5d054a0";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/3020-CF28";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  fileSystems."/mnt/1TB-HDD" =
    { device = "/dev/disk/by-uuid/d870dc25-8190-44c5-8bc8-26a8f557aed3";
      fsType = "ext4";
      options = [
        "rw"
        "noatime"
        "nodiratime"
        "commit=60"
        "nofail"
        "x-systemd.device-timeout=5s"
      ];
    };

  swapDevices = [{
    device = "/dev/disk/by-uuid/2a22c94c-53a3-4806-b566-edec101b6648";
  }];

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp10s0.useDHCP = lib.mkDefault true;

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
