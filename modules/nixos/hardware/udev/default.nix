{ config, pkgs, ... }:

{
  services.udev.extraRules = ''
    KERNEL=="ttyACM[0-9]*", MODE="0666"
    # mouse-battery (quickshell bar): LXDDZ 2.4G receivers and Razer mice over hidraw
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1d57", ATTRS{idProduct}=="fa60|fa65", TAG+="uaccess"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1532", TAG+="uaccess"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2357", ATTR{idProduct}=="0604", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2357", ATTR{idProduct}=="0604", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
  '';

  services.udisks2.enable = true;
  
  services.gvfs.enable = true;
  
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if (action.id.match("org.freedesktop.udisks2.") &&
            subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    });
  '';
}