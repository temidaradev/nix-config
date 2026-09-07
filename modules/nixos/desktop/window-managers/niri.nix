{ lib, pkgs, ... }:

let
  # Spawned from config.kdl; wrappers keep store paths out of it.
  polkitAgent = pkgs.writeShellScriptBin "niri-polkit-agent" ''
    exec ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
  '';
  gtkSettings = pkgs.writeShellScriptBin "niri-gtk-settings" ''
    g=${pkgs.glib}/bin/gsettings
    $g set org.gnome.desktop.interface gtk-theme 'Breeze-Dark'
    $g set org.gnome.desktop.interface color-scheme 'prefer-dark'
    $g set org.gnome.desktop.interface icon-theme 'breeze-dark'
    $g set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
    $g set org.gnome.desktop.interface cursor-size 32
    $g set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 10'
    $g set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'
  '';
  # Mod+Shift+S: pick an area, annotate in swappy (which saves + copies).
  screenshot = pkgs.writeShellScriptBin "niri-screenshot" ''
    set -e
    mkdir -p "$HOME/Pictures/Screenshots"
    area=$(${pkgs.slurp}/bin/slurp) || exit 0
    ${pkgs.grim}/bin/grim -g "$area" - | ${pkgs.swappy}/bin/swappy -f -
  '';

  # PATH for the shell service: NixOS gives user services a minimal PATH, and
  # everything launched from the app drawer inherits it.
  sessionPath = [
    "/run/wrappers"
    "/run/current-system/sw"
    "/etc/profiles/per-user/%u"
    "%h/.nix-profile"
    "%h/.local/state/nix/profile"
    "/nix/var/nix/profiles/default"
    "%h/.local/share/flatpak/exports"
    "/var/lib/flatpak/exports"
  ];
in
{
  programs.niri.enable = true;

  # plasma6 and niri both set this at the same priority; niri wins on the
  # SDDM login screen, Plasma stays selectable in the session menu.
  services.displayManager.defaultSession = lib.mkForce "niri";

  environment.systemPackages = with pkgs; [
    quickshell
    xwayland-satellite   # niri spawns it automatically when found in PATH
    fuzzel
    swaylock
    blueman              # pairing UI, opened from the control center
    networkmanagerapplet # nm-connection-editor, opened from the control center
    pavucontrol
    nixos-icons          # nix-snowflake icon used by the launcher button
    playerctl
    libnotify            # notify-send, lands in the shell's notification daemon
    curl
    grim
    slurp
    swappy
    wl-clipboard
    cliphist             # clipboard history shown in the sidebar
    polkitAgent
    gtkSettings
    screenshot
  ];

  # niri wants the GNOME portal for screencast/screenshot; the GTK one covers
  # file pickers and the Settings interface (fonts, dark mode) for GTK apps.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  xdg.portal.config.niri.default = [ "gnome" "gtk" ];

  programs.dconf.enable = true;          # gsettings backend for the GTK theme
  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;
  security.pam.services.swaylock = { };

  # The shell. Only niri.service wants it, so it never starts under Plasma or
  # Hyprland; it stops with the session and restarts if it crashes.
  systemd.user.services.quickshell-niri = {
    description = "Quickshell (niri shell)";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    requisite = [ "graphical-session.target" ];
    wantedBy = [ "niri.service" ];
    path = sessionPath;
    environment.QT_QPA_PLATFORM = "wayland";
    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.quickshell}/bin/qs";
      Restart = "on-failure";
      RestartSec = "2s";
      TimeoutStopSec = "5s";
      Slice = "session.slice";
    };
  };
}
