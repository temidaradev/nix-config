import QtQuick
import Quickshell
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "layout"
    anchorX: Launcher.menuAnchorX
    panelWidth: 260
    onDismissed: Launcher.menu = ""

    PopupTitle { glyph: "󰌌"; text: "Keyboard layout"; sub: Niri.layoutNames[Niri.layoutIdx] || "" }
    Column {
        width: parent.width; spacing: 1
        Repeater {
            model: Niri.layoutNames
            PopupRow {
                required property string modelData
                required property int index
                glyph: index === Niri.layoutIdx ? "󰄬" : ""
                label: modelData
                detail: Niri.shortLayout(modelData).toUpperCase()
                active: index === Niri.layoutIdx
                onClicked: { Niri.action("switch-layout", String(index)); Launcher.menu = "" }
            }
        }
    }
    Text {
        width: parent.width; wrapMode: Text.Wrap; topPadding: 2
        text: "Right-click or scroll the indicator to cycle layouts."
        color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 2
    }
}
