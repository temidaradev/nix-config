import QtQuick
import QtQuick.Controls
import qs
Column {
    id: root
    property string label
    property var options: []
    property var values: options
    property var current: ""
    signal chosen(var value)
    width: parent.width; spacing: 4
    SHint { text: root.label; visible: text !== "" }
    ComboBox {
        id: control
        width: parent.width; implicitHeight: 34; model: root.options
        currentIndex: Math.max(0, root.values.findIndex(v => String(v) === String(root.current)))
        onActivated: index => root.chosen(root.values[index])
        contentItem: Text { text: control.displayText; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; leftPadding: 10; rightPadding: 28 }
        background: Plate { color: "#18000000"; radius: Theme.radius; stroke: Theme.cardBorder; strokeWidth: 1 }
        popup: Popup {
            y: control.height; width: control.width
            implicitHeight: Math.min(280, contentItem.implicitHeight + 8)
            padding: 4
            background: Plate { color: Theme.bg2; stroke: Theme.cardBorder; strokeWidth: 1; radius: Theme.radius }
            contentItem: ListView {
                clip: true; implicitHeight: contentHeight; model: control.popup.visible ? control.delegateModel : null
                currentIndex: control.highlightedIndex; ScrollBar.vertical: ScrollBar {}
            }
        }
        delegate: ItemDelegate {
            required property int index
            required property var modelData
            width: control.width; height: 34
            contentItem: Text { text: String(modelData); color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? Theme.ink(0x30) : "transparent" }
        }
    }
}
