import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs
import qs.services

// Quick-settings panel: sound, toggles with device lists, media, notifications, session.
BarPopup {
    id: win
    visible: Launcher.controlOpen
    panelWidth: 400
    onDismissed: Launcher.hideControl()

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [win.sink, win.source] }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevices: adapter ? Bluetooth.devices.values.filter(d => d.paired || d.connected) : []
    readonly property var btConnected: btDevices.filter(d => d.connected)

    property var connections: []      // active nm connections
    property var wifi: []             // scanned networks
    property bool hasWifi: false
    property string expanded: ""      // "bt" | "net" | ""

    Process {
        id: nm
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: win.connections = text.trim().split("\n").filter(l => l !== "").map(l => {
                const [name, type, device] = l.split(":")
                return { name, type: (type || "").replace(/^802-11-wireless$/, "wifi").replace(/^802-3-ethernet$/, "ethernet"), device }
            })
        }
    }
    Process {
        id: wifiDev
        command: ["nmcli", "-t", "-f", "TYPE", "device"]
        stdout: StdioCollector { onStreamFinished: win.hasWifi = text.includes("wifi") }
    }
    Process {
        id: wifiScan
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                win.wifi = text.trim().split("\n").filter(l => l !== "").map(l => {
                    const [inUse, ssid, signal, sec] = l.split(":")
                    return { inUse: inUse === "*", ssid, signal: parseInt(signal) || 0, secure: (sec || "") !== "" }
                }).filter(w => w.ssid !== "" && !seen[w.ssid] && (seen[w.ssid] = true)).sort((a, b) => b.signal - a.signal)
            }
        }
    }
    Timer {
        interval: 5000; repeat: true; running: win.visible; triggeredOnStart: true
        onTriggered: { nm.running = true; wifiDev.running = true; if (win.expanded === "net" && win.hasWifi) wifiScan.running = true }
    }
    onExpandedChanged: if (expanded === "net" && hasWifi) wifiScan.running = true

    function run(cmd) { Quickshell.execDetached(cmd) }
    function runAndClose(cmd) { Quickshell.execDetached(cmd); Launcher.hideControl() }

    component Section: Text {
        color: Theme.fgDim
        font.family: Theme.font; font.pointSize: Theme.smallSize - 1
        font.capitalization: Font.AllUppercase
        topPadding: 6
    }
    component Toggle: Rectangle {
        property string glyph
        property string label
        property string sub: ""
        property bool on: false
        property bool expandable: false
        property bool expandedNow: false
        signal clicked
        signal expand
        width: (parent.width - 8) / 2; height: 54
        radius: Theme.radius
        color: on ? Theme.accent : Theme.bg2
        Row {
            anchors.fill: parent; anchors.margins: 10; spacing: 10
            Text { text: glyph; anchors.verticalCenter: parent.verticalCenter; color: on ? "#1b1e20" : Theme.fg; font.family: Theme.font; font.pointSize: 15 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 34 - (expandable ? 20 : 0)
                Text { width: parent.width; elide: Text.ElideRight; text: label; color: on ? "#1b1e20" : Theme.fg; font.family: Theme.font; font.pointSize: Theme.fontSize; font.bold: true }
                Text { width: parent.width; elide: Text.ElideRight; visible: sub !== ""; text: sub; color: on ? "#1b1e20" : Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
            }
            Text {
                visible: expandable
                anchors.verticalCenter: parent.verticalCenter
                text: expandedNow ? "󰅃" : "󰅀"; color: on ? "#1b1e20" : Theme.fgDim; font.family: Theme.font; font.pointSize: 12
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: parent.parent.parent.expand() }
            }
        }
        MouseArea { anchors.fill: parent; anchors.rightMargin: expandable ? 34 : 0; onClicked: parent.clicked() }
    }
    component VolSlider: Slider {
        id: s
        property string glyph
        property bool mutedState: false
        property var node
        signal toggleMute
        width: parent.width; height: 26
        from: 0; to: 1
        leftPadding: 34; rightPadding: 44
        Component.onCompleted: value = node?.audio?.volume ?? 0
        Connections { target: s.node?.audio ?? null; function onVolumeChanged() { if (!s.pressed) s.value = s.node.audio.volume } }
        onMoved: if (node?.audio) node.audio.volume = value
        Text {
            x: 4; anchors.verticalCenter: parent.verticalCenter
            text: s.glyph; color: s.mutedState ? Theme.fgDim : Theme.fg
            font.family: Theme.font; font.pointSize: 13
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: s.toggleMute() }
        }
        Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: Math.round(s.value * 100) + "%"; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize
        }
        background: Rectangle {
            x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - 2
            width: s.availableWidth; height: 4; radius: 2; color: Theme.bg3
            Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: s.mutedState ? Theme.fgDim : Theme.accent }
        }
        handle: Rectangle {
            x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
            y: s.topPadding + s.availableHeight / 2 - height / 2
            width: 14; height: 14; radius: 7; color: Theme.fg
        }
    }
    component ListRow: Rectangle {
        property string glyph
        property string label
        property string sub: ""
        property bool active: false
        signal clicked
        width: parent.width; height: 32
        radius: Theme.radius
        color: ma.containsMouse ? "#2affffff" : "transparent"
        Row {
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; width: 18; text: glyph; color: active ? Theme.accent : Theme.fg; font.family: Theme.font; font.pointSize: 12 }
            Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 26 - 90; elide: Text.ElideRight; text: label; color: active ? Theme.accent : Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize }
            Text { anchors.verticalCenter: parent.verticalCenter; width: 90; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: sub; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }

    Section { text: "Battery"; visible: Battery.present }
    Row {
        visible: Battery.present
        width: parent.width; spacing: 8
        Text { text: Battery.glyph; color: Battery.low ? Theme.red : (Battery.charging ? Theme.green : Theme.fg); font.family: Theme.font; font.pointSize: 14; anchors.verticalCenter: parent.verticalCenter }
        Text { text: Battery.pct + "%"; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize; anchors.verticalCenter: parent.verticalCenter }
        Text { text: Battery.timeText; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
    }

    Section { text: "Display"; visible: Brightness.present }
    VolSlider {
        visible: Brightness.present
        glyph: "󰃠"; node: null
        Component.onCompleted: value = Brightness.level
        Connections { target: Brightness; function onLevelChanged() { if (!pressed) value = Brightness.level } }
        onMoved: Brightness.set(value)
    }

    Section { text: "Sound" }
    VolSlider {
        glyph: mutedState ? "󰖁" : "󰕾"; node: win.sink
        mutedState: win.sink?.audio?.muted ?? false
        onToggleMute: if (win.sink?.audio) win.sink.audio.muted = !win.sink.audio.muted
    }
    VolSlider {
        glyph: mutedState ? "󰍭" : "󰍬"; node: win.source
        mutedState: win.source?.audio?.muted ?? false
        onToggleMute: if (win.source?.audio) win.source.audio.muted = !win.source.audio.muted
    }

    Section { text: "Toggles" }
    Flow {
        width: parent.width; spacing: 8
        Toggle {
            glyph: "󰂯"; label: "Bluetooth"; expandable: win.adapter !== null; expandedNow: win.expanded === "bt"
            on: win.adapter?.enabled ?? false
            sub: !win.adapter ? "No adapter" : (win.btConnected.length > 0 ? win.btConnected.map(d => d.name).join(", ") : (on ? "On" : "Off"))
            onClicked: if (win.adapter) win.adapter.enabled = !win.adapter.enabled
            onExpand: win.expanded = win.expanded === "bt" ? "" : "bt"
        }
        Toggle {
            glyph: Notifs.dnd ? "󰂛" : "󰂚"; label: "Do not disturb"
            on: Notifs.dnd; sub: on ? "Popups hidden" : "Popups shown"
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        Toggle {
            glyph: win.connections.some(c => c.type === "wifi") ? "󰤨" : "󰈀"; label: "Network"; expandable: true; expandedNow: win.expanded === "net"
            on: win.connections.length > 0
            sub: win.connections.length > 0 ? win.connections.map(c => c.name).join(", ") : "Disconnected"
            onClicked: win.expanded = win.expanded === "net" ? "" : "net"
            onExpand: win.expanded = win.expanded === "net" ? "" : "net"
        }
        Toggle {
            glyph: "󰸉"; label: "Wallpaper"; sub: "Pick an image"
            onClicked: Launcher.toggleWallpaper()
        }
    }

    Column {   // bluetooth devices
        visible: win.expanded === "bt"
        width: parent.width; spacing: 2
        Repeater {
            model: win.btDevices
            ListRow {
                required property var modelData
                glyph: modelData.connected ? "󰂱" : "󰂲"
                label: modelData.name
                active: modelData.connected
                sub: modelData.connected ? (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%  connected" : "connected") : "paired"
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
            }
        }
        ListRow { glyph: "󰂰"; label: "Pair a new device…"; sub: "blueman"; onClicked: win.runAndClose(["blueman-manager"]) }
    }

    Column {   // networks
        visible: win.expanded === "net"
        width: parent.width; spacing: 2
        Repeater {
            model: win.connections
            ListRow {
                required property var modelData
                glyph: modelData.type === "wifi" ? "󰤨" : modelData.type === "ethernet" ? "󰈀" : modelData.type.startsWith("wireguard") || modelData.type === "vpn" || modelData.type === "tun" ? "󰖂" : "󰛳"
                label: modelData.name; sub: modelData.device; active: true
                onClicked: win.run(["nmcli", "connection", "down", modelData.name])
            }
        }
        Repeater {
            model: win.wifi.filter(w => !w.inUse).slice(0, 8)
            ListRow {
                required property var modelData
                glyph: modelData.signal > 66 ? "󰤨" : modelData.signal > 33 ? "󰤥" : "󰤟"
                label: modelData.ssid; sub: (modelData.secure ? "󰌾 " : "") + modelData.signal + "%"
                onClicked: win.run(["sh", "-c", "nmcli device wifi connect '" + modelData.ssid.replace(/'/g, "'\\''") + "' || nm-connection-editor"])
            }
        }
        ListRow { glyph: "󰒓"; label: "Edit connections…"; sub: "nm-connection-editor"; onClicked: win.runAndClose(["nm-connection-editor"]) }
    }

    Section { text: "Now playing"; visible: Media.player !== null }
    Rectangle {
        visible: Media.player !== null
        width: parent.width; height: 56; radius: Theme.radius; color: Theme.bg2
        Row {
            anchors.fill: parent; anchors.margins: 8; spacing: 10
            Rectangle {
                width: 40; height: 40; radius: 3; color: Theme.bg3; clip: true
                Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true; sourceSize: Qt.size(80, 80) }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - 10 - 110
                Text { width: parent.width; elide: Text.ElideRight; text: Media.title; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize }
                Text { width: parent.width; elide: Text.ElideRight; text: Media.artist; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                BarButton { padding: 6; onClicked: Media.player?.previous()
                    BarText { text: "󰒮"; font.pointSize: 13 } }
                BarButton { padding: 6; onClicked: Media.player?.togglePlaying()
                    BarText { text: Media.playing ? "󰏤" : "󰐊"; font.pointSize: 13 } }
                BarButton { padding: 6; onClicked: Media.player?.next()
                    BarText { text: "󰒭"; font.pointSize: 13 } }
            }
        }
    }

    Row {
        width: parent.width
        Section { text: "Notifications" + (Notifs.count > 0 ? "  " + Notifs.count : ""); width: parent.width - 60 }
        BarButton {
            visible: Notifs.count > 0
            width: 60; implicitHeight: 22; padding: 4
            BarText { text: "Clear"; color: Theme.fgDim; font.pointSize: Theme.smallSize - 1 }
            onClicked: Notifs.clearAll()
        }
    }
    Text {
        visible: Notifs.count === 0
        text: "No notifications"; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize
    }
    Flickable {
        width: parent.width
        height: Math.min(260, list.implicitHeight)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: list
            width: parent.width; spacing: 4
            Repeater {
                model: Notifs.history.slice().reverse()
                NotificationCard {
                    required property var modelData
                    n: modelData; compact: true; width: list.width
                    onClicked: Notifs.activate(n)
                    onClosed: Notifs.dismiss(n)
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: "#22ffffff" }

    Row {
        width: parent.width; height: 32; spacing: 6
        layoutDirection: Qt.RightToLeft
        component SessionButton: BarButton {
            property string glyph
            padding: 10; implicitHeight: 32
            BarText { text: glyph; font.pointSize: 13 }
        }
        SessionButton { glyph: "⏻"; onClicked: { Launcher.hideControl(); Launcher.toggleSession() } }
        SessionButton { glyph: "󰜉"; onClicked: win.runAndClose(["systemctl", "reboot"]) }
        SessionButton { glyph: "󰍃"; onClicked: win.runAndClose(["niri", "msg", "action", "quit", "--skip-confirmation"]) }
        SessionButton { glyph: "󰌾"; onClicked: { Launcher.hideControl(); Lock.lock() } }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Quickshell.env("USER") + "@" + Niri.hostname
            color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize
        }
    }
}
