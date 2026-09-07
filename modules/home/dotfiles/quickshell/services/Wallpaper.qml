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
    onCurrentChanged: {}
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
