import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Button {
    id: colorChooser

    signal colorChoosed(color selectedColor)

    property alias color: bg.color

    implicitWidth: 30
    implicitHeight: implicitWidth
    background: Rectangle {
        id: bg
        anchors.centerIn: parent
        anchors.fill: parent
        radius: 8
        color: "red"
    }
    onPressed: dialog.visible ? dialog.close() : dialog.open()
    ColorDialog {
        id: dialog
        title: i18n("Please choose a color")
        onAccepted: colorChooser.colorChoosed(selectedColor)
    }
}