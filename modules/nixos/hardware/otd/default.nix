{ lib, config, pkgs, ... }:

{
  config = lib.mkIf (config.temidaradev.role == "desktop") {
  hardware.opentabletdriver.enable = true;

  hardware.uinput.enable = true;
  boot.kernelModules = [ "uinput" ];
  };
}
