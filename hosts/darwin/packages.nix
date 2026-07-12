{ pkgs }:

with pkgs; {
  system = [
    # Shell + CLI
    bash
    nushell
    git-lfs
    gnupg
    pinentry_mac
    lsd
    btop
    curl
    gnused
    automake
    cmake
    ninja
    just
    patch
    figlet
    cmatrix
    lolcat
    rich-cli
    nmap
    mtr
    inetutils
    libpcap
    czkawka
    qemu
    watchman

    # macOS hardware/embedded
    esptool
    micropython

    # Editors
    neovim-remote
    emacs
    bear

    # Languages / toolchains
    python312
    nodejs_22
    pnpm
    yarn
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
    graphicsmagick
    vips
    ghostscript

    # SDL2
    SDL2
    SDL2_gfx
    SDL2_image
    SDL2_mixer
    SDL2_net
    SDL2_ttf

    # Networking
    nikto
    dnsmap
  ];
}
