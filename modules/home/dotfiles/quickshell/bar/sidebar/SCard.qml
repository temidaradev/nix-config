import QtQuick
import qs
Rectangle {
    default property alias contents: body.data
    width: parent.width
    implicitHeight: body.implicitHeight + 24
    color: Theme.bg3; radius: Theme.radius
    Column { id: body; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 9 }
}
