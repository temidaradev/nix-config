{ lib, ... }:

let
  trustedTaps = [
    "charmbracelet/tap"
    "gromgit/fuse"
    "nikitabobko/tap"
    "osx-cross/avr"
    "pear-devs/pear"
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
      "nikitabobko/tap/aerospace"
      "alacritty"
      "android-platform-tools"
      "audacity"
      "blender"
      "cabal"
      "docker-desktop"
      "easy-move+resize"
      "firefox"
      "font-hack-nerd-font"
      "font-sf-mono"
      "font-sf-pro"
      "gcc-arm-embedded"
      "ghostty"
      "godot"
      "google-chrome"
      "gstreamer-runtime"
      "ios-app-signer"
      "iterm2"
      "itsycal"
      "keepassxc"
      "kitty"
      "libreoffice"
      "localsend"
      "maccy"
      "macfuse"
      "miniforge"
      "mullvad-vpn"
      "obs"
      "obsidian"
      "ollama-app"
      "pear-desktop"
      "postman"
      "proxyman"
      "qt-creator"
      "raycast"
      "realvnc-connect-viewer"
      "rectangle"
      "sf-symbols"
      "signal"
      "slack"
      "steam"
      "tailscale-app"
      "thonny"
      "tigervnc"
      "visual-studio-code"
      "vlc"
      "warp"
      "wine-stable"
      "xld"
      "zed"
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
      "Xcode" = 497799835;
    };
  };
}
