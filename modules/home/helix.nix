{ pkgs, hmUsername, ... }:

{
  hjem.users.${hmUsername} = {
    xdg.config.files = {
      "helix/config.toml" = {
        generator = (pkgs.formats.toml { }).generate "helix-config.toml";
        value = {
          theme = "gruvbox_dark_soft";

          editor = {
            line-number = "relative";
            mouse = false;
            bufferline = "multiple";
            color-modes = true;
            cursorline = true;
            file-picker.hidden = false;
            idle-timeout = 0;
            text-width = 100;

            cursor-shape = {
              insert = "bar";
              normal = "block";
              select = "underline";
            };

            indent-guides = {
              character = "▏";
              render = true;
            };

            whitespace = {
              characters.tab = "→";
              render.tab = "all";
            };
          };

          keys.normal.D = "extend_to_line_end";
          keys.select.D = "extend_to_line_end";
        };
      };

      "helix/languages.toml" = {
        generator = (pkgs.formats.toml { }).generate "helix-languages.toml";
        value.language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
          }
          {
            name = "toml";
            auto-format = true;
          }
        ];
      };
    };
  };
}
