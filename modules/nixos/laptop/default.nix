{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.temidaradev.role == "laptop") {
    # --- power ---
    services.thermald.enable = true;               # Intel thermal daemon
    services.power-profiles-daemon.enable = true;  # also driven from the shell's sidebar
    services.upower.enable = true;
    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";   # intel_pstate active mode
    boot.kernelParams = [ "intel_pstate=active" ];
    services.fstrim.enable = true;
    zramSwap = { enable = true; memoryPercent = 25; };
    networking.networkmanager.wifi.powersave = true;

    # Lid / power button: niri handles the lid via switch-events, logind does the rest.
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
      HandlePowerKey = "suspend";
      HandlePowerKeyLongPress = "poweroff";
    };

    # --- hardware ---
    hardware.firmware = [ pkgs.sof-firmware ];     # Senary SN6147 codec runs on SOF
    services.hardware.bolt.enable = true;          # Thunderbolt 4 authorisation
    services.fprintd.enable = true;                # touch reader in the power button
    services.fwupd.enable = true;
    hardware.sensor.iio.enable = true;
    boot.kernelModules = [ "kvm-intel" ];

    # NPU (Intel AI Boost) and the IR camera need nothing extra; firmware comes
    # with linux-firmware. Camera privacy shutter is mechanical.

    environment.systemPackages = with pkgs; [
      brightnessctl
      powertop
      acpi
      intel-npu-driver
    ];

    # Let the shell change the backlight without root.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
    '';
    users.users.temidaradev.extraGroups = [ "video" "input" ];
  };
}
