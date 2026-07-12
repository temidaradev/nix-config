{ config, lib, ... }:

let
  # Homebrew 6.x refuses to load formulae/casks from untrusted third-party taps
  # unless they are recorded in ~/.homebrew/trust.json. Trusting whole taps also
  # covers their transitive deps (e.g. osx-cross/avr/avr-binutils pulled in by
  # avr-gcc@9), which per-formula trust does not.
  tapNames = map (t: if builtins.isString t then t else t.name) config.homebrew.taps;
  declaredTaps = lib.concatStringsSep "\n" tapNames;
in
{
  # Trust every third-party tap before `brew bundle` runs so activation never
  # fails on an untrusted tap. Trusts the union of taps declared below AND any
  # taps already installed (e.g. auto-tapped by an unprefixed cask like
  # pear-desktop -> pear-devs/pear) — so no per-tap edits are ever needed.
  # preActivation runs early, ahead of the homebrew phase.
  system.activationScripts.preActivation.text = ''
    echo "seeding homebrew tap trust..." >&2
    /usr/bin/install -d -o lidldev -g staff -m 700 /Users/lidldev/.homebrew
    {
      printf '%s\n' ${lib.escapeShellArg declaredTaps}
      [ -x /opt/homebrew/bin/brew ] && /usr/bin/sudo -u lidldev /opt/homebrew/bin/brew tap 2>/dev/null
    } | grep -v '^homebrew/' | sort -u | grep . \
      | /usr/bin/awk 'BEGIN{printf "{\"trustedtaps\":["} NR>1{printf ","} {printf "\"%s\"", $0} END{printf "]}\n"}' \
      > /Users/lidldev/.homebrew/trust.json
    chown lidldev:staff /Users/lidldev/.homebrew/trust.json
    chmod 600 /Users/lidldev/.homebrew/trust.json
  '';

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
      "osx-cross/avr"
      "pear-devs/pear"
      "sikarugir-app/sikarugir"
    ];

    brews = [
      "mas"

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
      "kitty"
      "lm-studio"
      "localsend"
      "macfuse"
      "middleclick"
      "miniforge"
      "mullvad-vpn"
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
