import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

// Tray item menu drawn by the shell. Submenus replace the list with a back row.
BarPopup {
    id: menu
    visible: Launcher.trayItem !== null
    panelWidth: 240
    padding: 6
    anchorX: Launcher.trayAnchorX
    onDismissed: Launcher.trayItem = null

    property var stack: []                          // submenu handles
    readonly property var handle: stack.length > 0 ? stack[stack.length - 1] : (Launcher.trayItem ? Launcher.trayItem.menu : null)
    onVisibleChanged: if (visible) stack = []

    QsMenuOpener { id: opener; menu: menu.handle }

    BarButton {
        visible: menu.stack.length > 0
        width: parent.width; implicitHeight: 28; padding: 8
        onClicked: menu.stack = menu.stack.slice(0, -1)
        BarText { text: "󰅁  Back"; color: Theme.fgDim }
    }

    Repeater {
        model: opener.children
        Item {
            required property var modelData
            width: parent.width
            height: modelData.isSeparator ? 9 : 28

            Rectangle { visible: modelData.isSeparator; anchors.centerIn: parent; width: parent.width - 12; height: 1; color: "#22ffffff" }

            Rectangle {
                visible: !modelData.isSeparator
                anchors.fill: parent
                radius: Theme.radius
                color: ma.containsMouse && modelData.enabled ? "#2affffff" : "transparent"
                Row {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        text: modelData.buttonType === QsMenuButtonType.CheckBox ? (modelData.checkState === Qt.Checked ? "󰄲" : "󰄱")
                            : modelData.buttonType === QsMenuButtonType.RadioButton ? (modelData.checkState === Qt.Checked ? "󰐾" : "󰄰") : ""
                        color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize
                    }
                    IconImage {
                        visible: modelData.icon !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16; source: modelData.icon
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 14 - 8 - (modelData.icon !== "" ? 24 : 0) - 16
                        elide: Text.ElideRight
                        text: modelData.text
                        color: modelData.enabled ? Theme.fg : "#66ffffff"
                        font.family: Theme.font; font.pointSize: Theme.smallSize
                    }
                    Text {
                        visible: modelData.hasChildren
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅂"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent; hoverEnabled: true
                    enabled: modelData.enabled
                    onClicked: {
                        if (modelData.hasChildren) menu.stack = menu.stack.concat([modelData])
                        else { modelData.triggered(); Launcher.trayItem = null }
                    }
                }
            }
        }
    }
}
