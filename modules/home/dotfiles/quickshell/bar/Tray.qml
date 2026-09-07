import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.services

Row {
    id: root
    required property var bar
    spacing: 2
    height: Theme.barHeight

    Repeater {
        model: SystemTray.items
        BarButton {
            id: btn
            required property SystemTrayItem modelData
            padding: 4
            color: Launcher.trayItem === modelData ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
            IconImage {
                source: modelData.icon
                implicitSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            function openMenu() { Launcher.openTrayMenu(modelData, btn.mapToItem(null, 0, 0).x + btn.width / 2) }
            onClicked: e => {
                if (e.button === Qt.LeftButton) {
                    if (modelData.onlyMenu && modelData.hasMenu) openMenu()
                    else modelData.activate()
                } else if (e.button === Qt.MiddleButton) modelData.secondaryActivate()
                else if (modelData.hasMenu) openMenu()
            }
            onWheel: e => modelData.scroll(e.angleDelta.y, false)
        }
    }
}
