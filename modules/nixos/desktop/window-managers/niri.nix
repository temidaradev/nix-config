{ config, lib, pkgs, ... }:

let
  sidebarPython = pkgs.python3.withPackages (ps: [ ps.icalendar ps.python-dateutil ]);
  sidebarBackend = pkgs.writeShellApplication {
    name = "shell-sidebar-backend";
    runtimeInputs = with pkgs; [ pipewire wireplumber pulseaudio procps iputils networkmanager niri wl-clipboard cliphist libnotify systemd polkit wlsunset wf-recorder ];
    text = ''
      exec ${sidebarPython}/bin/python3 ${../../../home/dotfiles/quickshell/scripts/sidebar.py} "$@"
    '';
  };
  clipboardStore = pkgs.writeShellApplication {
    name = "shell-clipboard-store";
    runtimeInputs = [ pkgs.cliphist pkgs.coreutils ];
    text = ''
      if [[ ! -e "''${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/clipboard-paused" ]]; then
        exec cliphist store
      fi
      exec cat >/dev/null
    '';
  };
  # Desktop theme switch: normal (Breeze) <-> steinsgate. The shell watches the
  # state file; niri and ghostty pick up the copied override files through
  # optional includes (both live-reload; ghostty is nudged with SIGUSR2).
  steinsGate = ../../../home/dotfiles/themes/steinsgate;
  ghosttySteins = pkgs.replaceVars "${steinsGate}/ghostty" { background = "${steinsGate}/terminal.jpg"; };
  shellTheme = pkgs.writeShellApplication {
    name = "shell-theme";
    runtimeInputs = [ pkgs.coreutils pkgs.procps pkgs.gnugrep pkgs.findutils pkgs.glib pkgs.gawk pkgs.diffutils ];
    text = ''
      dir="''${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
      cfg="''${XDG_CONFIG_HOME:-$HOME/.config}"
      mkdir -p "$dir"
      cur=$(cat "$dir/theme" 2>/dev/null || echo normal)
      refresh=1
      case "''${1:-toggle}" in
        get) echo "$cur"; exit 0 ;;
        toggle) if [[ $cur == steinsgate ]]; then new=normal; else new=steinsgate; fi ;;
        apply) new=$cur; refresh=0 ;;   # login / after a rebuild: re-sync the files only
        normal|steinsgate) new=$1 ;;
        *) echo "usage: shell-theme [toggle|normal|steinsgate|get|apply]" >&2; exit 2 ;;
      esac
      sg=${steinsGate}
      steins() { [[ $new == steinsgate ]]; }

      put() {   # atomic, so file watchers never see half a file
        mkdir -p "$(dirname "$1")"
        if [[ -n $2 ]]; then install -m 644 "$2" "$1.tmp"; else printf '%s\n' "$3" > "$1.tmp"; fi
        mv -f "$1.tmp" "$1"
      }
      # A file the user may already have (gtk.css...): keep their copy while
      # Steins;Gate is on and put it back after. Never touch hjem symlinks.
      swap() {
        local target=$1 src=$2 bak; bak="$dir/normal/$(printf %s "$1" | md5sum | cut -c1-12)"
        [[ -L $target ]] && return 0
        if steins; then
          if [[ -e $target ]] && ! grep -qs 'shell-theme: steinsgate' "$target"; then mkdir -p "$dir/normal"; cp -f "$target" "$bak"; fi
          put "$target" "$src"
        elif grep -qs 'shell-theme: steinsgate' "$target"; then
          if [[ -e $bak ]]; then put "$target" "$bak"; else rm -f "$target"; fi
        fi
      }

      # niri + ghostty: optional includes, both live-reload
      if steins; then
        put "$dir/niri-theme.kdl" "$sg/niri.kdl"
        put "$dir/ghostty-theme" ${ghosttySteins}
      else
        put "$dir/niri-theme.kdl" "" "// normal theme: no overrides"
        put "$dir/ghostty-theme" "" "# normal theme: no overrides"
      fi

      # GTK 3/4 + libadwaita
      swap "$cfg/gtk-3.0/gtk.css" "$sg/gtk.css"
      swap "$cfg/gtk-4.0/gtk.css" "$sg/gtk.css"

      # Vencord (watches its themes dir), btop, helix
      if steins; then
        put "$cfg/Vencord/themes/steinsgate.css" "$sg/vencord.css"
        put "$cfg/btop/themes/shell.theme" "$sg/btop.theme"
        put "$cfg/helix/themes/shell.toml" "$sg/helix.toml"
      else
        put "$cfg/Vencord/themes/steinsgate.css" "" "/* normal theme */"
        rm -f "$cfg/btop/themes/shell.theme"
        put "$cfg/helix/themes/shell.toml" "" 'inherits = "gruvbox_dark_soft"'
      fi

      # Zen: chrome/steinsgate.css imported from userChrome.css (next start)
      for prefs in "$HOME"/.zen/*/prefs.js "$cfg"/zen/*/prefs.js; do
        [[ -e $prefs ]] || continue
        p=$(dirname "$prefs")
        if steins; then
          put "$p/chrome/steinsgate.css" "$sg/zen.css"
          uc="$p/chrome/userChrome.css"
          if ! grep -qs 'steinsgate.css' "$uc"; then
            { echo '@import url("steinsgate.css");   /* shell-theme */'; cat "$uc" 2>/dev/null || true; } > "$uc.tmp" && mv -f "$uc.tmp" "$uc"
          fi
          grep -qs 'legacyUserProfileCustomizations.stylesheets' "$p/user.js" \
            || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$p/user.js"
        elif [[ -e $p/chrome/steinsgate.css ]]; then
          put "$p/chrome/steinsgate.css" "" "/* normal theme */"
        fi
      done

      kz="$cfg/kopuz/settings.toml"
      if [[ -f $kz ]]; then
        kzsaved="$dir/normal/kopuz-theme"
        kzcur=$(awk -F'"' '/^\[/ { exit } /^theme *=/ { print $2; exit }' "$kz")
        if steins; then
          if [[ $kzcur != steinsgate ]]; then mkdir -p "$dir/normal"; printf '%s' "''${kzcur:-system}" > "$kzsaved"; fi
          kztheme=steinsgate
        elif [[ $kzcur == steinsgate ]]; then
          kztheme=$(cat "$kzsaved" 2>/dev/null || echo system)
        else
          kztheme=$kzcur
        fi
        awk -v t="$kztheme" -v pal="$sg/kopuz.toml" '
          function line(s) { out[++n] = s }
          /^\[/ {
            if (!seen && t != "") { line("theme = \"" t "\""); seen = 1 }
            top = 1; skip = ($0 ~ /^\[custom_themes\.steinsgate[].]/)
          }
          skip { next }
          !top && /^theme *=/ { if (t != "") line("theme = \"" t "\""); seen = 1; next }
          { line($0) }
          END {
            if (!seen && t != "") line("theme = \"" t "\"")
            while (n > 0 && out[n] ~ /^[ \t]*$/) n--
            for (i = 1; i <= n; i++) print out[i]
            print ""
            while ((getline l < pal) > 0) print l
          }' "$kz" > "$kz.tmp"
        if cmp -s "$kz" "$kz.tmp"; then rm -f "$kz.tmp"; else mv -f "$kz.tmp" "$kz"; fi
      fi

      printf '%s' "$new" > "$dir/theme.tmp" && mv -f "$dir/theme.tmp" "$dir/theme"

      if (( refresh )); then
        # Qt/KDE apps repaint on the colour-scheme change signal
        if command -v plasma-apply-colorscheme >/dev/null; then
          if steins; then plasma-apply-colorscheme SteinsGate >/dev/null 2>&1 || true
          else plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || true; fi
        fi
        # GTK apps re-read gtk.css when the theme changes; libadwaita follows accent-color
        gs() { gsettings "$@" 2>/dev/null || true; }
        if steins; then gs set org.gnome.desktop.interface accent-color orange; else gs set org.gnome.desktop.interface accent-color blue; fi
        theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || true)
        if [[ -n $theme ]]; then gs set org.gnome.desktop.interface gtk-theme Adwaita; sleep 0.3; gs set org.gnome.desktop.interface gtk-theme "$theme"; fi
      fi

      # ghostty and helix reload their config on a signal (nixpkgs names: .ghostty-wrapped, hx)
      pkill -USR2 -x '\.?ghostty(-wrappe(d)?)?' 2>/dev/null || true
      pkill -USR1 -x 'hx|\.hx-wrapped' 2>/dev/null || true
      [[ ''${1:-} == apply ]] || echo "$new"
    '';
  };
  # Spawned from config.kdl; wrappers keep store paths out of it.
  polkitAgent = pkgs.writeShellScriptBin "niri-polkit-agent" ''
    exec ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
  '';
  gtkSettings = pkgs.writeShellScriptBin "niri-gtk-settings" ''
    g=${pkgs.glib}/bin/gsettings
    $g set org.gnome.desktop.interface gtk-theme 'Breeze-Dark'
    $g set org.gnome.desktop.interface color-scheme 'prefer-dark'
    $g set org.gnome.desktop.interface icon-theme 'breeze-dark'
    $g set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
    $g set org.gnome.desktop.interface cursor-size 32
    $g set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 10'
    $g set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'
  '';
  # Mod+Shift+S: pick an area, annotate in swappy (which saves + copies).
  screenshot = pkgs.writeShellScriptBin "niri-screenshot" ''
    set -e
    mkdir -p "$HOME/Pictures/Screenshots"
    area=$(${pkgs.slurp}/bin/slurp) || exit 0
    ${pkgs.grim}/bin/grim -g "$area" - | ${pkgs.swappy}/bin/swappy -f -
  '';

  # PATH for the shell service: NixOS gives user services a minimal PATH, and
  # everything launched from the app drawer inherits it.
  sessionPath = [
    "/run/wrappers"
    "/run/current-system/sw"
    "/etc/profiles/per-user/%u"
    "%h/.nix-profile"
    "%h/.local/state/nix/profile"
    "/nix/var/nix/profiles/default"
    "%h/.local/share/flatpak/exports"
    "/var/lib/flatpak/exports"
  ];
