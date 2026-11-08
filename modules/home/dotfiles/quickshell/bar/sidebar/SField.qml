import QtQuick
import QtQuick.Controls
import qs
TextField {
    id: control
    width: parent.width; implicitHeight: 36; color: Theme.fg
    font.family: Theme.font; font.pointSize: Theme.smallSize
    placeholderTextColor: Theme.fgDim; selectByMouse: true
    background: Rectangle { color: "#16000000"; radius: Theme.radius; border.width: 1; border.color: control.activeFocus ? Theme.accent : Theme.cardBorder }
}
