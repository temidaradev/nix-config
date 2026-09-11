{ config, lib, pkgs, ... }:

let
  # Firmware ships a TCC offset of 25, so thermal throttling starts at
  # Tjmax (105 C) minus 25, i.e. 80 C, and caps sustained package power at
  # 35 W while allowing 43 W only in bursts. Both are reapplied continuously:
  # the offset resets to the firmware default on every boot, and the MMIO
  # limit gets rewritten behind us. Hardware protection is untouched, so
  # PROCHOT still fires at 105 C and the ACPI critical trip stays at 110 C.
  rapl-mmio-reapply = pkgs.writeShellScript "rapl-mmio-reapply" ''
    set -u
    rapl=/sys/class/powercap/intel-rapl-mmio/intel-rapl-mmio:0
    ac=/sys/class/power_supply/AC/online

    # apply <value> <file>
    apply() {
      [ -w "$2" ] && printf '%s\n' "$1" > "$2" || true
    }

    while :; do
      if [ -r "$ac" ] && [ "$(cat "$ac")" = 1 ]; then
        pl1=43000000; pl2=43000000; offset=0;  interval=0.5
      else
        pl1=15000000; pl2=20000000; offset=25; interval=30
      fi

      apply "$pl1" "$rapl/constraint_0_power_limit_uw"
      apply "$pl2" "$rapl/constraint_1_power_limit_uw"
      for tcc in /sys/bus/pci/devices/*/tcc_offset_degree_celsius; do
        apply "$offset" "$tcc"
      done

      sleep "$interval"
    done
  '';
in

{
  config = lib.mkIf (config.temidaradev.role == "laptop") {
    # --- power: watt (pkgs.watt, github:NotAShelf/watt) drives governor / EPP /
    # turbo / frequency caps / charge thresholds. Policy: on wall power, maximum
    # performance no matter what; on battery, save power. Watt exposes its
    # legacy net.hadess.PowerProfiles API; Plasma's newer standard profile
    # service is intentionally not started alongside Watt.
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
          # Battery above 40%: favor efficiency while retaining normal
          # interactive performance.
          name = "battery-balanced";
          priority = 80;
          "if" = "?discharging";
          cpu = {
            governor = { first-available-governor = [ "schedutil" "powersave" ]; };
            energy-performance-preference = { first-available-energy-performance-preference = [ "balance_power" "power" ]; };
            energy-perf-bias = { first-available-energy-perf-bias = [ "balance-power" "power" ]; };
            turbo = { "if" = "?turbo-available"; "then" = false; };
          };
          power.platform-profile = { first-available-platform-profile = [ "balanced" "low-power" "quiet" ]; };
          usb.autosuspend = true;
          gpu.panel-power-savings = 3;
          audio.timeout-seconds = 10;
        }
        {
          # Below 40%: favor battery life over responsiveness.
          # This higher-priority rule overrides battery-balanced while discharging.
          name = "battery-low-power";
          priority = 85;
          "if".all = [ "?discharging" { is-less-than = 0.4; value = "%power-supply-charge"; } ];
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
          name = "charge-thresholds";
          priority = 1;
          # Only BAT0 exposes charge-control files on this machine; the AC and
          # USB-C power supplies reject threshold writes and would stop Watt.
          power.for = [ "BAT0" ];
          power.charge-threshold-start = 40;
          power.charge-threshold-end = 80;
        }
      ];
    };
    # Watt owns its legacy power-profile API while power-profiles-daemon is off.
    systemd.services.watt.environment.WATT_CONFIG = "/etc/watt.toml";

    # The kernel and firmware both rewrite the MMIO RAPL limit, so reapply the
    # requested policy continuously. This also owns the TCC offset, which
    # otherwise reverts to the firmware default of 25 on every boot.
    systemd.services.rapl-mmio-reapply = {
      description = "Reapply kernel MMIO RAPL package limits";
      wantedBy = [ "multi-user.target" ];
      after = [ "watt.service" ];
      serviceConfig = {
        ExecStart = rapl-mmio-reapply;
        Restart = "always";
        RestartSec = 1;
        User = "root";
      };
    };

    services.upower.enable = true;
    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";   # intel_pstate active mode
    boot.kernelParams = [ "intel_pstate=active" ];
    services.fstrim.enable = true;
    zramSwap = { enable = true; memoryPercent = 25; };
    networking.networkmanager.wifi.powersave = false;

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
