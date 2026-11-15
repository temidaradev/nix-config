import QtQuick
import qs
import qs.services

// Notification history under the bell, with do-not-disturb and clear.
BarPopup {
    visible: Launcher.notifOpen
    panelWidth: 400
    anchorX: Launcher.notifAnchorX
    onDismissed: Launcher.notifOpen = false

    Row {
        width: parent.width; spacing: 6
        Text {
            width: parent.width - 160; anchors.verticalCenter: parent.verticalCenter
            text: "Notifications" + (Notifs.count > 0 ? "  " + Notifs.count : "")
            color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize
        }
        BarButton {
            width: 92; implicitHeight: 24; padding: 6
            color: Notifs.dnd ? Theme.accent : (hovered ? Theme.ink(0x2a) : Theme.bg2)
            BarText { text: Notifs.dnd ? "󰂛 DND on" : "󰂚 DND off"; font.pointSize: Theme.smallSize - 1; color: Notifs.dnd ? Theme.onAccent : Theme.fg }
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        BarButton {
            width: 56; implicitHeight: 24; padding: 6
            visible: Notifs.count > 0
            color: hovered ? Theme.ink(0x2a) : Theme.bg2
            BarText { text: "Clear"; font.pointSize: Theme.smallSize - 1 }
            onClicked: Notifs.clearAll()
        }
    }

    Text {
        visible: Notifs.count === 0
        width: parent.width; horizontalAlignment: Text.AlignHCenter
        topPadding: 24; bottomPadding: 24
        text: "󰂜\nNo notifications"
        color: Theme.ink(0x66); font.family: Theme.font; font.pointSize: Theme.smallSize
    }

    Flickable {
        visible: Notifs.count > 0
        width: parent.width
        height: Math.min(520, list.implicitHeight)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: list
            width: parent.width; spacing: 6
            Repeater {
                model: Notifs.history.slice().reverse()
                NotificationCard {
                    required property var modelData
                    n: modelData; width: list.width
                    onClicked: Notifs.activate(n)
                    onClosed: Notifs.dismiss(n)
                }
            }
        }
    }
}
