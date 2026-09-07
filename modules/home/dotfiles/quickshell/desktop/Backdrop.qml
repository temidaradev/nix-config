import QtQuick
import QtQuick.Effects
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
        id: img
        anchors.fill: parent
        source: "file://" + Wallpaper.current
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        blurEnabled: true
        blur: 0.8
        blurMax: 48
        brightness: -0.25
        saturation: -0.2
    }
}
