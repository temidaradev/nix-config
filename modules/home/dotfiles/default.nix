{ pkgs, hmUsername, ... }:

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
  };
}
