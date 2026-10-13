{ config, ... }:

{
  services.blueman.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = config.temidaradev.role == "desktop";
  };
}
