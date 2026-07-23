{ pkgs, lib, hmUsername, ... }:

let
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
    alias tree='eza --tree --git-ignore --group-directories-first'
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
    alias cp='cp -rv'
    alias mv='mv -v'

    # Create a directory and cd into it.
    mc() {
      mkdir -p "$1" && cd "$1"
    }

    # Create a directory, cd into it and initialize version control.
    mcg() {
      mkdir -p "$1" && cd "$1" && jj git init
    }

    export GPG_TTY=$(tty)
    export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"

    # Pager: quit if one screen, case-insensitive incremental search,
    # no line wrapping, keep colors, highlight unread portion
    export LESS='--quit-if-one-screen --quit-on-intr --ignore-case --incsearch --LONG-PROMPT --no-edit-warn --chop-long-lines --HILITE-UNREAD --tilde --RAW-CONTROL-CHARS'

    # Colored man pages via bat
    export MANROFFOPT='-c'
    export MANPAGER="sh -c 'col -bx | bat --language man --plain --color always'"

    export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"

    # ssh connection multiplexing needs its socket directory
    [[ -d "$HOME/.cache/ssh" ]] || mkdir -p "$HOME/.cache/ssh"

    # Get the realpath of a program on PATH.
    realwhich() {
      readlink -f "$(command -v "$1")"
    }

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

    # Route interactive zsh into nushell once env/PATH are set.
    # Use the nix-managed nushell by absolute store path so a stale
    # `~/.cargo/bin/nu` (broken/old) can't shadow it and abort the exec.
    # Escape hatch: `ZSH_NO_NU=1 zsh` (nu also sets this for its children).
    # Disabled for now: stay in zsh instead of exec'ing into nushell.
    # if [[ -o interactive && -z "$ZSH_NO_NU" ]]; then
    #   exec ${pkgs.nushell}/bin/nu
    # fi

    # Shell integrations
    eval "$(starship init zsh)"
    eval "$(zoxide init zsh --cmd cd)"
    source <(fzf --zsh)
    eval "$(direnv hook zsh)"

    # Must be sourced last
    source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  '';
in
{
  hjem.users.${hmUsername} = {
    packages = with pkgs; [
      eza
      bat
      starship
      tmux
      fastfetch
      zoxide
      fzf
      tealdeer
      glow
    ];

    files.".zshrc".text = zshrc;

    # Silence macOS "Last login" banner
    files.".hushlogin".text = "";
  };
}
