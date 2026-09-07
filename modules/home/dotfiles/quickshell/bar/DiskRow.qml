import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: row
    property var disk
    implicitHeight: col.implicitHeight
    Column {
        id: col
        width: parent.width
        spacing: 3
        Row {
            width: parent.width
            Text {
                width: parent.width - 150; elide: Text.ElideMiddle
                text: row.disk ? row.disk.mount.replace(/^\/run\/media\/[^/]+\//, "") : ""
                color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize
            }
            Text {
                width: 150; horizontalAlignment: Text.AlignRight
                text: row.disk ? SysStats.fmtBytes(row.disk.used, 0) + " / " + SysStats.fmtBytes(row.disk.size, 0) : ""
                color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
            }
        }
        Rectangle {
            width: parent.width; height: 6; radius: 3; color: Theme.bg3
            Rectangle {
                width: parent.width * Math.min(1, (row.disk ? row.disk.pct : 0) / 100); height: parent.height; radius: 3
                color: !row.disk ? Theme.accent : row.disk.pct > 90 ? Theme.red : row.disk.pct > 75 ? Theme.yellow : Theme.accent
            }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: if (row.disk) Quickshell.execDetached(["dolphin", row.disk.mount]) }
}
