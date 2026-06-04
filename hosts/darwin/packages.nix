{ pkgs }:

with pkgs; {
  system = [
    # Shell + CLI
    bash
    fish
    nushell
    git
    git-lfs
    gh
    gnupg
    pinentry_mac
    lazygit
    fzf
    zoxide
    eza
    lsd
    bat
    btop
    fastfetch
    tmux
    direnv
    curl
    wget
    gnused
    gnumake
    automake
    cmake
    ninja
    just
    patch
    dos2unix
    figlet
    cmatrix
    lolcat
    tealdeer
    glow
    rich-cli
    nmap
    mtr
    inetutils
    libpcap
    openssl
    pkg-config
    zip
    czkawka
    qemu
    watchman
    yt-dlp

    # macOS hardware/embedded
    avrdude
    dfu-util
    dfu-programmer
    esptool
    micropython
    picotool

    # Editors
    vim
    neovim
    neovim-remote
    helix
    emacs
    bear

    # Languages / toolchains
    go
    zig
    ghc
    cabal-install
    openjdk17
    python312
    nodejs_22
    pnpm
    yarn
    rustup
    luajit
    lua
    lua-language-server
    luarocks
    sccache
    clang-tools
    ccls
    stylua
    commitizen
    tailwindcss
    xcodegen

    # Media / graphics
    ffmpeg
    graphicsmagick
    imagemagick
    vips
    ghostscript
    mpv

    # SDL2
    SDL2
    SDL2_gfx
    SDL2_image
    SDL2_mixer
    SDL2_net
    SDL2_ttf
    glm

    # Networking / mining
    xmrig
    nikto
    dnsmap

    # Misc
    sioyek
    localsend
    scrcpy
    ollama
    cava

    # Fonts
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-cove
    noto-fonts-cjk-sans
  ];
}