in
{
  programs.niri.enable = true;

  # plasma6 and niri both set this at the same priority; niri wins on the
  # SDDM login screen, Plasma stays selectable in the session menu.
  services.displayManager.defaultSession = lib.mkForce "niri";

  environment.systemPackages = with pkgs; [
    quickshell
    xwayland-satellite   # niri spawns it automatically when found in PATH
    fuzzel
    swaylock
    networkmanagerapplet # nm-connection-editor, opened from the control center
    pavucontrol
    nixos-icons          # nix-snowflake icon used by the launcher button
    playerctl
    cava                 # visualizer in the dashboard
    libqalculate         # "=" calculator in the launcher
    imagemagick          # accent-from-wallpaper
    libnotify            # notify-send, lands in the shell's notification daemon
    cmf-buds
    sony-xm5
    mouse-battery
    airpods
    curl
    pciutils             # lspci, for the GPU name in the system tab
    grim
    slurp
    swappy
    wl-clipboard
    cliphist             # clipboard history shown in the sidebar
    sidebarBackend
    clipboardStore
    easyeffects
    wlsunset
    wf-recorder
    polkitAgent
    gtkSettings
    screenshot
    shellTheme
  ];

  # niri wants the GNOME portal for screencast/screenshot; the GTK one covers
  # file pickers and the Settings interface (fonts, dark mode) for GTK apps.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  xdg.portal.config.niri.default = [ "gnome" "gtk" ];

  programs.dconf.enable = true;          # gsettings backend for the GTK theme
  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;
  security.pam.services.swaylock = { };

  # The shell. Only niri.service wants it, so it never starts under Plasma or
  # Hyprland; it stops with the session and restarts if it crashes.
  systemd.user.services.quickshell-niri = {
    description = "Quickshell (niri shell)";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    requisite = [ "graphical-session.target" ];
    wantedBy = [ "niri.service" ];
    path = sessionPath;
    environment = {
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "kde";
    };
    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.quickshell}/bin/qs";
      Restart = "on-failure";
      RestartSec = "2s";
      TimeoutStopSec = "5s";
      Slice = "session.slice";
    };
  };
}
