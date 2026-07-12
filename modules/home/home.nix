{ pkgs, lib, ... }:

{
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    eza
    bat
    fd
    ripgrep
    tealdeer
    glow
    yt-dlp
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      share = true;
    };

    shellAliases = {
      ls = "eza";
      ll = "eza -l --git";
      la = "eza -la --git";
      lt = "eza --tree";
      cat = "bat";
      lg = "lazygit";
      gs = "git status";
      gp = "git push";
      gl = "git pull";
      js = "jj status";
      jl = "jj log";
      jd = "jj diff";
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    initContent = ''
      export GPG_TTY=$(tty)
      export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"

      # Case-insensitive tab completion (doc -> Documents)
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

      # Up/Down search history by typed prefix (e.g. type "nh" then Up)
      autoload -U up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey '^[[A' up-line-or-beginning-search
      bindkey '^[[B' down-line-or-beginning-search
      bindkey "''${terminfo[kcuu1]}" up-line-or-beginning-search
      bindkey "''${terminfo[kcud1]}" down-line-or-beginning-search

      # `nh switch` anywhere -> rebuild this flake
      nh() {
        if [[ "$1" == "switch" ]]; then
          command nh darwin switch ~/Projects/nix-config "''${@:2}"
        else
          command nh "$@"
        fi
      }
    '' + lib.optionalString pkgs.stdenv.isDarwin ''
      # macOS-only: keep Homebrew tools on PATH
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
    '';
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.lazygit.enable = true;

  programs.tmux.enable = true;

  programs.fastfetch.enable = true;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "temidaradev";
        email = "temidaradev@proton.me";
      };
      ui = {
        default-command = "log";
        pager = "less -FRX";
      };
      signing = {
        behavior = "own";
        backend = "gpg";
        key = "CF0CCF7E9AD5BD9D";
      };
    };
  };
}
