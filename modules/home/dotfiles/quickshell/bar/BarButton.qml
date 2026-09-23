import QtQuick
import Quickshell
import qs
import qs.services

// Hover-highlighted container for a panel widget.
Rectangle {
    id: root
    property alias hovered: mouse.containsMouse
    property alias mouse: mouse
    property int padding: 6
    property string menu: ""
    function pop() { Launcher.toggleMenu(menu, mapToItem(null, 0, 0).x + width / 2) }
    Connections {
        target: Launcher
        enabled: root.menu !== ""
        function onLocate(name) { if (name === root.menu && root.visible && root.QsWindow.window?.screen === Launcher.screen) Launcher.menuAnchorX = root.mapToItem(null, 0, 0).x + root.width / 2 }
    }
    default property alias content: inner.data
    signal clicked(var event)
    signal wheel(var event)

    implicitWidth: inner.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.radius
    color: menu !== "" && Launcher.menu === menu ? "#40ffffff" : mouse.containsMouse ? "#2affffff" : "transparent"

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
