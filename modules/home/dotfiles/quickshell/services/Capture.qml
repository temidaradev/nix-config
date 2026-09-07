pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screenshots, screen recording (wf-recorder) and a colour picker.
Singleton {
    id: root
    readonly property string shotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string recDir: Quickshell.env("HOME") + "/Videos/Recordings"
    property var recent: []                   // last screenshots, newest first
    property bool recording: rec.running
    property int recSeconds: 0
    property var colors: []                   // picked hex colours, newest first

    function shotArea() { Quickshell.execDetached(["niri-screenshot"]) }
    function shotWindow() { Quickshell.execDetached(["niri", "msg", "action", "screenshot-window"]) }
    function shotScreen() { Quickshell.execDetached(["niri", "msg", "action", "screenshot-screen"]) }

    Process {
        id: rec
        command: ["sh", "-c", "mkdir -p '" + root.recDir + "'; g=$(slurp) || exit 0; exec wf-recorder -g \"$g\" -f '" + root.recDir + "/'$(date +%Y-%m-%d_%H-%M-%S).mp4"]
        onRunningChanged: if (!running) { root.recSeconds = 0; Quickshell.execDetached(["notify-send", "-a", "Recorder", "Recording saved", root.recDir]) }
    }
    Timer { interval: 1000; repeat: true; running: rec.running; onTriggered: root.recSeconds++ }
    function toggleRecord() { if (rec.running) rec.signal(2); else rec.running = true }

    Process {
        id: pick
        command: ["sh", "-c", "grim -g \"$(slurp -p)\" -t ppm - | magick - -format '%[hex:p{0,0}]' info:"]
        stdout: StdioCollector { onStreamFinished: { const h = text.trim().slice(0, 6); if (/^[0-9A-Fa-f]{6}$/.test(h)) { root.colors = ["#" + h.toLowerCase()].concat(root.colors).slice(0, 8); Quickshell.execDetached(["sh", "-c", "printf '#" + h.toLowerCase() + "' | wl-copy"]) } } }
    }
    function pickColor() { pick.running = true }
    function copyColor(c) { Quickshell.execDetached(["sh", "-c", "printf '%s' '" + c + "' | wl-copy"]) }

    Process {
        id: ls
        command: ["sh", "-c", "ls -t '" + root.shotDir + "' 2>/dev/null | head -6"]
        stdout: StdioCollector { onStreamFinished: root.recent = text.trim().split("\n").filter(l => l !== "").map(f => root.shotDir + "/" + f) }
    }
    function refresh() { ls.running = true }
}
