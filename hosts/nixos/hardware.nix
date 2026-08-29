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
    { device = "/dev/disk/by-uuid/d140e311-1f60-4c6e-a58b-888d895ebab6";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/D273-D855";
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

  fileSystems."/mnt/430GB-SSD" =
    { device = "/dev/disk/by-uuid/aa932d4b-a5ec-4664-a1e0-063bf645ac5f";
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
    device = "/dev/disk/by-uuid/2fadf6c2-04e8-4f73-9d48-799519e1b5a1";
  }];

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp10s0.useDHCP = lib.mkDefault true;

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
