import QtQuick
import QtQuick.Controls
import qs
Switch {
    id: control
    width: parent.width
    contentItem: Text { text: control.text; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize; verticalAlignment: Text.AlignVCenter; leftPadding: control.indicator.width + control.spacing; wrapMode: Text.Wrap }
}
