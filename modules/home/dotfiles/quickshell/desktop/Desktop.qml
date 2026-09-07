import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Wallpaper on the background layer, under all windows.
PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-desktop"
    color: "#6e84ac"

    Image {
        anchors.fill: parent
        source: "file://" + Wallpaper.current
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }
}
