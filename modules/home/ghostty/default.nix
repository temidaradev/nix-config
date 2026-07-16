{ pkgs, hmUsername, ... }:

let
  # Assets referenced by absolute store path so the config works from anywhere.
  baseConfig = ''
    font-family = "JetBrains Nerd Font Mono"
    font-size = 14

    custom-shader = ${./shaders/cursor_smear.glsl}
    custom-shader-animation = true

    background-image = ${./background.png}
    background-image-opacity = 0.3
    background-image-position = center
    background-image-fit = cover
    background-image-repeat = false

    window-padding-x = 5
    window-padding-y = 5

    window-decoration = auto

    # 100 MiB scrollback
    scrollback-limit = 104857600

    mouse-hide-while-typing = true
  '';

  linuxExtra = ''
    keybind = ctrl+shift+z=jump_to_prompt:-2
    keybind = ctrl+shift+x=jump_to_prompt:2
    keybind = ctrl+shift+home=scroll_to_top
    keybind = ctrl+shift+end=scroll_to_bottom
    keybind = ctrl+shift+enter=reset_font_size
    keybind = ctrl+shift+plus=increase_font_size:1
    keybind = ctrl+shift+minus=decrease_font_size:1
    keybind = ctrl+tab=next_tab
    keybind = ctrl+shift+tab=previous_tab
  '';
in
{
  hjem.users.${hmUsername} =
    if pkgs.stdenv.isDarwin then {
      # Ghostty.app on macOS reads Application Support, which overrides the
      # XDG path — manage the one that wins.
      files."Library/Application Support/com.mitchellh.ghostty/config".text = baseConfig;
    } else {
      xdg.config.files."ghostty/config".text = baseConfig + linuxExtra;
    };
}
