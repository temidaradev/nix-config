{ pkgs }:

with pkgs; {
  system = [
    opentabletdriver
    # Gaming
    lunar-client
    osu-lazer
    heroic

    # Networking
    proton-vpn
    nicotine-plus
    google-chrome

    # Hardware
    kdePackages.qtmultimedia
    qt6Packages.qtbase
    qt6Packages.qttools
    qt6Packages.qtsvg
    qt6Packages.qtdeclarative
    qt6Packages.qtwayland
    qt6Packages.qtwebsockets
    cava
    direnv

    # MTP support for Android devices
    libmtp
    jmtpfs
    doublecmd
    rar
    scrcpy

    # iphone stuff
    libimobiledevice
    ifuse
    usbmuxd

    # Virtualization
    vmware-workstation
    docker

    # Desktop
    bibata-cursors
    flatpak
    fuzzel
    swaylock
    swayidle
    xwayland-satellite
    feh
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    fwupd
    whatsapp-electron
    ffmpeg
    discordo
    youtube-tui
    sioyek
    gsmartcontrol
    smartmontools
    kdePackages.konsole
    conky
    eww
    tradingview
    qbittorrent
    localsend
    jellyfin-media-player
    parted
    ollama
    alacritty
    fzf
    zoxide
    eza
    librespot

    # Development tools
    git
    qmk
    qmk-udev-rules
    hidapi
    cachix
    avrdude
    dfu-programmer
    dfu-util
    dos2unix
    alsa-lib
    gnumake
    gh
    unzip
    luajit
    (btop.override { cudaSupport = false; rocmSupport = false; })
    fastfetch
    arduino-ide
    ddcutil
    brightnessctl
    networkmanager
    lm_sensors
    fish
    openssl
    openssl.dev
    android-studio
    solaar
    aubio
    docker-compose
    pipewire
    postgresql
    swappy
    cargo-tauri
    trunk
    libqalculate
    material-symbols
    nerd-fonts.caskaydia-cove
    kitty
    slack
    dioxus-cli
    sqlite
    picotool
    stripe-cli
    tigervnc
    xmrig
    chromium
    autossh
    glib-networking
    libsoup_3
    libsecret
    gtk3
    webkitgtk_4_1
    xdotool

    # Editors
    vim
    antigravity
    neovim
    helix
    vscode
    zed-editor
    lmstudio

    # Languages
    openjdk17
    uv
    pkg-config
    odin
    ghc
    cabal-install
    go
    rustc
    rustup
    gcc
    binutils
    libGL
    wget
    glm
    glib
    glibc
    zlib
    zig
    lua

    # Hyprland
    waybar
    wofi

    # Desktop tools
    yt-dlp
    wl-clipboard
    grim
    slurp
    wf-recorder
    imagemagick
    gpu-screen-recorder
    nixos-icons
    papirus-icon-theme
    adwaita-icon-theme
    gnome-icon-theme
    hicolor-icon-theme
    pantheon.elementary-icon-theme
    tango-icon-theme
    arc-icon-theme
    shared-mime-info
    qalculate-gtk
    kdePackages.gwenview
    mpv
    pavucontrol
    playerctl
    pamixer
    alsa-utils
    zip
    calibre
    ani-cli
    gnome-themes-extra
    ollama

    # Fonts
    noto-fonts-cjk-sans
    nerd-fonts.jetbrains-mono

    # Applications
    thunderbird
    firefox
    telegram-desktop
    pear-desktop
    blender
    godot
    kitty
    ghostty
    kdePackages.dolphin
    wine
  ];
}
