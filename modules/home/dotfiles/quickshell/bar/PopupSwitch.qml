import QtQuick
import qs

Rectangle {
    id: sw
    property bool on: false
    signal toggled(bool value)
    width: 40; height: 22; radius: 11
    color: on ? Theme.accent : Theme.bg3
    Rectangle { x: sw.on ? sw.width - width - 3 : 3; y: 3; width: 16; height: 16; radius: 8; color: Theme.fg }
    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled(!sw.on) }
}
