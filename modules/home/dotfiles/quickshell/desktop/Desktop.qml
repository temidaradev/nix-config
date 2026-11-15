import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Wallpaper on the background layer, under all windows. Each theme has its
// own wallpaper; in Steins;Gate it can also be the drawn divergence-meter
// scene. Purely decorative: nothing here takes input.
PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-desktop"
    color: Theme.desktopBg

    Image {
        anchors.fill: parent
        visible: !Wallpaper.isScene
        source: visible ? "file://" + Wallpaper.current : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio)
        asynchronous: true
        smooth: true
        cache: false
    }

    // Steins;Gate art: a warm, dark grade so it sits with the amber shell
    Rectangle {
        anchors.fill: parent
        visible: Theme.steins && !Wallpaper.isScene
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#b0080402" }
            GradientStop { position: 0.12; color: "#30140802" }
            GradientStop { position: 0.75; color: "#20140802" }
            GradientStop { position: 1.0; color: "#a0080402" }
        }
    }

    Loader {
        anchors.fill: parent
        active: Theme.steins && Wallpaper.isScene
        sourceComponent: SteinsScene { interactive: false }
    }
}
