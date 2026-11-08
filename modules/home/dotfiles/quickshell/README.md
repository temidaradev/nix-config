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

## Sidebar

Open with Mod+S. Search controls in the header, pin pages on Home, and reorder
the pins with the arrow buttons. The sidebar remembers its last page and scroll
positions. `sidebar.width` in `quickshell-settings.nix` controls its width.

- Audio: manual sample rate and buffer controls, per-application routing,
  device-reported profiles/codecs and ports, opt-in microphone meter/test,
  and EasyEffects presets. Opening the page never changes a profile or codec.
  Bluetooth policy, codecs and audio defaults use the original configuration.
  The selector only changes a profile when you explicitly choose one.
- Capture: screenshots, colour picker, region/monitor recording, frame rate,
  video/audio bitrate, software or VA-API encoding, audio sources, countdown,
  and recent recordings. ThinkPad defaults are 30 fps, 8 Mbps, H.264 VA-API.
  Encoder availability depends on hardware; errors appear in notifications/logs.
- Displays: modes, scale, rotation, position, VRR, saved layouts and night light.
  Keep a display change within 18 seconds or the watchdog restores the previous
  layout. These controls change the current session; Nix defines startup settings.
- Clipboard: search, bounded image previews, private pins, delete, and pause.
  Pause affects the new `shell-clipboard-store` watchers; after rebuilding, start
  a new niri session to replace watchers launched by the old configuration.
- Tasks: local tasks/reminders, focus timer with DND restoration, and scratchpad.
- Agenda: import a local `.ics` file with recurring events and excluded dates.
  It displays the next 30 days; it does not sync a remote calendar account.
- Network, Power and System: VPN controls, peers/DNS/traffic, explicit pings and
  Wi-Fi scans, hotspot, battery health/thresholds/watts, timed stay-awake,
  processes, failed services, logs and copyable diagnostics.
- Media and Bluetooth: player controls/sleep timer and existing device controls.

Local data lives under `$XDG_STATE_HOME/quickshell` (normally
`~/.local/state/quickshell`); notes, tasks and pins are private files. Clipboard
previews use `$XDG_CACHE_HOME/quickshell/sidebar`. No calendar credentials are
stored in Nix. Focus, stay-awake and media sleep timers are session-only.

## Battery policy

Only the selected page loads its added controls. Static pages refresh on entry
and actions. Power, Network and System snapshots refresh every 15 seconds on
battery (5 seconds on AC), and stop when closed, locked or screens are off.
Audio uses server events with a debounce instead of periodic snapshots. Wi-Fi
does not automatically rescan on battery; use its Rescan button. Reminders use
one scheduled timer, with a one-minute retry if notification delivery fails.

The live microphone meter runs only when enabled on the visible Audio page.
Recording starts only on request; GPU encoding and conservative defaults reduce
its CPU cost. System-stat sampling slows to 10 seconds on battery with details
closed, and media position polling also slows. Audio quality is not reduced to
save power. Runtime wattage/battery-life improvements have not been benchmarked.

## Validation

`scripts/test_sidebar.py` exercises the Python backend using temporary state and
mocked hardware actions. Run it with Python containing `icalendar` and
`python-dateutil`. `nix flake check path:. --no-build --no-write-lock-file` checks
configuration evaluation without activating a system. Build/apply the NixOS
configuration before using the new backend commands.
