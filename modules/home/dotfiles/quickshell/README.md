# quickshell shell for niri

Plasma-flavoured shell. Started by the `quickshell-niri` user service (see
modules/nixos/desktop/window-managers/niri.nix), which only runs in niri sessions.

```
shell.qml       entry point: bar and wallpaper per screen, popups created on demand
Theme.qml       colours, font, bar height
services/       singletons
  Niri          niri IPC event stream: windows, workspaces, keyboard layout
  SysStats      cpu / mem / net / temps, read in-process from /proc and /sys
  SysInfo       hardware and software facts for the System tab
  Idle          dim, lock, screens off and sleep on inactivity; lock before suspend
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
