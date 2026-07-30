{ pkgs, ... }:

{
  imports = [
    ./display
    ./window-managers
    ./audio
  ];

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "image/png" = "org.kde.gwenview.desktop";
      "image/jpeg" = "org.kde.gwenview.desktop";
      "image/gif" = "org.kde.gwenview.desktop";
      "image/bmp" = "org.kde.gwenview.desktop";
      "image/svg+xml" = "org.kde.gwenview.desktop";
      "image/webp" = "org.kde.gwenview.desktop";
      "image/tiff" = "org.kde.gwenview.desktop";
    };
  };


  # `common` applies to every session, so listing the KDE backend there made
  # Hyprland ask for a backend that only plasma-workspace ever starts. The
  # Settings interface is the one that matters for appearance: it is what
  # hands GTK apps their UI font, antialiasing and text scaling. Pick the
  # backend per session (keys are matched against $XDG_CURRENT_DESKTOP).
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "gtk" ];
      KDE.default = [ "kde" "gtk" ];
      Hyprland.default = [ "hyprland" "gtk" ];
    };
  };
}
