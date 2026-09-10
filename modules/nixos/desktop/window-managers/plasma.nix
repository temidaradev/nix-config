{ lib, pkgs, ... }:

let
  style = ./plasma-style;
  styleConfig = style + "/config";
  configFiles = [
    "kdeglobals"
    "kscreenlockerrc"
    "kwinrc"
    "plasmarc"
    "plasmashellrc"
    "plasma-org.kde.plasma.desktop-appletsrc"
  ];
  layoutVersion = builtins.hashString "sha256" (
    lib.concatMapStrings (file: builtins.readFile (styleConfig + "/${file}")) configFiles
  );
  plasmoids = lib.filterAttrs (_: type: type == "directory") (
    builtins.readDir (style + "/data/plasma/plasmoids")
  );
  plasmoidFiles = lib.mapAttrs' (name: _: {
    name = "plasma/plasmoids/${name}";
    value.source = style + "/data/plasma/plasmoids/${name}";
  }) plasmoids;
  installStyle = pkgs.writeShellScript "install-plasma-style" ''
    set -eu

    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}"
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
    marker="$state_dir/temidaradev-plasma-style-${layoutVersion}"

    if [ -e "$marker" ]; then
      exit 0
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$config_dir" "$state_dir"
    for file in ${lib.concatStringsSep " " configFiles}; do
      ${pkgs.coreutils}/bin/install -m 0600 "${styleConfig}/$file" "$config_dir/$file"
    done
    ${pkgs.coreutils}/bin/touch "$marker"
  '';
in
{
  services.desktopManager.plasma6.enable = true;

  # The mutable Plasma layout is seeded once for each version before
  # plasmashell starts. Themes and widgets can stay declarative and read-only.
  hjem.users.temidaradev.xdg.data.files = {
    "aurorae/themes/Nothing".source = style + "/data/aurorae/themes/Nothing";
    "color-schemes/Nothing.colors".source = style + "/data/color-schemes/Nothing.colors";
    "plasma/desktoptheme/Nothing".source = style + "/data/plasma/desktoptheme/Nothing";
    "plasma/look-and-feel/Nothing".source = style + "/data/plasma/look-and-feel/Nothing";
  } // plasmoidFiles;

  systemd.user.services.temidaradev-plasma-style = {
    description = "Seed temidaradev's Plasma layout and appearance";
    wantedBy = [ "plasma-workspace.target" ];
    before = [ "plasma-plasmashell.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = installStyle;
    };
  };
}
