{ ... }:

{
  hardware.openrazer = {
    enable = true;
    users = [ "temidaradev" ];
  };

  imports = [
    ./bluetooth
    ./graphics
    ./udev
    ./keyboard
    ./otd
  ];
}
