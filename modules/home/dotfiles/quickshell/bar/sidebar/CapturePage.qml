import QtQuick
import Quickshell
import qs.services

Column {
    width: parent.width; spacing: 8
    SHeading { text: "Capture & recording" }
    SCard {
        Flow {
            width: parent.width; spacing: 6
            SAction { text: "Area screenshot"; onClicked: { Launcher.sidebarOpen = false; Capture.shotArea() } }
            SAction { text: "Window screenshot"; onClicked: { Launcher.sidebarOpen = false; Capture.shotWindow() } }
            SAction { text: "Screen screenshot"; onClicked: { Launcher.sidebarOpen = false; Capture.shotScreen() } }
            SAction { text: "Pick colour"; onClicked: { Launcher.sidebarOpen = false; Capture.pickColor() } }
        }
    }
    SCard {
        enabled: !Capture.recording && Capture.remaining === 0
        SSelect { label: "Record"; options: ["Selected region", "Monitor"]; values: ["region", "output"]; current: Capture.target; onChosen: value => Capture.target = value }
        SSelect { visible: Capture.target === "output"; label: "Monitor"; options: ["Automatic"].concat(Quickshell.screens.map(s => s.name)); values: [""].concat(Quickshell.screens.map(s => s.name)); current: Capture.output; onChosen: value => Capture.output = value }
        SSelect { label: "Frame rate"; options: ["24 fps", "30 fps", "60 fps", "120 fps"]; values: [24, 30, 60, 120]; current: Capture.fps; onChosen: value => Capture.fps = value }
        SSelect { label: "Video bitrate"; options: ["4 Mbps", "8 Mbps", "12 Mbps", "20 Mbps", "40 Mbps", "80 Mbps"]; values: [4, 8, 12, 20, 40, 80]; current: Capture.bitrate; onChosen: value => Capture.bitrate = value }
        SSelect { label: "Encoder"; options: ["H.264 · software", "H.265 · software", "VP9 · software", "H.264 · GPU (VA-API)", "H.265 · GPU (VA-API)"]; values: ["libx264", "libx265", "libvpx-vp9", "h264_vaapi", "hevc_vaapi"]; current: Capture.encoder; onChosen: value => Capture.encoder = value }
        SSelect { label: "Audio source"; options: ["No audio", "Desktop", "Microphone", "Desktop + microphone"]; values: ["none", "desktop", "microphone", "both"]; current: Capture.audioMode; onChosen: value => Capture.audioMode = value }
        SSelect { visible: Capture.audioMode !== "none"; label: "Audio bitrate · AAC"; options: ["96 kbps", "128 kbps", "192 kbps", "256 kbps", "320 kbps"]; values: [96, 128, 192, 256, 320]; current: Capture.audioBitrate; onChosen: value => Capture.audioBitrate = value }
        SSelect { label: "Countdown"; options: ["None", "3 seconds", "5 seconds", "10 seconds"]; values: [0, 3, 5, 10]; current: Capture.countdown; onChosen: value => Capture.countdown = value }
        SHint { text: "Approximate video size: " + Math.round(Capture.bitrate * 60 / 8) + " MB / minute. GPU encoding depends on your device." }
    }
    SCard {
        SLabel { text: Capture.recording ? "Recording · " + Media.fmtTime(Capture.recSeconds) + " · " + SysStats.fmtBytes(Capture.recBytes) : Capture.remaining > 0 ? "Starting in " + Capture.remaining + "…" : "Ready to record"; font.bold: true }
        SAction { text: Capture.recording ? "Stop & save" : Capture.remaining > 0 || Capture.selecting ? "Cancel" : "Start recording"; onClicked: { if (!Capture.recording && Capture.remaining === 0) Launcher.sidebarOpen = false; Capture.toggleRecord() } }
        Flow { width: parent.width; spacing: 6
            SAction { text: "Open recordings"; onClicked: Apps.spawn(["xdg-open", Capture.recDir]) }
            SAction { text: "Open screenshots"; onClicked: Apps.spawn(["xdg-open", Capture.shotDir]) }
        }
    }
    SHeading { text: "Recent recordings" }
    Repeater {
        model: Workbench.capture.recent || []
        SCard {
            required property var modelData
            SLabel { text: modelData.name }
            SHint { text: SysStats.fmtBytes(modelData.size) }
            Flow { width: parent.width; spacing: 6
                SAction { text: "Play"; onClicked: Apps.spawn(["xdg-open", modelData.path]) }
                SAction { text: "Copy path"; onClicked: Workbench.copy(modelData.path) }
            }
        }
    }
}
