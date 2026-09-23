import QtQuick
import qs

Rectangle {
    id: r
    property string glyph: ""
    property string label
    property string sub: ""
    property string detail: ""
    property bool active: false
    property string action: ""
    signal clicked
    signal actionClicked
    width: parent.width
    height: sub !== "" ? 40 : 32
    radius: Theme.radius
    color: ma.containsMouse ? "#2affffff" : "transparent"
    Row {
        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 8
        Text { visible: r.glyph !== ""; anchors.verticalCenter: parent.verticalCenter; width: 18; text: r.glyph; color: r.active ? Theme.accent : Theme.fg; font.family: Theme.font; font.pointSize: 12 }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (r.glyph !== "" ? 26 : 0) - (det.visible ? det.width + 8 : 0) - (btn.visible ? btn.width + 8 : 0)
            Text { width: parent.width; elide: Text.ElideRight; text: r.label; color: r.active ? Theme.accent : Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize }
            Text { visible: r.sub !== ""; width: parent.width; elide: Text.ElideRight; text: r.sub; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
        }
        Text { id: det; visible: r.detail !== ""; anchors.verticalCenter: parent.verticalCenter; text: r.detail; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        PopupButton { id: btn; visible: r.action !== ""; anchors.verticalCenter: parent.verticalCenter; label: r.action; implicitHeight: 24; onClicked: r.actionClicked() }
    }
    MouseArea { id: ma; anchors.fill: parent; anchors.rightMargin: btn.visible ? btn.width + 10 : 0; hoverEnabled: true; onClicked: r.clicked() }
}
