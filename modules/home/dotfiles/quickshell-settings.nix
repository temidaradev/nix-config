# Defaults for the niri shell. Shipped as ~/.config/quickshell/settings.json.
# Anything changed from the shell's Settings window is stored as an override in
# ~/.local/state/quickshell/settings.json; "Export" there gives you a snippet
# to paste back here, "Reset" drops the overrides.
{
  appearance = {
    accent = "#3daee9";        # Breeze blue
    panelOpacity = 0.95;       # 0..1, bar and popups
    barHeight = 36;
    radius = 4;
    font = "JetBrainsMono Nerd Font";
    fontSize = 10;
  };

  bar = {
    # right-side widgets, in display order; set to false to hide
    tray = true;
    layout = true;
    volume = true;
    bluetooth = true;
    battery = true;
    cpu = true;
    memory = true;
    temps = true;
    disk = true;
    network = true;
    notifications = true;
    control = true;
    sidebar = true;
    # centre
    nowPlaying = true;
    marqueeWidth = 220;
    clockFormat = "HH:mm";
    dateFormat = "ddd d MMM";
  };

  # desktop ids shown in the sidebar's quick launch
  pinned = [
    "org.kde.dolphin" "zen-beta" "code" "dev.zed.Zed" "discord"
    "moe.kopuz.kopuz" "com.mitchellh.ghostty" "steam" "thunderbird" "org.jellyfin.JellyfinDesktop"
  ];

  weather = { city = "Istanbul"; };

  osd = { timeoutMs = 1500; bottomMargin = 90; };

  notifications = { timeoutMs = 6000; maxPopups = 5; };

  wallpaper = "";              # empty = the one shipped in the repo
}
