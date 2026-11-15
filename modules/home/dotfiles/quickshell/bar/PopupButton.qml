import QtQuick
import qs

BarButton {
    id: b
    property string label
    property bool on: false
    property bool danger: false
    padding: 8; implicitHeight: 26
    color: on ? Theme.accent : danger && hovered ? Theme.red : hovered ? Theme.ink(0x2a) : Theme.bg2
    BarText { text: b.label; font.pointSize: Theme.smallSize - 1; color: b.on || (b.danger && b.hovered) ? Theme.onAccent : Theme.fg }
}
