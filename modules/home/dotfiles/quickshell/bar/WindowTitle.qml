import QtQuick
import Quickshell.Widgets
import qs
import qs.services

// Focused window: app icon + title, like Plasma's window-title applet.
BarButton {
    readonly property var win: Niri.windows.find(w => w.id === Niri.focusedWindow) || null
    visible: Settings.s.bar.windowTitle && win !== null
    padding: 8
    IconImage {
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 16
        asynchronous: true
        source: win ? Apps.icon(win.app_id) : ""
    }
    BarText {
        text: win ? (win.title || win.app_id || "") : ""
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 320)
        color: Theme.fgDim
    }
    onClicked: e => { if (!win) return; if (e.button === Qt.RightButton) Niri.closeWindow(win.id); else Launcher.toggleSidebar() }
}
