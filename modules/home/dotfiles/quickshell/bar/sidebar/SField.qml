import QtQuick
import QtQuick.Controls
import qs
TextField {
    id: control
    width: parent.width; implicitHeight: 36; color: Theme.fg
    font.family: Theme.font; font.pointSize: Theme.smallSize
    placeholderTextColor: Theme.fgDim; selectByMouse: true
    background: Plate { color: "#16000000"; radius: Theme.radius; strokeWidth: 1; stroke: control.activeFocus ? Theme.accent : Theme.cardBorder }
}
