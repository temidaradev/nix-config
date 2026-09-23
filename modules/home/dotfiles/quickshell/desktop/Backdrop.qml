import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Blurred, darkened wallpaper shown behind workspaces in niri's overview.
// niri places it there via the "qs-backdrop" layer-rule.
PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-backdrop"
    color: "#3d4a63"

    Image {
        anchors.fill: parent
        source: Wallpaper.blurred !== "" ? "file://" + Wallpaper.blurred : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
    }
}
