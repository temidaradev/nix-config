import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services

// Centre dropdown: calendar | media, with a resources strip below.
BarPopup {
    id: dash
    visible: Launcher.dashOpen
    panelWidth: 760
    anchorX: Launcher.dashAnchorX
    onDismissed: Launcher.dashOpen = false
    onVisibleChanged: if (visible) calendar.reset()

    readonly property MprisPlayer p: Media.player
    readonly property real length: p && p.length > 0 ? p.length : 0
    readonly property real pos: p ? Math.min(p.position, length || p.position) : 0

    component Glyph: Text {
        property bool dim: false
        property bool active: false
        signal clicked
        color: active ? Theme.accent : (dim ? "#88ffffff" : Theme.fg)
        font.family: Theme.font; font.pointSize: 15
        anchors.verticalCenter: parent.verticalCenter
        verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
        width: 28
        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component Card: Rectangle {
        radius: Theme.radius; color: Theme.bg2
        default property alias content: inner.data
        property alias spacing: inner.spacing
        implicitHeight: inner.implicitHeight + 20
        Column { id: inner; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; spacing: 6 }
    }
    component Stat: Column {
        property string k; property string v; property string glyph
        width: 110; spacing: 2
        Row { spacing: 6
            Text { text: glyph; color: Theme.accent; font.family: Theme.font; font.pointSize: 12 }
            Text { text: v; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize } }
        Text { text: k; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
    }

    Row {
        width: parent.width; spacing: 12

        Card {   // calendar
            id: calCard
            width: (parent.width - 12) / 2
            Text {
                width: parent.width
                text: Qt.formatDate(new Date(), "dddd, d MMMM")
                color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize
            }
            CalendarView { id: calendar; width: parent.width }
        }

        Card {   // media, same height as the calendar
            width: (parent.width - 12) / 2
            height: calCard.implicitHeight
            spacing: 12
            Row {
                width: parent.width; spacing: 14
                Rectangle {
                    width: 168; height: 168; radius: 6; color: Theme.bg3; clip: true
                    Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true; sourceSize: Qt.size(336, 336) }
                    Text { visible: Media.artUrl === ""; anchors.centerIn: parent; text: "󰝚"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: 34 }
                }
                Column {
                    width: parent.width - 182; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                    Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: Media.title || "Nothing playing"; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize + 2 }
                    Text { width: parent.width; elide: Text.ElideRight; text: Media.artist; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize }
                    Text { width: parent.width; elide: Text.ElideRight; visible: text !== ""; text: Media.album; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                    Row {   // player tabs
                        visible: Media.players.length > 1
                        spacing: 4; topPadding: 4
                        Repeater {
                            model: Media.players
                            BarButton {
                                required property MprisPlayer modelData
                                padding: 6; implicitHeight: 20
                                color: modelData === dash.p ? Theme.accent : (hovered ? "#2affffff" : Theme.bg3)
                                BarText { text: modelData.identity; font.pointSize: Theme.smallSize - 2; color: modelData === dash.p ? "#1b1e20" : Theme.fg }
                                onClicked: Media.select(modelData)
                            }
                        }
                    }
                    Text { visible: Media.players.length <= 1; width: parent.width; elide: Text.ElideRight; text: dash.p ? dash.p.identity : ""; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; topPadding: 4 }
                }
            }

            Column {   // seek
                width: parent.width; spacing: 0
                Slider {
                    id: seek
                    width: parent.width; height: 16
                    from: 0; to: Math.max(1, dash.length)
                    enabled: (dash.p?.canSeek ?? false) && dash.length > 0
                    Component.onCompleted: value = dash.pos
                    Connections { target: dash; function onPosChanged() { if (!seek.pressed) seek.value = dash.pos } }
                    onMoved: if (dash.p) dash.p.position = value
                    background: Rectangle {
                        x: seek.leftPadding; y: seek.topPadding + seek.availableHeight / 2 - 2
                        width: seek.availableWidth; height: 4; radius: 2; color: Theme.bg3
                        Rectangle { width: seek.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
                    }
                    handle: Rectangle {
                        x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                        y: seek.topPadding + seek.availableHeight / 2 - height / 2
                        width: 12; height: 12; radius: 6; color: Theme.fg; visible: seek.enabled
                    }
                }
                Item {
                    width: parent.width; height: 14
                    Text { anchors.left: parent.left; text: Media.fmtTime(dash.pos); color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                    Text { anchors.right: parent.right; text: dash.length > 0 ? Media.fmtTime(dash.length) : "--:--"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                }
            }

            Row {   // controls
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40; spacing: 26
                Glyph { text: "󰒝"; dim: !(dash.p?.shuffleSupported ?? false); active: dash.p?.shuffle ?? false; onClicked: if (dash.p) dash.p.shuffle = !dash.p.shuffle }
                Glyph { text: "󰒮"; dim: !(dash.p?.canGoPrevious ?? true); onClicked: if (dash.p) dash.p.previous() }
                Glyph { text: Media.playing ? "󰏤" : "󰐊"; font.pointSize: 22; onClicked: if (dash.p) dash.p.togglePlaying() }
                Glyph { text: "󰒭"; dim: !(dash.p?.canGoNext ?? true); onClicked: if (dash.p) dash.p.next() }
                Glyph {
                    text: dash.p?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                    dim: !(dash.p?.loopSupported ?? false)
                    active: dash.p ? dash.p.loopState !== MprisLoopState.None : false
                    onClicked: {
                        if (!dash.p) return
                        const s = dash.p.loopState
                        dash.p.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                    }
                }
            }
        }
    }

    Row {   // resources: five tiles
        id: tiles
        width: parent.width; spacing: 8
        readonly property real tileW: (width - 8 * 4) / 5
        readonly property var rootDisk: SysStats.disks.find(d => d.mount === "/")
        readonly property real memPct: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal * 100 : 0

        component Tile: Rectangle {
            property string glyph
            property string label
            property string value
            property string sub: ""
            property color accent: Theme.accent
            default property alias extra: slot.data
            width: tiles.tileW; height: 96
            radius: Theme.radius; color: Theme.bg2
            Column {
                anchors.fill: parent; anchors.margins: 10; spacing: 2
                Row { spacing: 6
                    Text { text: glyph; color: accent; font.family: Theme.font; font.pointSize: 11 }
                    Text { text: label; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; anchors.verticalCenter: parent.verticalCenter } }
                Text { text: value; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize + 3 }
                Text { visible: sub !== ""; text: sub; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; elide: Text.ElideRight; width: parent.width }
                Item { id: slot; width: parent.width; height: 18 }
            }
        }
        component Bar: Rectangle {
            property real pct: 0
            property color accent: Theme.accent
            anchors.bottom: parent.bottom
            width: parent.width; height: 5; radius: 3; color: Theme.bg3
            Rectangle { width: parent.width * Math.min(1, pct / 100); height: parent.height; radius: 3; color: accent
                Behavior on width { NumberAnimation { duration: 400 } } }
        }

        Tile { glyph: "󰻠"; label: "CPU"; value: Math.round(SysStats.cpu) + "%"; sub: Math.round(SysStats.temp) + " °C  ·  " + SysStats.cores + " cores"
            Sparkline { anchors.bottom: parent.bottom; width: parent.width; height: 18; data: SysStats.cpuHist } }
        Tile { glyph: "󰍛"; label: "Memory"; accent: Theme.green; value: SysStats.fmtBytes(SysStats.memUsed, 1); sub: "of " + SysStats.fmtBytes(SysStats.memTotal, 0) + "  ·  " + Math.round(tiles.memPct) + "%"
            Sparkline { anchors.bottom: parent.bottom; width: parent.width; height: 18; data: SysStats.memHist; color: Theme.green } }
        Tile { glyph: "󰢮"; label: "GPU"; accent: Theme.yellow; value: SysStats.gpuTemp > 0 ? Math.round(SysStats.gpuTemp) + " °C" : "n/a"; sub: SysStats.gpuTotal > 0 ? SysStats.fmtBytes(SysStats.gpuTotal, 0) + " VRAM" : "Arc B580"
            Bar { pct: SysStats.gpuTemp; accent: Theme.yellow } }
        Tile { glyph: "󰋊"; label: "Disk  /"; value: (tiles.rootDisk ? tiles.rootDisk.pct : 0) + "%"; sub: tiles.rootDisk ? SysStats.fmtBytes(tiles.rootDisk.used, 0) + " of " + SysStats.fmtBytes(tiles.rootDisk.size, 0) : ""
            Bar { pct: tiles.rootDisk ? tiles.rootDisk.pct : 0 } }
        Tile { glyph: "󰛳"; label: "Network"; value: "󰁅 " + SysStats.fmtRate(SysStats.rx); sub: "󰁝 " + SysStats.fmtRate(SysStats.tx)
            Text { anchors.bottom: parent.bottom; anchors.right: parent.right; text: "up " + SysStats.uptime; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 } }
    }
}
