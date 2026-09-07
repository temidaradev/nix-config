{ config, lib, pkgs, ... }:


{
  config = lib.mkIf (config.temidaradev.role == "laptop") {
    # --- power: watt (pkgs.watt, github:NotAShelf/watt) drives governor / EPP /
    # turbo / frequency caps / charge thresholds. Policy: on wall power, maximum
    # performance no matter what; on battery, save power. watt also serves the
    # net.hadess.PowerProfiles D-Bus API, so powerprofilesctl still answers;
    # power-profiles-daemon and thermald must be off.
    services.power-profiles-daemon.enable = lib.mkForce false;
    services.thermald.enable = false;
    services.watt = {
      enable = true;
      settings.rule = [
        {
          name = "ac-max-performance";
          priority = 90;
          "if" = { not = "?discharging"; };
          cpu = {
            governor = { first-available-governor = [ "performance" "schedutil" ]; };
            energy-performance-preference = { first-available-energy-performance-preference = [ "performance" "balance_performance" ]; };
            energy-perf-bias = { first-available-energy-perf-bias = [ "performance" "balance-performance" ]; };
            turbo = { "if" = "?turbo-available"; "then" = true; };
            frequency-mhz-maximum = { "if" = "?frequency-available"; "then" = "$cpu-frequency-maximum"; };
          };
          power.platform-profile = { first-available-platform-profile = [ "performance" "balanced" ]; };
          usb.autosuspend = false;
          gpu.panel-power-savings = 0;
        }
        {
          name = "battery-critical";
          priority = 85;
          "if".all = [ "?discharging" { is-less-than = 0.2; value = "%power-supply-charge"; } ];
          cpu.frequency-mhz-maximum = { "if" = "?frequency-available"; "then" = 1600; };
        }
        {
          name = "battery-power-save";
          priority = 80;
          "if" = "?discharging";
          cpu = {
            governor = { first-available-governor = [ "powersave" "schedutil" ]; };
            energy-performance-preference = { first-available-energy-performance-preference = [ "power" "balance_power" ]; };
            energy-perf-bias = { first-available-energy-perf-bias = [ "power" "balance-power" ]; };
            turbo = { "if" = "?turbo-available"; "then" = false; };
            frequency-mhz-maximum = { "if" = "?frequency-available"; "then" = 2400; };
          };
          power.platform-profile = { first-available-platform-profile = [ "low-power" "quiet" "balanced" ]; };
          usb.autosuspend = true;
          gpu.panel-power-savings = 3;
          audio.timeout-seconds = 10;
        }
        {
          # Battery longevity: keep the 64Wh pack between 40 and 80 percent.
          # Raise both to 95/100 before a long trip.
          name = "charge-thresholds";
          priority = 1;
          power.charge-threshold-start = 40;
          power.charge-threshold-end = 80;
        }
      ];
    };
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
      power-profiles-daemon   # only for the powerprofilesctl CLI (daemon is watt)
    ];

    # Let the shell change the backlight without root.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
    '';
    users.users.temidaradev.extraGroups = [ "video" "input" ];
  };
}
