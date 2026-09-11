{ config, lib, pkgs, ... }:

let
  cfg = config.temidaradev.laptop.throttledArrowLake;
  throttled-arrowlake = pkgs.python3Packages.buildPythonApplication {
    pname = "throttled-arrowlake";
    version = "unstable-2026-09-11";
    pyproject = true;
    src = pkgs.fetchFromGitHub {
      owner = "erpalma";
      repo = "throttled";
      rev = "7e1c1d14fcdc1afbf5b0f5ab9f3e44f6ad807740";
      hash = "sha256-k7A46b0N2FP1rMqIMvZXqktPNou4HKEByfRDmOQfpBA=";
    };
    # CPUID 6:197:2 is Arrow Lake-H (Core Ultra 7 255H). The upstream source
    # already validates this platform's 0x7d06 host bridge and 0x59a0 RAPL
    # register layout; only the CPU allowlist entry is missing.
    postPatch = ''
      sed -i "/(6, 198, 2): 'ArrowLake-HX',/i\\    (6, 197, 2): 'ArrowLake-H'," throttled.py
    '';
    build-system = [ pkgs.python3Packages.setuptools ];
    dependencies = [ pkgs.python3Packages.configparser pkgs.python3Packages.dbus-fast ];
    nativeBuildInputs = [ pkgs.python3Packages.setuptools ];
    doCheck = false;
  };
  rapl-mmio-reapply = pkgs.writeShellScript "rapl-mmio-reapply" ''
    set -u
    pl1=/sys/class/powercap/intel-rapl-mmio/intel-rapl-mmio:0/constraint_0_power_limit_uw
    pl2=/sys/class/powercap/intel-rapl-mmio/intel-rapl-mmio:0/constraint_1_power_limit_uw
    ac=/sys/class/power_supply/AC/online
    while :; do
      if [ -r "$ac" ] && [ "$(cat "$ac")" = 1 ]; then
        target1=43000000
        target2=43000000
      else
        target1=15000000
        target2=20000000
      fi
      [ -w "$pl1" ] && printf '%s\n' "$target1" > "$pl1" || true
      [ -w "$pl2" ] && printf '%s\n' "$target2" > "$pl2" || true
      sleep 0.5
    done
  '';
in

{
  options.temidaradev.laptop.throttledArrowLake.enable = lib.mkEnableOption
    "the experimental throttled Arrow Lake package-limit rewriter";

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
          # Battery above 40%: keep the system responsive without forcing
          # the AC performance policy.
          name = "battery-balanced";
          priority = 80;
          "if" = "?discharging";
          cpu = {
            governor = { first-available-governor = [ "schedutil" "powersave" ]; };
            energy-performance-preference = { first-available-energy-performance-preference = [ "balance_performance" "balance_power" ]; };
            energy-perf-bias = { first-available-energy-perf-bias = [ "balance-performance" "balance-power" ]; };
            turbo = { "if" = "?turbo-available"; "then" = true; };
          };
          power.platform-profile = { first-available-platform-profile = [ "balanced" "quiet" ]; };
          usb.autosuspend = false;
          gpu.panel-power-savings = 0;
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

    # Experimental bounded reapplication of the requested 43 W
    # sustained limit. Enabling this service makes raw
    # MSR/MCHBAR writes every second on AC; it does not disable thermal or
    # current protection, and its battery profile remains conservative.
    environment.etc."throttled-arrowlake.conf" = lib.mkIf cfg.enable {
      text = ''
        [GENERAL]
        Enabled: True
        Autoreload: True
        Sysfs_Power_Path: /sys/class/power_supply/AC*/online

        [AC]
        # Lenovo rewrites MMIO PL1 asynchronously; refresh frequently so the
        # requested 43 W DPTF limit remains
        # effective without changing thermal/current protection.
        Update_Rate_s: 0.5
        PL1_Tdp_W: 43
        PL1_Duration_s: 40
        PL2_Tdp_W: 43
        PL2_Duration_S: 0.002

        [BATTERY]
        Update_Rate_s: 30
        PL1_Tdp_W: 15
        PL1_Duration_s: 28
        PL2_Tdp_W: 20
        PL2_Duration_S: 0.002
      '';
    };
    systemd.services.throttled-arrowlake = lib.mkIf cfg.enable {
      description = "Reapply Arrow Lake package power limits";
      wantedBy = [ "multi-user.target" ];
      after = [ "watt.service" "upower.service" ];
      wants = [ "upower.service" ];
      path = [ pkgs.kmod pkgs.pciutils pkgs.util-linux ];
      serviceConfig = {
        ExecStart = "${throttled-arrowlake}/bin/throttled --config /etc/throttled-arrowlake.conf";
        Restart = "on-failure";
        RestartSec = 5;
        User = "root";
      };
      environment = {
        PYTHONUNBUFFERED = "1";
      };
    };
    systemd.services.rapl-mmio-reapply = lib.mkIf cfg.enable {
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

    environment.systemPackages = [ throttled-arrowlake ] ++ (with pkgs; [
      brightnessctl
      powertop
      acpi
      intel-npu-driver
      power-profiles-daemon   # only for the powerprofilesctl CLI (daemon is watt)
    ]);

    # Let the shell change the backlight without root.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
    '';
    users.users.temidaradev.extraGroups = [ "video" "input" ];
  };
}
