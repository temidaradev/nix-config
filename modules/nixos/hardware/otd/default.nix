{ ... }:

{
  hardware.opentabletdriver.enable = true;

  hardware.uinput.enable = true;
  boot.kernelModules = [ "uinput" ];
}
