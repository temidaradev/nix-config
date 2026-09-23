import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "bluetooth"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var known: adapter ? Bluetooth.devices.values.filter(d => d.paired || d.connected).sort((a, b) => b.connected - a.connected) : []
    readonly property var found: adapter ? Bluetooth.devices.values.filter(d => !d.paired && !d.connected && d.name) : []
    readonly property var connected: known.filter(d => d.connected)
    property bool startedScan: false
    Component.onDestruction: if (startedScan && adapter) adapter.discovering = false

    PopupTitle {
        glyph: !pop.enabled ? "󰂲" : pop.connected.length > 0 ? "󰂱" : "󰂯"
        glyphColor: pop.enabled ? Theme.accent : Theme.fgDim
        text: "Bluetooth"
        sub: !pop.adapter ? "No adapter" : !pop.enabled ? "Off" : pop.connected.length > 0 ? pop.connected.map(d => d.name).join(", ") : "On, nothing connected"
        PopupSwitch { visible: pop.adapter !== null; on: pop.enabled; onToggled: v => pop.adapter.enabled = v }
    }
    PopupToggle {
        visible: pop.enabled
        label: "Discover nearby devices"; sub: pop.adapter?.discovering ? "Scanning…" : ""
        on: pop.adapter?.discovering ?? false
        onToggled: v => { pop.adapter.discovering = v; if (v) pop.startedScan = true }
    }

    PopupSection { text: "Devices"; visible: pop.enabled }
    Text { visible: pop.enabled && pop.known.length === 0; text: "No paired devices"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
    Column {
        visible: pop.enabled
        width: parent.width; spacing: 1
        Repeater {
            model: pop.known
            PopupRow {
                required property var modelData
                glyph: Devices.glyphFor(null, modelData.name)
                label: modelData.name
                sub: (modelData.connected ? "Connected" : modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : "Paired")
                     + (modelData.batteryAvailable ? "  ·  󰁹 " + Math.round(modelData.battery * 100) + "%" : "")
                active: modelData.connected
                action: modelData.connected ? "Disconnect" : "Connect"
                onActionClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
            }
        }
    }
    PopupSection { text: "Nearby"; visible: pop.enabled && pop.found.length > 0 }
    Column {
        visible: pop.enabled && pop.found.length > 0
        width: parent.width; spacing: 1
        Repeater {
            model: pop.found.slice(0, 8)
            PopupRow { required property var modelData; glyph: "󰂯"; label: modelData.name; sub: modelData.address; action: "Pair"; onActionClicked: modelData.pair(); onClicked: modelData.pair() }
        }
    }

    Row {
        spacing: 6; topPadding: 4
        PopupButton { label: "󰂯  Bluetooth settings"; onClicked: Launcher.openSidebar("bluetooth") }
    }
}
