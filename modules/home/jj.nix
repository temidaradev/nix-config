{ pkgs, hmUsername, ... }:

{
  hjem.users.${hmUsername} = {
    packages = with pkgs; [
      jujutsu
      lazygit
      difftastic
      mergiraf
      watchman
    ];

    xdg.config.files = {
      "jj/config.toml" = {
        generator = (pkgs.formats.toml { }).generate "jj-config.toml";
        value = {
          user = {
            name = "temidaradev";
            email = "temidaradev@proton.me";
          };

          aliases = {
            ".." = [ "edit" "@-" ];
            ",," = [ "edit" "@+" ];

            f = [ "git" "fetch" ];
            p = [ "git" "push" ];
            cl = [ "git" "clone" ];
            i = [ "git" "init" ];

            a = [ "abandon" ];

            c = [ "commit" ];
            ci = [ "commit" "--interactive" ];

            d = [ "diff" ];
            e = [ "edit" ];

            l = [ "log" ];
            la = [ "log" "--revisions" "::" ];

            s = [ "squash" ];
            si = [ "squash" "--interactive" ];

            u = [ "undo" ];

            # AST-aware conflict resolution via mergiraf
            resolve-ast = [ "resolve" "--tool" "${pkgs.mergiraf}/bin/mergiraf" ];
          };

          revsets.log = ''
            present(@) | present(trunk()) | ancestors(remote_bookmarks().. | @.., 8)
          '';

          ui = {
            default-command = "log";
            pager = "less -FRX";
            diff-editor = ":builtin";
            conflict-marker-style = "snapshot";
            graph.style = "curved";
            # Structural, syntax-aware diffs
            diff-formatter = [
              "${pkgs.difftastic}/bin/difft"
              "--color"
              "always"
              "$left"
              "$right"
            ];
          };

          # Watchman filesystem monitor: fast `jj st`/snapshotting in big repos
          fsmonitor = {
            backend = "watchman";
            watchman.register-snapshot-trigger = true;
          };

          templates.draft_commit_description = ''
            concat(
              coalesce(description, "\n"),
              surround(
                "\nJJ: This commit contains the following changes:\n", "",
                indent("JJ:     ", diff.stat(72)),
              ),
              "\nJJ: ignore-rest\n",
              diff.git(),
            )
          '';

          templates.git_push_bookmark = ''
            "temidaradev/change-" ++ change_id.short()
          '';

          remotes."*" = {
            auto-track-bookmarks = "temidaradev/*";
            push-new-bookmarks = true;
          };

          signing = {
            behavior = "own";
            backend = "gpg";
            key = "CF0CCF7E9AD5BD9D";
          };
        };
      };

      "watchman/watchman.json" = {
        generator = (pkgs.formats.json { }).generate "watchman.json";
        value = {
          ignore_dirs = [
            ".direnv"
            "node_modules"
            "target"
          ];
        };
      };
    };
  };
}
