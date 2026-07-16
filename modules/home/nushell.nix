{ pkgs, hmUsername, ... }:

let
  # Shell integrations generated at build time so config.nu can `source` them.
  starshipInit = pkgs.runCommand "starship-init.nu" { } ''
    ${pkgs.starship}/bin/starship init nu > $out
  '';

  zoxideInit = pkgs.runCommand "zoxide-init.nu" { } ''
    ${pkgs.zoxide}/bin/zoxide init nushell --cmd cd > $out
  '';
in
{
  hjem.users.${hmUsername} = {
    packages = [ pkgs.nushell ];

    xdg.config.files."nushell/env.nu".text = ''
      # Children spawned from nu (e.g. typing `zsh`) must stay zsh.
      $env.ZSH_NO_NU = "1"

      # One-time: seed nushell history from zsh history.
      # Strips the extended-history `: <ts>:<dur>;` prefix.
      let zsh_hist = $env.HOME | path join ".zsh_history"
      if ($zsh_hist | path exists) and (not ($nu.history-path | path exists)) {
        try {
          open --raw $zsh_hist
          | lines
          | each {|line| $line | str replace --regex '^: \d+:\d+;' "" }
          | to text
          | save $nu.history-path
        }
      }
    '';

    xdg.config.files."nushell/config.nu".text = ''
      $env.config.show_banner = false
      $env.config.history.max_size = 100000

      alias lg = lazygit
      alias gs = ^git status
      alias gp = ^git push
      alias gl = ^git pull
      alias js = jj status
      alias jl = jj log
      alias jd = jj diff

      # Create a directory and cd into it.
      def --env mc [path: path]: nothing -> nothing {
        mkdir $path
        cd $path
      }

      # Create a directory, cd into it and initialize version control.
      def --env mcg [path: path]: nothing -> nothing {
        mkdir $path
        cd $path
        jj git init
      }

      source ${starshipInit}
      source ${zoxideInit}

      # direnv hook
      $env.config.hooks.pre_prompt = (
        $env.config.hooks.pre_prompt? | default [] | append {||
          let direnv = ^direnv export json | from json | default {}
          if ($direnv | is-not-empty) { $direnv | load-env }
        }
      )
    '';
  };
}
