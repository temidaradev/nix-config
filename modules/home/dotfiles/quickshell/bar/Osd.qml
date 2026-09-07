import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs
import qs.services

// macOS-style OSD pill: volume, microphone and keyboard layout changes.
PanelWindow {
    id: osd
    anchors { bottom: true }
    margins.bottom: Settings.s.osd.bottomMargin
    implicitWidth: 320
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    visible: shown || fade.running

    property bool shown: false
    property bool ready: false
    property string kind: "volume"          // volume | mic | layout

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [osd.sink, osd.source] }
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string layout: Niri.layout
    readonly property real brightness: Brightness.level

    readonly property real level: kind === "mic" ? micVolume : kind === "brightness" ? brightness : volume
    readonly property bool isMuted: kind === "mic" ? micMuted : kind === "brightness" ? false : muted
    readonly property string glyph: kind === "layout" ? "󰌌"
        : kind === "brightness" ? (brightness < 0.34 ? "󰃞" : brightness < 0.67 ? "󰃟" : "󰃠")
        : kind === "mic" ? (micMuted ? "󰍭" : "󰍬")
        : (muted ? "󰖁" : (volume < 0.01 ? "󰕿" : volume < 0.5 ? "󰖀" : "󰕾"))

    Timer { interval: 1500; running: true; onTriggered: osd.ready = true }
    Timer { id: hide; interval: Settings.s.osd.timeoutMs; onTriggered: osd.shown = false }

    function ping(k) {
        if (!ready) return
        kind = k; shown = true; hide.restart()
    }
    onVolumeChanged: ping("volume")
    onMutedChanged: ping("volume")
    onMicVolumeChanged: ping("mic")
    onMicMutedChanged: ping("mic")
    onLayoutChanged: ping("layout")
    Connections { target: Brightness; function onOsd() { osd.ping("brightness") } }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#f21b1e20"
        border.color: "#33ffffff"; border.width: 1
        opacity: osd.shown ? 1 : 0
        scale: osd.shown ? 1 : 0.92
        Behavior on opacity { NumberAnimation { id: fade; duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 18; anchors.rightMargin: 18
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                text: osd.glyph
                color: osd.kind !== "layout" && osd.isMuted ? Theme.fgDim : Theme.fg
                font.family: Theme.font; font.pointSize: 18
            }

            Row {   // segmented level bar
                id: segs
                visible: osd.kind !== "layout"
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                readonly property int count: 16
                readonly property int lit: Math.round(Math.min(1, osd.level) * count)
                Repeater {
                    model: segs.count
                    Rectangle {
                        required property int index
                        width: (osd.width - 36 - 28 - 14 - 14 - 44) / segs.count - 3
                        height: 8; radius: 2
                        color: (!osd.isMuted && index < segs.lit) ? Theme.fg : "#33ffffff"
                    }
                }
            }
            Text {
                visible: osd.kind === "layout"
                anchors.verticalCenter: parent.verticalCenter
                width: osd.width - 36 - 28 - 14 - 14 - 44
                text: osd.layout.toUpperCase() + "   " + (Niri.layoutNames[Niri.layoutIdx] || "")
                elide: Text.ElideRight
                color: Theme.fg; font.bold: true
                font.family: Theme.font; font.pointSize: Theme.fontSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: osd.kind === "layout" ? "" : (osd.isMuted ? "0%" : Math.round(osd.level * 100) + "%")
                color: Theme.fgDim
                font.family: Theme.font; font.pointSize: Theme.smallSize
            }
        }
    }
}
