import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Blurred, darkened wallpaper shown behind workspaces in niri's overview.
// niri places it there via the "qs-backdrop" layer-rule. Steins;Gate: the
// lab scene without the meter, dimmed.
PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-backdrop"
    color: Theme.backdropBg

    Image {
        anchors.fill: parent
        visible: !Wallpaper.isScene
        source: visible && Wallpaper.blurred !== "" ? "file://" + Wallpaper.blurred : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
    }

    Loader {
        anchors.fill: parent
        active: Theme.steins && Wallpaper.isScene
        sourceComponent: Item {
            SteinsScene { anchors.fill: parent; showMeter: false; showText: false; interactive: false }
            Rectangle { anchors.fill: parent; color: "#80050302" }
        }
    }
}
