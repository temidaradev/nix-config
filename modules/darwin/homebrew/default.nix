{ ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
      extraFlags = [ "--force" ];
    };

    taps = [
      "charmbracelet/tap"
      "gromgit/fuse"
      "koekeishiya/formulae"
      "nikitabobko/tap"
      "osx-cross/avr"
      "sikarugir-app/sikarugir"
    ];

    brews = [
      "mas"

      # macOS-specific
      "nowplaying-cli"
      "switchaudio-osx"
      "pidof"
      "koekeishiya/formulae/skhd"

      # nixpkgs-darwin pain
      "cocoapods"
      "llvm@15"
      "llvm@19"
      "postgresql@14"
      "postgresql@15"
      "node@20"
      "powerlevel10k"

      # version managers
      "nvm"
      "pyenv"

      # FUSE / macfuse-dependent
      "gromgit/fuse/ext2fuse-mac"
      "gromgit/fuse/sshfs-mac"

      # custom taps
      "charmbracelet/tap/markscribe"
      "osx-cross/avr/avr-gcc@9"

      # cleaner on brew
      "handbrake"
      "faudio"
      "molten-vk"
      "opencode"
      "opencv"
      "emscripten"
      "git-flow-avh"
      "gradle"
      "mole"
      "clipboard"
      "ghidra"
      "jackett"
      "lsusb"
      "mingw-w64"
      "putty"
      "qt"
      "winetricks"

      "ffmpeg"
      "streamrip"
    ];

    casks = [
      "alacritty"
      "android-platform-tools"
      "audacity"
      "cabal"
      "cyberduck"
      "docker-desktop"
      "easy-move+resize"
      "emacs-app"
      "font-hack-nerd-font"
      "font-sf-mono"
      "font-sf-pro"
      "gcc-arm-embedded"
      "godot"
      "google-chrome"
      "gstreamer-runtime"
      "ios-app-signer"
      "iterm2"
      "itsycal"
      "karabiner-elements"
      "kitty"
      "lm-studio"
      "localsend"
      "macfuse"
      "middleclick"
      "miniforge"
      "mullvad-vpn"
      "nikitabobko/tap/aerospace"
      "ngrok/ngrok/ngrok"
      "pear-desktop"
      "qt-creator"
      "rectangle"
      "sf-symbols"
      "signal"
      "sikarugir"
      "sioyek"
      "stats"
      "thonny"
      "tigervnc"
      "unnaturalscrollwheels"
      "upscayl"
      "vlc"
      "vnc-viewer"
      "warp"
      "wine-stable"
      "xdeck"
      "xld"
      "zulu@17"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "Cake Wallet" = 1334702542;
      "CapCut" = 1500855883;
      "Developer" = 640199958;
      "FreeChat" = 6458534902;
      "GarageBand" = 682658836;
      "Hidden Bar" = 1452453066;
      "iMovie" = 408981434;
      "Keynote" = 409183694;
      "Monal" = 1637078500;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Raycast Companion" = 6738274497;
      "Telegram" = 747648890;
      "The Unarchiver" = 425424353;
      "uBlock Origin Lite" = 6745342698;
      "Unzip - RAR ZIP 7Z Unarchiver" = 1537056818;
      "WhatsApp" = 310633997;
      "Xcode" = 497799835;
    };
  };
}
