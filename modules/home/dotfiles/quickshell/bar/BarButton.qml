import QtQuick
import qs

// Hover-highlighted container for a panel widget.
Rectangle {
    id: root
    property alias hovered: mouse.containsMouse
    property alias mouse: mouse
    property int padding: 6
    default property alias content: inner.data
    signal clicked(var event)
    signal wheel(var event)

    implicitWidth: inner.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.radius
    color: mouse.containsMouse ? "#2affffff" : "transparent"

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 4
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => root.clicked(e)
        onWheel: e => root.wheel(e)
    }
}
