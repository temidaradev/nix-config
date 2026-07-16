{ pkgs }:

with pkgs; [
  # Shell + CLI
  fish
  git
  gh
  dos2unix
  gnumake
  wget
  openssl
  pkg-config
  zip

  # Embedded / hardware
  avrdude
  dfu-util
  dfu-programmer
  picotool

  # Editors
  vim
  # neovim now comes from modules/home/nvim (standalone nvf wrapper).
  helix

  # Languages / toolchains
  go
  zig
  ghc
  cabal-install
  openjdk17
  rustup
  luajit
  lua

  # Media / graphics
  ffmpeg
  imagemagick
  #mpv
  glm

  # Apps / misc
  localsend
  scrcpy
  ollama
  cava
  xmrig
]
