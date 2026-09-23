import QtQuick
import Quickshell
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "devices"
    anchorX: Launcher.menuAnchorX
    panelWidth: 320
    onDismissed: Launcher.menu = ""

    PopupTitle { glyph: "󰂯"; text: "Device batteries"; sub: Devices.all.length + (Devices.all.length === 1 ? " device" : " devices") }
    Repeater {
        model: Devices.all
        Column {
            required property var modelData
            width: parent.width; spacing: 4; topPadding: 4
            Row {
                width: parent.width; spacing: 8
                Text { width: 20; text: modelData.glyph; color: modelData.pct < 20 ? Theme.red : Theme.fg; font.family: Theme.font; font.pointSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { width: parent.width - 28 - 60; elide: Text.ElideRight; text: modelData.name; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
                Text { width: 52; horizontalAlignment: Text.AlignRight; text: modelData.pct + "%" + (modelData.charging ? " 󱐋" : ""); color: modelData.pct < 20 ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
            }
            PopupMeter { pct: modelData.pct; accent: modelData.pct < 20 ? Theme.red : modelData.charging ? Theme.green : Theme.accent }
        }
    }
    Row {
        spacing: 6; topPadding: 6
        PopupButton { label: "󰂯  Bluetooth"; onClicked: { const x = Launcher.menuAnchorX; Launcher.toggleMenu("bluetooth", x) } }
        PopupButton { label: "󰁹  Power settings"; onClicked: Launcher.openSidebar("power") }
    }
}
