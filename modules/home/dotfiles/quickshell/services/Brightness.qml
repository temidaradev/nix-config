pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen backlight via brightnessctl. `present` is false without a backlight.
Singleton {
    id: root
    property bool present: false
    property real level: 0          // 0..1
    signal osd()

    Process {
        id: read
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",")
                if (p.length >= 5) { root.present = true; root.level = parseInt(p[3]) / 100 }
                else root.present = false
            }
        }
    }
    function refresh() { read.running = true }
    Component.onCompleted: refresh()

    function set(v) {
        v = Math.max(0.01, Math.min(1, v))
        level = v
        Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", Math.round(v * 100) + "%"])
    }

    IpcHandler {
        target: "brightness"
        function osd(): void { root.refresh(); root.osd() }
        function refresh(): void { root.refresh() }
    }
}
