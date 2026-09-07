import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

// Stack of notification cards, top-right under the bar.
PanelWindow {
    id: win
    visible: Notifs.popups.length > 0
    anchors { top: true; right: true }
    margins { top: 6; right: 6 }
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"

    Column {
        id: stack
        width: parent.width
        spacing: 6
        Repeater {
            model: Notifs.popups
            NotificationCard {
                required property Notification modelData
                n: modelData
                width: stack.width
                onClicked: Notifs.activate(n)
                onClosed: Notifs.dismiss(n)
            }
        }
    }
}
