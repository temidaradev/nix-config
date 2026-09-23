import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services

// Quick toggles and session actions; details live in the bar popups and sidebar tabs.
BarPopup {
    id: win
    visible: Launcher.controlOpen
    panelWidth: 400
    onDismissed: Launcher.hideControl()

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: adapter ? Bluetooth.devices.values.filter(d => d.connected) : []

    readonly property var connections: Network.devices
        .filter(d => d.state === "connected" && d.connection && d.type !== "bridge" && d.type !== "loopback"
            && !d.name.startsWith("docker") && !d.name.startsWith("br-") && !d.name.startsWith("vmnet") && !d.name.startsWith("veth"))
        .map(d => ({ name: d.connection, type: d.type, device: d.name }))

    function runAndClose(cmd) { Quickshell.execDetached(cmd); Launcher.hideControl() }

    component Toggle: Rectangle {
        property string glyph
        property string label
        property string sub: ""
        property bool on: false
        property bool expandable: false
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
                text: "󰅂"; color: on ? "#1b1e20" : Theme.fgDim; font.family: Theme.font; font.pointSize: 12
                MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: parent.parent.parent.expand() }
            }
        }
        MouseArea { anchors.fill: parent; anchors.rightMargin: expandable ? 34 : 0; onClicked: parent.clicked() }
    }

    Flow {
        width: parent.width; spacing: 8
        Toggle {
            glyph: "󰂯"; label: "Bluetooth"; expandable: win.adapter !== null
            on: win.adapter?.enabled ?? false
            sub: !win.adapter ? "No adapter" : (win.btConnected.length > 0 ? win.btConnected.map(d => d.name).join(", ") : (on ? "On" : "Off"))
            onClicked: if (win.adapter) win.adapter.enabled = !win.adapter.enabled
            onExpand: Launcher.openSidebar("bluetooth")
        }
        Toggle {
            glyph: Notifs.dnd ? "󰂛" : "󰂚"; label: "Do not disturb"
            on: Notifs.dnd; sub: on ? "Popups hidden" : "Popups shown"
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        Toggle {
            glyph: win.connections.some(c => c.type === "wifi") ? "󰤨" : "󰈀"; label: "Network"; expandable: true
            on: win.connections.length > 0
            sub: win.connections.length > 0 ? win.connections.map(c => c.name).join(", ") : "Disconnected"
            onClicked: Launcher.openSidebar("network")
            onExpand: Launcher.openSidebar("network")
        }
        Toggle {
            glyph: Idle.inhibit ? "󰅶" : "󰾪"; label: "Stay awake"
            on: Idle.inhibit; sub: on ? "No dim, lock or sleep" : "Lock after " + Idle.fmt(Idle.cur.lock)
            onClicked: Idle.inhibit = !Idle.inhibit
        }
        Toggle {
            glyph: "󰸉"; label: "Wallpaper"; sub: "Pick an image"
            onClicked: Launcher.toggleWallpaper()
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
