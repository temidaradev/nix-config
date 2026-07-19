{ config, lib, pkgs, system, flakeInputs, ... }:

let
  caelestia = flakeInputs.caelestia-shell.packages.${system}.with-cli;
in
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  programs.uwsm.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.systemPackages = (with pkgs; [
    kitty
    wofi
    waybar
    hyprpaper
    hyprlauncher
  ]) ++ lib.optional config.programs.hyprland.enable caelestia;

  # Start the Caelestia shell only in a Hyprland session. It is bound to the
  # UWSM per-compositor target (wayland-session@hyprland.desktop.target), which
  # only exists during a Hyprland session, so it never starts under Plasma.
  # NOTE: UWSM derives the target name from the desktop-entry id, so it is
  # lowercase and suffixed with `.desktop` — not `@Hyprland.target`.
  systemd.user.services.caelestia = lib.mkIf config.programs.hyprland.enable {
    description = "Caelestia Shell Service";
    after = [ "wayland-session@hyprland.desktop.target" ];
    partOf = [ "wayland-session@hyprland.desktop.target" ];
    wantedBy = [ "wayland-session@hyprland.desktop.target" ];
    environment.QT_QPA_PLATFORM = "wayland";
    serviceConfig = {
      Type = "exec";
      ExecStart = "${caelestia}/bin/caelestia-shell";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStopSec = "5s";
      Slice = "session.slice";
    };
  };
}
