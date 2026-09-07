pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Current wallpaper path, persisted outside the (read-only) nix config.
Singleton {
    id: root
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string stateFile: stateDir + "/wallpaper"
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string current: Theme.wallpaper
    property string accent: ""          // dominant hue of the wallpaper, boosted (Settings: appearance.accentFromWallpaper)
    onCurrentChanged: pickAccent.running = true

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
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const t = text().trim(); if (t !== "") root.current = t }
        onLoadFailed: root.current = Theme.wallpaper
    }

    Process {
        id: scan
        command: ["sh", "-c", "mkdir -p '" + root.dir + "'; find '" + root.dir + "' -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector { onStreamFinished: root.available = [Theme.wallpaper].concat(text.trim().split("\n").filter(l => l !== "")) }
    }
    function rescan() { scan.running = true }
    Component.onCompleted: rescan()

    function set(path) {
        Quickshell.execDetached(["sh", "-c", "mkdir -p '" + stateDir + "' && printf '%s' '" + path + "' > '" + stateFile + "'"])
        current = path
    }
}
