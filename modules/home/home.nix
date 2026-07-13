{ pkgs, lib, ... }:

let
  username = if pkgs.stdenv.isDarwin then "lidldev" else "temidaradev";

  zshrc = ''
    # Completion
    autoload -U compinit && compinit

    # Case-insensitive tab completion (doc -> Documents)
    zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

    # Plugins
    source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh

    # History
    HISTSIZE=10000
    SAVEHIST=10000
    HISTFILE="$HOME/.zsh_history"
    setopt HIST_IGNORE_DUPS
    setopt SHARE_HISTORY

    # Aliases
    alias ls='eza'
    alias ll='eza -l --git'
    alias la='eza -la --git'
    alias lt='eza --tree'
    alias cat='bat'
    alias lg='lazygit'
    alias gs='git status'
    alias gp='git push'
    alias gl='git pull'
    alias js='jj status'
    alias jl='jj log'
    alias jd='jj diff'
    alias ..='cd ..'
    alias ...='cd ../..'

    export GPG_TTY=$(tty)
    export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"

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
  '' + ''

    # Shell integrations
    eval "$(starship init zsh)"
    eval "$(zoxide init zsh)"
    source <(fzf --zsh)
    eval "$(direnv hook zsh)"

    # Must be sourced last
    source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  '';
in
{
  hjem.users.${username} = {
    enable = true;
    clobberFiles = true;

    packages = with pkgs; [
      eza
      bat
      fd
      ripgrep
      tealdeer
      glow
      yt-dlp

      starship
      lazygit
      tmux
      fastfetch
      zoxide
      fzf
      direnv
      jujutsu
    ];

    files.".zshrc".text = zshrc;

    xdg.config.files = {
      "direnv/direnvrc".text = ''
        source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
      '';

      "jj/config.toml" = {
        generator = (pkgs.formats.toml { }).generate "jj-config.toml";
        value = {
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
    };
  };
}
