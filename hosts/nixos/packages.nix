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

    # MTP support for Android devices
    libmtp
    jmtpfs
    doublecmd
    rar

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
    discordo
    youtube-tui
    gsmartcontrol
    smartmontools
    kdePackages.konsole
    conky
    eww
    tradingview
    qbittorrent
    jellyfin-media-player
    parted
    alacritty
    librespot

    # Development tools
    qmk
    qmk-udev-rules
    hidapi
    cachix
    alsa-lib
    unzip
    (btop.override { cudaSupport = false; rocmSupport = false; })
    arduino-ide
    ddcutil
    brightnessctl
    networkmanager
    lm_sensors
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
    xdotool

    # Editors
    antigravity
    vscode
    zed-editor
    lmstudio

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

    # Hyprland
    waybar
    wofi

    # Desktop tools
    wl-clipboard
    grim
    slurp
    wf-recorder
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
    pavucontrol
    playerctl
    pamixer
    alsa-utils
    calibre
    ani-cli
    gnome-themes-extra

    # Applications
    thunderbird
    firefox
    telegram-desktop
    pear-desktop
    blender
    godot
    ghostty
    kdePackages.dolphin
    wine
  ];
}
