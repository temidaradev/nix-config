{ config, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = config.temidaradev.role == "desktop";
  };
}
