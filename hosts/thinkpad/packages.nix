{ pkgs }:

# Laptop package set: the desktop list minus VMware, mining, tablet, and the
# heavier gaming extras.
with pkgs; {
  system = [
    # Networking
    localsend
    proton-vpn
    google-chrome

    # Hardware / Qt runtime for the shell and Qt apps
    kdePackages.qtmultimedia
    qt6Packages.qtbase
    qt6Packages.qttools
    qt6Packages.qtsvg
    qt6Packages.qtdeclarative
    qt6Packages.qtwayland
    qt6Packages.qtwebsockets
    libmtp
    go-mtpfs
    libimobiledevice
    ifuse
    usbmuxd
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
    gsmartcontrol
    smartmontools
    qbittorrent
    jellyfin-media-player
    parted
    alacritty
    librespot

    # Development tools
    cachix
    alsa-lib
    unzip
    (btop.override { cudaSupport = false; rocmSupport = false; })
    ddcutil
    brightnessctl
    networkmanager
    lm_sensors
    openssl.dev
    android-studio
    docker-compose
    pipewire
    postgresql
    swappy
    cargo-tauri
    trunk
    libqalculate
    material-symbols
    kitty
    slack
    dioxus-cli
    sqlite
    stripe-cli
    tigervnc
    chromium
    autossh
    glib-networking
    libsoup_3
    libsecret
    gtk3
    webkitgtk_4_1

    # Editors
    vscode
    zed-editor

    # Languages
    uv
    odin
    rustc
    gcc
    binutils
    libGL
    glib
    glibc
    zlib

    # Desktop tools
    wl-clipboard
    grim
    slurp
    wf-recorder
    gpu-screen-recorder
    nixos-icons
    papirus-icon-theme
    adwaita-icon-theme
    hicolor-icon-theme
    shared-mime-info
    qalculate-gtk
    kdePackages.gwenview
    pavucontrol
    playerctl
    pamixer
    alsa-utils

    # Applications
    thunderbird
    firefox
    telegram-desktop
    ghostty
    kdePackages.dolphin
  ];
}
