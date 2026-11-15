{ ... }:

{
  hardware.opentabletdriver.enable = true;

  hardware.uinput.enable = true;
  boot.kernelModules = [ "uinput" ];

  # Overclock the tablet to 1000 Hz. The CTL-472's pen interface reports a
  # Generic Desktop Mouse collection, so usbhid's mousepoll override applies:
  # 1 ms interval instead of the descriptor's 2 ms (500 Hz). Also hits other
  # USB mice, which is harmless. usbhid is in the initrd, so this has to be a
  # kernel param rather than a modprobe option.
  boot.kernelParams = [ "usbhid.mousepoll=1" ];
}
