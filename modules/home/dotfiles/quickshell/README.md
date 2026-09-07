# quickshell shell for niri

Plasma-flavoured shell. Started by the `quickshell-niri` user service (see
modules/nixos/desktop/window-managers/niri.nix), which only runs in niri sessions.

```
shell.qml       entry point: one of each window per screen
Theme.qml       colours, font, bar height
services/       singletons
  Niri          niri IPC event stream: windows, workspaces, keyboard layout
  SysStats      cpu / mem / net from scripts/sysstats.sh
  Crypto        SOL/USD ticker
  Media         MPRIS player selection
  Launcher      which popup is open + `qs ipc` handlers
  Notifs        notification daemon (popups + history)
  Wallpaper     current wallpaper, persisted in ~/.local/state/quickshell/wallpaper
bar/            top bar, popups (app drawer, control center, media, calendar,
                tray menus, wallpaper picker), notification cards, OSD
desktop/        wallpaper layer + blurred overview backdrop
```

IPC from niri binds: `qs ipc call launcher|control|media|calendar toggle`.
Logs: `qs log` or `journalctl --user -u quickshell-niri`.
