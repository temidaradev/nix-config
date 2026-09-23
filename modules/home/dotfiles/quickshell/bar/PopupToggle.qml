import QtQuick
import qs

Item {
    id: t
    property string label
    property string sub: ""
    property bool on: false
    signal toggled(bool value)
    width: parent.width
    implicitHeight: Math.max(30, col.implicitHeight)
    Column {
        id: col
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 52
        Text { width: parent.width; elide: Text.ElideRight; text: t.label; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize }
        Text { visible: t.sub !== ""; width: parent.width; elide: Text.ElideRight; text: t.sub; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
    }
    PopupSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: t.on; onToggled: v => t.toggled(v) }
}
