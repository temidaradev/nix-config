pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Screenshots, screen recording (wf-recorder) and a colour picker.
Singleton {
    id: root
    readonly property string shotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string recDir: Quickshell.env("HOME") + "/Videos/Recordings"
    property var recent: []                   // last screenshots, newest first
    property bool recording: rec.running
    property bool selecting: sel.running       // region picker open, not recording yet
    property int recSeconds: 0
    property string recFile: ""
    property var colors: []                   // picked hex colours, newest first
    property int fps: Settings.s.capture?.fps || 30
    property int bitrate: Settings.s.capture?.bitrate || 8
    property int audioBitrate: 192
    property string encoder: Settings.s.capture?.encoder || "h264_vaapi"
    property string audioMode: "desktop"
    property string target: "region"
    property string output: ""
    property int countdown: 0
    property int remaining: 0
    property real recBytes: 0
    property var pending: ({})
    function options(geometry) {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss-zzz")
        root.recFile = root.recDir + "/" + stamp + (encoder === "libvpx-vp9" ? ".mkv" : ".mp4")
        return { file: recFile, fps, bitrate, audioBitrate, codec: encoder, audio: audioMode, geometry: geometry || "", output }
    }
    function prepare(geometry) {
        pending = options(geometry); remaining = countdown
        if (remaining > 0) count.start(); else startRecording()
    }
    function startRecording() {
        remaining = 0
        rec.command = ["shell-sidebar-backend", "record", JSON.stringify(pending)]
        recSeconds = 0; recBytes = 0; rec.running = true
    }
    Timer {
        id: count; interval: 1000; repeat: true
        onTriggered: { root.remaining--; if (root.remaining <= 0) { stop(); root.startRecording() } }
    }

    function shotArea() { Quickshell.execDetached(["niri-screenshot"]) }
    function shotWindow() { Quickshell.execDetached(["niri", "msg", "action", "screenshot-window"]) }
    function shotScreen() { Quickshell.execDetached(["niri", "msg", "action", "screenshot-screen"]) }

    // Region picking is its own process. Folded into the recorder as
    // `sh -c "g=$(slurp); exec wf-recorder"` the stop button was dead until slurp
    // returned: SIGINT landed on a shell blocked in a command substitution.
    Process {
        id: sel
        command: ["slurp"]
        stdout: StdioCollector {
            onStreamFinished: {
                const g = text.trim()
                if (g === "") return                  // cancelled
                root.prepare(g)
            }
        }
    }

    Process {
        id: rec
        onExited: code => {
            root.recSeconds = 0
            Workbench.refresh("capture")
            if (code === 0) Quickshell.execDetached(["notify-send", "-a", "Recorder", "Recording saved", root.recFile])
            else Quickshell.execDetached(["notify-send", "-a", "Recorder", "-u", "critical", "Recording failed", "wf-recorder exited with " + code])
        }
    }
    Process { id: fileSize; command: ["stat", "-c", "%s", root.recFile]; stdout: StdioCollector { onStreamFinished: root.recBytes = Number(text.trim()) || 0 } }
    Timer { interval: 1000; repeat: true; running: rec.running; onTriggered: root.recSeconds++ }
    Timer { interval: 5000; repeat: true; running: rec.running && Launcher.sidebarOpen && Launcher.sidebarTab === "capture"; onTriggered: if (!fileSize.running) fileSize.running = true }
    function toggleRecord() {
        if (rec.running) rec.signal(2)              // SIGINT: wf-recorder finalises the mp4
        else if (sel.running) sel.signal(15)        // a second click cancels a pending pick
        else if (count.running) { count.stop(); remaining = 0 }
        else if (target === "region") sel.running = true
        else prepare("")
    }

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
