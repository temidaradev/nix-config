import QtQuick
import qs
import qs.services

// Sensor readings under the temperature widget.
BarPopup {
    visible: Launcher.tempOpen
    panelWidth: 300
    anchorX: Launcher.tempAnchorX
    onDismissed: Launcher.tempOpen = false

    component TempRow: Column {
        property string glyph
        property string label
        property real value
        property real warn: 80
        property real max: 100
        property string extra: ""
        visible: value > 0
        width: parent.width; spacing: 4
        Row {
            width: parent.width; spacing: 8
            Text { text: glyph; width: 20; color: value > warn ? Theme.red : Theme.accent; font.family: Theme.font; font.pointSize: 12 }
            Text { text: label; width: parent.width - 28 - 120; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
            Text { text: extra; width: 60; horizontalAlignment: Text.AlignRight; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; anchors.verticalCenter: parent.verticalCenter }
            Text { text: Math.round(value) + " °C"; width: 52; horizontalAlignment: Text.AlignRight; color: value > warn ? Theme.red : Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle {
            width: parent.width; height: 5; radius: 3; color: Theme.bg3
            Rectangle {
                width: parent.width * Math.min(1, value / max); height: parent.height; radius: 3
                color: value > warn ? Theme.red : value > warn - 15 ? Theme.yellow : Theme.accent
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
    }

    Text { text: "Sensors"; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize }
    TempRow { glyph: "󰻠"; label: "CPU  (Ryzen 7 5700X)"; value: SysStats.temp; warn: 85; max: 95; extra: Math.round(SysStats.cpu) + "% load" }
    TempRow { glyph: "󰢮"; label: "GPU  (Arc B580)"; value: SysStats.gpuTemp; warn: 85; max: 100 }
    TempRow { glyph: "󰋊"; label: "NVMe"; value: SysStats.nvmeTemp; warn: 70; max: 85 }
    Text {
        width: parent.width; topPadding: 4
        text: "Fans and the GPU load aren't exposed by the drivers on this machine."
        wrapMode: Text.Wrap
        color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 2
    }
}
