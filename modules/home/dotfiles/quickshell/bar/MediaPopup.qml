import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs
import qs.services

// MPRIS dropdown under the bar's now-playing widget.
PanelWindow {
    id: win
    visible: Launcher.mediaOpen && Media.player !== null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-media"

    readonly property MprisPlayer p: Media.player
    readonly property real length: p && p.length > 0 ? p.length : 0
    readonly property real pos: p ? Math.min(p.position, length || p.position) : 0

    MouseArea { anchors.fill: parent; onClicked: Launcher.mediaOpen = false }

    component Glyph: Text {
        property bool dim: false
        property bool active: false
        signal clicked
        color: active ? Theme.accent : (dim ? "#88ffffff" : Theme.fg)
        font.family: Theme.font; font.pointSize: 15
        anchors.verticalCenter: parent.verticalCenter
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        width: 28
        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component SeekBar: Slider {
        id: s
        width: parent.width; height: 16
        background: Rectangle {
            x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - 2
            width: s.availableWidth; height: 4; radius: 2; color: Theme.bg3
            Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
        }
        handle: Rectangle {
            x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
            y: s.topPadding + s.availableHeight / 2 - height / 2
            width: 12; height: 12; radius: 6; color: Theme.fg
            visible: s.enabled
        }
    }

    Rectangle {
        id: panel
        width: 360
        height: body.implicitHeight + 24
        y: Theme.barHeight + 4
        x: Math.max(4, Math.min(win.width - width - 4, Launcher.mediaAnchorX - width / 2))
        radius: 6
        color: Theme.panelBg
        border.color: Theme.cardBorder; border.width: 1
        MouseArea { anchors.fill: parent }

        Column {
            id: body
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            Row {   // player tabs, only when several players exist
                visible: Media.players.length > 1
                spacing: 4
                Repeater {
                    model: Media.players
                    BarButton {
                        required property MprisPlayer modelData
                        padding: 8; implicitHeight: 24
                        color: modelData === win.p ? Theme.accent : (hovered ? "#2affffff" : Theme.bg2)
                        BarText { text: modelData.identity; font.pointSize: Theme.smallSize - 1; color: modelData === win.p ? "#1b1e20" : Theme.fg }
                        onClicked: Media.select(modelData)
                    }
                }
            }

            Row {   // art + text
                width: parent.width; spacing: 12
                Rectangle {
                    width: 96; height: 96; radius: 4; color: Theme.bg3; clip: true
                    Image {
                        anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true
                        smooth: true; mipmap: true; sourceSize: Qt.size(width * 2, height * 2)
                    }
                    Text { visible: Media.artUrl === ""; anchors.centerIn: parent; text: "󰝚"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: 30 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 108
                    spacing: 2
                    Text { width: parent.width; elide: Text.ElideRight; text: Media.title || "Nothing playing"; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize }
                    Text { width: parent.width; elide: Text.ElideRight; text: Media.artist; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize }
                    Text { width: parent.width; elide: Text.ElideRight; visible: text !== ""; text: Media.album; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                    Text { width: parent.width; elide: Text.ElideRight; text: win.p ? win.p.identity : ""; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; topPadding: 4 }
                }
            }

            Column {   // seek
                width: parent.width; spacing: 0
                SeekBar {
                    id: seek
                    from: 0; to: Math.max(1, win.length)
                    Component.onCompleted: value = win.pos
                    Connections { target: win; function onPosChanged() { if (!seek.pressed) seek.value = win.pos } }
                    enabled: (win.p?.canSeek ?? false) && win.length > 0
                    onMoved: if (win.p) win.p.position = value
                }
                Item {
                    width: parent.width; height: 14
                    Text { anchors.left: parent.left; text: Media.fmtTime(win.pos); color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                    Text { anchors.right: parent.right; text: win.length > 0 ? Media.fmtTime(win.length) : "--:--"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                }
            }

            Row {   // controls
                anchors.horizontalCenter: parent.horizontalCenter
                height: 36
                spacing: 22
                Glyph {
                    text: "󰒝"; dim: !(win.p?.shuffleSupported ?? false); active: win.p?.shuffle ?? false
                    onClicked: if (win.p) win.p.shuffle = !win.p.shuffle
                }
                Glyph { text: "󰒮"; dim: !(win.p?.canGoPrevious ?? true); onClicked: if (win.p) win.p.previous() }
                Glyph { text: Media.playing ? "󰏤" : "󰐊"; font.pointSize: 22; onClicked: if (win.p) win.p.togglePlaying() }
                Glyph { text: "󰒭"; dim: !(win.p?.canGoNext ?? true); onClicked: if (win.p) win.p.next() }
                Glyph {
                    text: win.p?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                    dim: !(win.p?.loopSupported ?? false)
                    active: win.p ? win.p.loopState !== MprisLoopState.None : false
                    onClicked: {
                        if (!win.p) return
                        const s = win.p.loopState
                        win.p.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                                        : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                    }
                }
            }

            Row {   // player volume (MPRIS), when the player exposes it
                visible: win.p?.volumeSupported ?? false
                width: parent.width; spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: "󰕾"; color: Theme.fg; font.family: Theme.font; font.pointSize: 12 }
                SeekBar {
                    id: pvol
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0; to: 1
                    Component.onCompleted: value = win.p?.volume ?? 0
                    Connections { target: win.p; function onVolumeChanged() { if (!pvol.pressed) pvol.value = win.p.volume } }
                    Connections { target: win; function onPChanged() { if (win.p) pvol.value = win.p.volume } }
                    onMoved: if (win.p) win.p.volume = value
                }
                Text { anchors.verticalCenter: parent.verticalCenter; width: 34; horizontalAlignment: Text.AlignRight; text: Math.round((win.p?.volume ?? 0) * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
            }
        }
    }
}
