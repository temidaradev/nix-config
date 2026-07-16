{ pkgs, hmUsername, ... }:

{
  hjem.users.${hmUsername} = {
    packages = with pkgs; [
      fd
      ripgrep
      direnv
      yt-dlp
      hyperfine
      tokei
      typos
    ];

    files.".ssh/config".text = ''
      Host *
        SetEnv COLORTERM=truecolor

        # Reuse one connection per host: instant repeat ssh/scp/jj push
        ControlMaster auto
        ControlPersist 60m
        ControlPath ~/.cache/ssh/%r@%n:%p
    '';

    xdg.config.files = {
      "direnv/direnvrc".text = ''
        source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
      '';

      "ripgrep/config".text = ''
        --line-number
        --smart-case
      '';
    };
  };
}
