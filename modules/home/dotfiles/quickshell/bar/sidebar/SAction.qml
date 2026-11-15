import QtQuick
import QtQuick.Controls
import qs
Button {
    id: control
    property bool selected: false
    implicitHeight: 32; implicitWidth: Math.max(60, contentItem.implicitWidth + 20)
    contentItem: Text { text: control.text; color: control.selected ? Theme.bg2 : Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    background: Plate { color: control.selected ? Theme.accent : (control.hovered ? Theme.ink(0x33) : Theme.ink(0x19)); radius: Theme.radius; opacity: control.enabled ? 1 : 0.4 }
}
