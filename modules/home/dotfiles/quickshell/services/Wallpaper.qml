pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Current wallpaper path, persisted outside the (read-only) nix config.
Singleton {
    id: root
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string stateFile: stateDir + "/wallpaper"
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string current: Theme.wallpaper
    property string accent: ""          // dominant hue of the wallpaper, boosted (Settings: appearance.accentFromWallpaper)
    property string blurred: ""
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/blur"
    readonly property bool wantAccent: Settings.s.appearance.accentFromWallpaper
    onWantAccentChanged: if (wantAccent) pickAccent.running = true
    onCurrentChanged: { if (wantAccent) pickAccent.running = true; blur.running = true }

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
        id: state
        path: root.stateFile
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const t = text().trim(); if (t !== "") root.current = t }
        onLoadFailed: root.current = Theme.wallpaper
    }

    Process {
        id: scan
        command: ["sh", "-c", 'mkdir -p "$1"; find "$1" -maxdepth 1 -type f -size +0 \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) | sort', "sh", root.dir]
        stdout: StdioCollector { onStreamFinished: root.available = [Theme.wallpaper].concat(text.trim().split("\n").filter(l => l !== "")) }
    }
    function rescan() { scan.running = true }
    Component.onCompleted: rescan()

    function set(path) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/wallpaper"', "sh", stateDir, path])
        current = path
    }
}
