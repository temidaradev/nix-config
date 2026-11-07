# SketchyBar styled after the Linux Quickshell bar: Breeze Dark, the front
# app's menus, a tray of menu bar icons, popups for every widget. Apple's menu
# bar stays shown underneath and SketchyBar covers it; the notch itself is
# left to Boring Notch (now playing, calendar, shelf).
# Needs Accessibility (menus, tray, Control Center) and Bluetooth permission.
#
# Turn the whole bar on/off with `services.sketchybar.enable` in
# hosts/darwin/machine.nix; everything below only applies while it's on.
{ config, lib, pkgs, ... }:

let
  lua = pkgs.lua5_5;
  appFont = pkgs.sketchybar-app-font;

  # topmost=on puts the bar at kCGStatusWindowLevel (25), the same level as
  # MenuBarAgent's menu bar, so the auto-hidden Apple bar could slide in on top
  # and steal clicks. One level higher keeps it underneath (still below Boring
  # Notch at 27; SketchyBar's own popups sit at 101).
  sketchybar = pkgs.sketchybar.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/bar_manager.c \
        --replace-fail "bar_manager->window_level = kCGStatusWindowLevel;" \
                       "bar_manager->window_level = kCGStatusWindowLevel + 1;"
    '';
  });

  # Small native helpers: sbmenus (app menus, tray, displays), sbcal (renders
  # the calendar popup's month grid) and sbwatch (network/CPU event providers).
  helpers = pkgs.runCommandCC "sketchybar-helpers" { } ''
    mkdir -p $out/bin
    $CC -O2 -Wall -framework ApplicationServices -framework AppKit -framework Carbon ${./sbmenus.c} -o $out/bin/sbmenus
    $CC -O2 -Wall -framework ApplicationServices -framework CoreText -framework ImageIO ${./sbcal.c} -o $out/bin/sbcal
    $CC -x objective-c -fblocks -O2 -Wall -framework AppKit -framework CoreFoundation -framework SystemConfiguration -framework IOKit ${./sbwatch.c} -o $out/bin/sbwatch
  '';
in
lib.mkIf config.services.sketchybar.enable {
  services.sketchybar = {
    package = sketchybar;
    extraPackages = [ pkgs.blueutil ];
    config = ''
      #!${lua}/bin/lua
      package.cpath = "${pkgs.sbarlua}/lib/lua/5.5/?.so;" .. package.cpath
      package.path = "${./config}/?.lua;${appFont}/lib/sketchybar-app-font/?.lua;" .. package.path
      SBMENUS = "${helpers}/bin/sbmenus"
      SBCAL = "${helpers}/bin/sbcal"
      SBWATCH = "${helpers}/bin/sbwatch"
      require("init")
    '';
  };

  fonts.packages = [ appFont ];

  # Keep Apple's menu bar permanently shown (also in full screen) and let
  # SketchyBar cover it. An auto-hidden bar slides in on top of everything
  # when the pointer touches the screen edge and steals those clicks; a shown
  # one stays underneath SketchyBar's higher window level.
  system.defaults.NSGlobalDomain._HIHideMenuBar = false;
  system.defaults.CustomUserPreferences.NSGlobalDomain.AppleMenuBarVisibleInFullscreen = true;
  # Native menus must exist for the Accessibility click bridge.
  system.defaults.CustomUserPreferences."com.apple.controlcenter" = {
    "NSStatusItem Visible Sound" = true;
    "NSStatusItem Visible Display" = true;
  };
}
