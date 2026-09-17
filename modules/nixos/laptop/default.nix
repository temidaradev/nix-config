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

    capacity=/sys/class/power_supply/BAT0/capacity

    while :; do
      if [ -r "$ac" ] && [ "$(cat "$ac")" = 1 ]; then
        pl1=43000000; pl2=43000000; offset=0;  interval=0.5
        aspm=default; watchdog=1; writeback=500
      else
        pct=100
        [ -r "$capacity" ] && pct=$(cat "$capacity")
        if [ "$pct" -lt 40 ]; then
          pl1=10000000; pl2=15000000
        else
          pl1=15000000; pl2=20000000
        fi
        offset=25; interval=20
        aspm=powersave; watchdog=0; writeback=1500
      fi

      apply "$pl1" "$rapl/constraint_0_power_limit_uw"
      apply "$pl2" "$rapl/constraint_1_power_limit_uw"
      for tcc in /sys/bus/pci/devices/*/tcc_offset_degree_celsius; do
        apply "$offset" "$tcc"
      done
      apply "$aspm" /sys/module/pcie_aspm/parameters/policy
      apply "$watchdog" /proc/sys/kernel/nmi_watchdog
      apply "$writeback" /proc/sys/vm/dirty_writeback_centisecs

      sleep "$interval"
    done
  '';

  wifi-powersave-sync = pkgs.writeShellScript "wifi-powersave-sync" ''
    set -u
    ac=/sys/class/power_supply/AC/online

    if [ -r "$ac" ] && [ "$(cat "$ac")" = 1 ]; then
      state=off
    else
      state=on
    fi

    for dev in /sys/class/net/*; do
      [ -d "$dev/wireless" ] || continue
      ${pkgs.iw}/bin/iw dev "$(basename "$dev")" set power_save "$state" || true
    done
  '';

  wait-for-charge-thresholds = pkgs.writeShellScript "wait-for-charge-thresholds" ''
    set -u
    end=/sys/class/power_supply/BAT0/charge_control_end_threshold
    waited=0

    while [ ! -e "$end" ]; do
      if [ "$waited" -ge 60 ]; then
        echo "timed out waiting for '$end'; starting watt anyway" >&2
        exit 0
      fi
      waited=$((waited + 1))
      sleep 0.5
    done
  '';

  chargeThresholds = {
    limit = { start = 79; end = 80; };
    full = { start = 99; end = 100; };
  };

  chargeRule = { start, end }: {
    name = "charge-thresholds";
    priority = 1;
    power.for = [ "BAT0" ];
    power.charge-threshold-start = start;
    power.charge-threshold-end = end;
  };

  wattFullChargeConfig = (pkgs.formats.toml { }).generate "watt-charge-full.toml" (
    config.services.watt.settings // {
      rule =
        (builtins.filter (r: r.name or null != "charge-thresholds") config.services.watt.settings.rule)
        ++ [ (chargeRule chargeThresholds.full) ];
    }
  );

  battery-charge-ctl = pkgs.writeShellScriptBin "battery-charge-ctl" ''
    set -eu
    dropin=/run/systemd/system/watt.service.d
    startf=/sys/class/power_supply/BAT0/charge_control_start_threshold
    endf=/sys/class/power_supply/BAT0/charge_control_end_threshold

    case "''${1-}" in
      full)
        want_start=${toString chargeThresholds.full.start}
        want_end=${toString chargeThresholds.full.end}
        mkdir -p "$dropin"
        printf '[Service]\nEnvironment=WATT_CONFIG=/etc/watt-charge-full.toml\n' \
          > "$dropin/charge-full.conf"
        ;;
      limit)
        want_start=${toString chargeThresholds.limit.start}
        want_end=${toString chargeThresholds.limit.end}
        rm -f "$dropin/charge-full.conf"
        rmdir --ignore-fail-on-non-empty "$dropin" 2>/dev/null || true
        ;;
      *)
        echo "usage: battery-charge-ctl full|limit" >&2
        exit 2
        ;;
    esac

    for _ in 1 2; do
      printf '%s\n' "$want_end" > "$endf" 2>/dev/null || true
      printf '%s\n' "$want_start" > "$startf" 2>/dev/null || true
    done

    systemctl daemon-reload
    systemctl reset-failed watt.service 2>/dev/null || true
    systemctl restart watt
    sleep 2

    got_start=$(cat "$startf")
    got_end=$(cat "$endf")
    printf 'charge thresholds: start=%s end=%s\n' "$got_start" "$got_end"
    [ "$got_start" = "$want_start" ] && [ "$got_end" = "$want_end" ]
  '';

  charge-full = pkgs.writeShellScriptBin "charge-full" ''
    exec sudo -n /run/current-system/sw/bin/battery-charge-ctl full
  '';

  charge-limit = pkgs.writeShellScriptBin "charge-limit" ''
    exec sudo -n /run/current-system/sw/bin/battery-charge-ctl limit
  '';

  lid-closed = pkgs.writeShellScript "lid-closed" ''
    for state in /proc/acpi/button/lid/*/state; do
      [ -r "$state" ] || continue
      read -r _ position < "$state" || continue
      if [ "$position" = closed ]; then
        exit 0
      fi
    done
    exit 1
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
          uncore.frequency-khz-maximum = 3900000;
          vm.transparent-hugepage-defrag = "madvise";
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
            turbo = { "if" = "?turbo-available"; "then" = true; };
            pstate-max-performance-percent = 70;
          };
          power.platform-profile = { first-available-platform-profile = [ "balanced" "low-power" "quiet" ]; };
          usb.autosuspend = true;
          usb.autosuspend-delay-seconds = 2;
          uncore.frequency-khz-maximum = 2000000;
          audio.timeout-seconds = 10;
          vm.transparent-hugepage-defrag = "defer+madvise";
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
            turbo = { "if" = "?turbo-available"; "then" = true; };
            pstate-max-performance-percent = 45;
          };
          power.platform-profile = { first-available-platform-profile = [ "low-power" "quiet" "balanced" ]; };
          usb.autosuspend = true;
          usb.autosuspend-delay-seconds = 2;
          uncore.frequency-khz-maximum = 1200000;
          audio.timeout-seconds = 5;
          vm.transparent-hugepage-defrag = "defer+madvise";
        }
        (chargeRule chargeThresholds.limit)
      ];
    };

    environment.etc."watt-charge-full.toml".source = wattFullChargeConfig;
    # Watt owns its legacy power-profile API while power-profiles-daemon is off.
    systemd.services.watt.environment.WATT_CONFIG = "/etc/watt.toml";
    # The config reaches watt through WATT_CONFIG rather than the unit itself,
    # so editing the rules leaves the unit byte-identical and switch-to-
    # configuration never restarts the daemon: it keeps serving the rules it
    # parsed at boot. Tie the restart to the config's store path explicitly.
    systemd.services.watt.restartTriggers = [ config.environment.etc."watt.toml".source ];

    systemd.services.watt.serviceConfig.ExecStartPre = wait-for-charge-thresholds;
    systemd.services.watt.serviceConfig.RestartSec = 5;
    systemd.services.watt.startLimitIntervalSec = 300;
    systemd.services.watt.startLimitBurst = 10;

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

    systemd.services.wifi-powersave-sync = {
      description = "Match WiFi power saving to AC state";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = wifi-powersave-sync;
      };
    };

    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeText "wifi-powersave-dispatch" ''
          [ "$2" = up ] || exit 0
          exec ${wifi-powersave-sync}
        '';
      }
    ];

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

    security.pam.services =
      let
        skipFprintd = service: control: {
          rules.auth.lid-closed-skips-fprintd = {
            inherit control;
            order = config.security.pam.services.${service}.rules.auth.fprintd.order - 1;
            modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
            args = [ "quiet" "${lid-closed}" ];
          };
        };
      in
      lib.genAttrs
        [ "sudo" "su" "systemd-run0" "polkit-1" "login" "swaylock" ]
        (service: skipFprintd service "[success=1 default=ignore]")
      // {
        kde-fingerprint = skipFprintd "kde-fingerprint" "[success=die default=ignore]";
      };
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
      battery-charge-ctl
      charge-full
      charge-limit
    ];

    security.sudo.extraRules = [
      {
        users = [ "temidaradev" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/battery-charge-ctl full";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/battery-charge-ctl limit";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Let the shell change the backlight without root.
    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ATTR{online}=="?*", RUN+="${pkgs.systemd}/bin/systemctl --no-block start wifi-powersave-sync.service"
      ACTION=="add", SUBSYSTEM=="pci", DRIVERS=="nvme|iwlwifi|e1000e|xhci_hcd|intel-lpss|mei_me", ATTR{power/control}="auto"
      ACTION=="add", SUBSYSTEM=="pci", DRIVERS=="e1000e", ATTR{power/autosuspend_delay_ms}="1000"
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
    '';
    users.users.temidaradev.extraGroups = [ "video" "input" ];
  };
}
