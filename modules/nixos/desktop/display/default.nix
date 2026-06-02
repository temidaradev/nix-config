{ config, pkgs, ... }:

{
  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  environment.systemPackages = with pkgs; [
    bibata-cursors
  ];

  services.displayManager.sddm.settings = {
    Theme = {
      CursorTheme = "Bibata-Modern-Classic";
      CursorSize = 24;
    };
  };

  services.libinput.enable = true;

  services.xserver.xkb = {
    layout = "us,tr";
    variant = "";
  };

  console.keyMap = "us";

  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };
}
