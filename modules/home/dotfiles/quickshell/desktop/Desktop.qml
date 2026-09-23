import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Wallpaper on the background layer, under all windows.
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-desktop"
    color: "#6e84ac"

    Image {
        anchors.fill: parent
        source: "file://" + Wallpaper.current
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio)
        asynchronous: true
        smooth: true
        cache: false
    }
}
