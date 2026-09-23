import QtQuick
import qs

Item {
    id: t
    property string text
    property string sub: ""
    property string glyph: ""
    property color glyphColor: Theme.accent
    default property alias trailing: tr.data
    width: parent.width
    implicitHeight: Math.max(head.implicitHeight, tr.implicitHeight)

    Row {
        id: head
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        width: parent.width - tr.width - 8
        spacing: 10
        Text {
            id: g
            visible: t.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: t.glyph; color: t.glyphColor
            font.family: Theme.font; font.pointSize: 18
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (g.visible ? g.width + 10 : 0)
            Text { width: parent.width; elide: Text.ElideRight; text: t.text; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize + 1 }
            Text { visible: t.sub !== ""; width: parent.width; elide: Text.ElideRight; text: t.sub; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        }
    }
    Row { id: tr; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6 }
}
