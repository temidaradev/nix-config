{ pkgs, hmUsername, ... }:

let
  # Shell defaults as JSON next to the QML; the Settings window layers overrides
  # from ~/.local/state/quickshell/settings.json on top.
  shellSettings = pkgs.writeText "quickshell-settings.json" (builtins.toJSON (import ./quickshell-settings.nix));
  quickshellDir = pkgs.runCommand "quickshell-config" { } ''
    cp -r ${./quickshell} $out
    chmod -R u+w $out
    ln -s ${shellSettings} $out/settings.json
  '';
in
{
  hjem.users.${hmUsername}.xdg.config.files = {
    # macOS window management (dormant unless the daemons are started)
    "aerospace/aerospace.toml".source = ./aerospace.toml;
    "skhd/skhdrc".source = ./skhdrc;
    # yabairc/bordersrc are executed as scripts — writeScript keeps the exec bit
    "yabai/yabairc".source = pkgs.writeScript "yabairc" (builtins.readFile ./yabairc);
    "borders/bordersrc".source = pkgs.writeScript "bordersrc" (builtins.readFile ./bordersrc);
    "sketchybar".source = ./sketchybar;

    "btop/btop.conf".source = ./btop.conf;
    "cava".source = ./cava;

    "kitty/kitty.conf".source = ./kitty/kitty.conf;
    "kitty/theme.conf".source = ./kitty/theme.conf;
    "kitty/userprefs.conf".source = ./kitty/userprefs.conf;
    "kitty/1701872350454979.png".source = ./kitty/1701872350454979.png;

    "zed/settings.json".source = ./zed/settings.json;
    "zed/keymap.json".source = ./zed/keymap.json;

    "karabiner/karabiner.json".source = ./karabiner.json;

    # niri + its Quickshell shell (see quickshell/README.md)
    "niri/config.kdl".source = ./niri/config.kdl;
    "niri/wallpaper.png".source = ./niri/wallpaper.png;
    "swappy/config".source = ./niri/swappy;
    "quickshell".source = quickshellDir;
  };
}
