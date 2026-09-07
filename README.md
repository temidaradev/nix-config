# nix-config

Nix config for three machines:

- `temidaradev`: NixOS desktop (x86_64-linux), Ryzen 7 5700X + Arc B580
- `thinkpad`: NixOS laptop (x86_64-linux), ThinkPad E16 Gen 3 (Core Ultra 7 255H)
- `temidaradev-darwin`: Apple Silicon Mac (aarch64-darwin), via [nix-darwin](https://github.com/nix-darwin/nix-darwin)

## Rebuild

```bash
nh darwin switch .   # macOS
nh os switch .       # NixOS (either host, picked by hostname)
```

Edit `hosts/<host>/packages.nix`, then rebuild. Mac GUI apps and brews go in `darwin/homebrew/default.nix`.

Homebrew uses `cleanup = "uninstall"`: anything not in that file gets removed on rebuild. Don't `brew install` by hand, add it to the file.

## Layout

```
hosts/<host>/         machine.nix, hardware.nix, packages.nix per machine
modules/nixos/        shared NixOS modules (desktop, hardware, services, ...)
modules/nixos/laptop  laptop-only: watt power policy, fprintd, bolt, lid handling
modules/darwin/       nix-darwin modules
modules/home/         user files, placed with hjem (no home-manager)
modules/shared/       fonts, nix settings, packages common to all hosts
```

`temidaradev.role` (`desktop` or `laptop`, set in `hosts/<host>/machine.nix`)
switches desktop-only modules (xmrig, Samba, VMware, OpenTabletDriver) and
laptop-only ones on or off.

## Desktop: niri + a custom shell

NixOS hosts boot into [niri](https://github.com/YaLTeR/niri) with a shell
written in [Quickshell](https://quickshell.org) (QML). Plasma stays installed
and selectable in SDDM. No Noctalia, Caelestia, waybar or mako: the shell is
the bar, launcher, notification daemon, OSD and desktop.

```
modules/home/dotfiles/niri/                  niri config; host-<hostname>.kdl holds the monitor block
modules/home/dotfiles/quickshell/            the shell (see its README for the file map)
modules/home/dotfiles/quickshell-settings.nix  shell settings: colours, bar widgets, pinned apps, ...
modules/nixos/desktop/window-managers/niri.nix niri, portals, helper wrappers, the shell's user service
```

Settings are declarative only. Edit `quickshell-settings.nix`, rebuild, then
`systemctl --user restart quickshell-niri`.

Keys worth knowing (Mod = Super):

| Key | Action |
| --- | --- |
| Mod+D, Alt+Space | app drawer |
| Mod+A | control center (sound, bluetooth, network, wallpaper, notifications) |
| Mod+S | sidebar (weather, quick launch, todo, windows, capture, clipboard, timer) |
| Mod+O | overview |
| Mod+T / Mod+E | terminal / file manager |
| Mod+Up / Down | previous / next workspace |
| Mod+Shift+S | area screenshot with annotation (swappy) |
| Mod+Shift+L | lock |
| Win+Space | keyboard layout (us / tr) |

Clicking the clock opens the dashboard (calendar, media, resources); the
bell opens notification history; temperatures and disk open their own
dropdowns.

## Laptop notes

`hosts/thinkpad/hardware.nix` is a placeholder until the machine exists.
After installing, replace its filesystems block with the output of
`nixos-generate-config --show-hardware-config`.

Power is managed by [watt](https://github.com/NotAShelf/watt): on wall power
everything runs at maximum performance, on battery it drops to power saving,
and charge is held between 40 and 80 %. Thresholds live in
`modules/nixos/laptop/default.nix`.
