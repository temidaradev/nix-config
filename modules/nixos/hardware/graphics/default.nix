{ config, lib, ... }:

{
  options.temidaradev.hardware.graphics.driver = lib.mkOption {
    type = lib.types.enum [ "intel" ];
    default = "intel";
  };

  config.hardware.graphics = {
    enable = lib.mkDefault true;
    enable32Bit = lib.mkDefault true;
  };

  imports = [
    ./intel.nix
  ];
}
