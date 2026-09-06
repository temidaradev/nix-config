{ lib, ... }:

let
  trustedTaps = [
    "charmbracelet/tap"
    "gromgit/fuse"
    "osx-cross/avr"
    "pear-devs/pear"
    "sikarugir-app/sikarugir"
  ];
in
{
  # mas discovers installed App Store apps through Spotlight. Refresh the
  # application metadata before `brew bundle` runs so it does not try to
  # reinstall an app merely because its Spotlight entry is temporarily missing.
  system.activationScripts.preActivation.text = ''
    echo "indexing Mac App Store apps..." >&2
    /usr/bin/sudo -u lidldev /usr/bin/mdimport /Applications >/dev/null 2>&1 || true

    # Homebrew reads installed formulae while parsing the Brewfile, before its
    # `trusted: true` entries take effect. Bootstrap the same declarative tap
    # trust first; forced bundle cleanup then preserves these entries.
    if [ -x /opt/homebrew/bin/brew ]; then
      echo "seeding homebrew tap trust..." >&2
      /usr/bin/sudo --user=lidldev --set-home \
        /opt/homebrew/bin/brew trust --tap ${lib.escapeShellArgs trustedTaps}
    fi
  '';

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
      extraFlags = [ "--force" ];
    };

    taps = map (name: { inherit name; trusted = true; }) trustedTaps;

    brews = [
      "mas"
      "bazelisk"

      # macOS-specific
      "nowplaying-cli"
      "switchaudio-osx"
      "pidof"

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
      "kitty"
      "lm-studio"
      "localsend"
      "maccy"
      "macfuse"
      "middleclick"
      "miniforge"
      "mullvad-vpn"
      "ollama-app"
      "pear-desktop"
      "qt-creator"
      "raycast"
      "rectangle"
      "sf-symbols"
      "signal"
      "thonny"
      "tigervnc"
      "unnaturalscrollwheels"
      "vlc"
      "vnc-viewer"
      "warp"
      "wine-stable"
      "xdeck"
      "xld"
      "zulu@17"
    ];

    masApps = {
      "Cake Wallet" = 1334702542;
      "CapCut" = 1500855883;
      "Developer" = 640199958;
      "GarageBand" = 682658836;
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
      "Windows App" = 1295203466;
      "Xcode" = 497799835;
    };
  };
}
