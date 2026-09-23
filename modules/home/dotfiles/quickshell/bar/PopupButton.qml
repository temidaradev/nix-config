import QtQuick
import qs

BarButton {
    id: b
    property string label
    property bool on: false
    property bool danger: false
    padding: 8; implicitHeight: 26
    color: on ? Theme.accent : danger && hovered ? Theme.red : hovered ? "#2affffff" : Theme.bg2
    BarText { text: b.label; font.pointSize: Theme.smallSize - 1; color: b.on || (b.danger && b.hovered) ? "#1b1e20" : Theme.fg }
}
