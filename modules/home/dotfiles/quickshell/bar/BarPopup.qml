import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Full-screen transparent layer that closes on outside click, with a panel
// positioned below the bar. Children go inside the panel.
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.keyboardFocus: visible && wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool wantsKeyboard: false
    property real panelWidth: 360
    property real panelHeight: content.implicitHeight + 24
    property real anchorX: -1            // centre the panel on this x; -1 = right edge
    property bool anchorRight: anchorX < 0
    property int padding: 12
    default property alias content: content.data
    signal dismissed

    MouseArea { anchors.fill: parent; onClicked: win.dismissed() }

    Rectangle {
        id: panel
        width: win.panelWidth
        height: win.panelHeight
        y: Theme.barHeight + 4
        x: win.anchorRight ? win.width - width - 4 : Math.max(4, Math.min(win.width - width - 4, win.anchorX - width / 2))
        radius: 6
        color: Theme.panelBg
        border.color: Theme.cardBorder; border.width: 1
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: win.padding
            spacing: 8
        }
    }
}
