pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Current wallpaper path, persisted outside the (read-only) nix config.
// Each theme remembers its own: ~/.local/state/quickshell/wallpaper and
// .../wallpaper-steinsgate. The Steins;Gate list is the art pinned in
// themes/steinsgate/wallpapers.nix (linked into the shell dir) plus
// ~/Pictures/Wallpapers/steinsgate, and "scene" (the drawn divergence meter).
Singleton {
    id: root
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string stateFile: stateDir + (Theme.steins ? "/wallpaper-steinsgate" : "/wallpaper")
    readonly property string dir: Theme.steins ? sgUserDir : normalDir
    readonly property string normalDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string sgUserDir: normalDir + "/steinsgate"
    readonly property string sgDir: Quickshell.shellDir + "/steinsgate-walls"
    readonly property string sgDefault: sgDir + "/kurisu-gears.png"
    readonly property string scene: "scene"

    property string normalCurrent: Theme.wallpaper
    property string steinsCurrent: sgDefault
    readonly property string current: Theme.steins ? steinsCurrent : normalCurrent
    readonly property bool isScene: current === scene

    property string accent: ""          // dominant hue of the wallpaper, boosted (Settings: appearance.accentFromWallpaper)
    property string blurred: ""
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/blur"
    readonly property bool wantAccent: Settings.s.appearance.accentFromWallpaper
    onWantAccentChanged: if (wantAccent && !isScene) pickAccent.running = true
    onCurrentChanged: {
        if (isScene) { blurred = ""; return }
        if (wantAccent) pickAccent.running = true
        blur.running = true
    }

    Process {
        id: blur
        command: ["sh", "-c", 'mkdir -p "$2"; f="$2/$(printf %s "$1" | md5sum | cut -c1-16).jpg"; if [ ! -s "$f" ] || [ "$1" -nt "$f" ]; then magick "$1" -resize "1600x1600>" -blur 0x18 -modulate 75,80 -quality 88 "jpg:$f.tmp" && mv "$f.tmp" "$f"; fi; [ -s "$f" ] && echo "$f"', "sh", root.current, root.cacheDir]
        stdout: StdioCollector { onStreamFinished: root.blurred = text.trim() }
    }

    Process {
        id: pickAccent
        command: ["sh", "-c", "magick \"$1\" -resize 64x64! -modulate 100,160 -colors 6 -depth 8 -format '%c' histogram:info: | sort -rn | head -1 | grep -o '#[0-9A-Fa-f]\\{6\\}' | head -1", "sh", root.current]
        stdout: StdioCollector {
            onStreamFinished: {
                const h = text.trim()
                if (!/^#[0-9a-fA-F]{6}$/.test(h)) return
                const c = Qt.color(h)
                root.accent = Qt.hsla(c.hslHue, Math.max(0.55, c.hslSaturation), 0.58, 1).toString()
            }
        }
    }
    property var available: []

    FileView {
        path: root.stateDir + "/wallpaper"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const t = text().trim(); if (t !== "") root.normalCurrent = t }
        onLoadFailed: root.normalCurrent = Theme.wallpaper
    }
    FileView {
        path: root.stateDir + "/wallpaper-steinsgate"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const t = text().trim(); if (t !== "") root.steinsCurrent = t }
        onLoadFailed: root.steinsCurrent = root.sgDefault
    }

    Process {
        id: scan
        // -L: the pinned Steins;Gate art is a directory of store symlinks
        command: ["sh", "-c", 'for d in "$@"; do mkdir -p "$d" 2>/dev/null; find -L "$d" -maxdepth 1 -type f -size +0 \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) | sort; done', "sh"].concat(Theme.steins ? [root.sgDir, root.sgUserDir] : [root.normalDir])
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim().split("\n").filter(l => l !== "")
                root.available = Theme.steins ? [root.scene].concat(found) : [Theme.wallpaper].concat(found)
            }
        }
    }
    function rescan() { scan.running = true }
    Component.onCompleted: rescan()
    Connections { target: Theme; function onSteinsChanged() { root.rescan() } }

    function set(path) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "sh", stateFile, path])
        if (Theme.steins) steinsCurrent = path; else normalCurrent = path
    }
}
