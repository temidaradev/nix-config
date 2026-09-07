pragma Singleton
import QtQuick
import Quickshell
import qs.services

Singleton {
    readonly property var a: Settings.s.appearance

    // Breeze Dark
    readonly property real opacity: a.panelOpacity
    readonly property color panelBg: Qt.rgba(0x1b / 255, 0x1e / 255, 0x20 / 255, opacity)
    readonly property color cardBg: panelBg
    readonly property color cardBorder: "#33ffffff"
    readonly property color bg2: "#292c30"
    readonly property color bg3: "#31363b"
    readonly property color fg: "#fcfcfc"
    readonly property color fgDim: "#a9aeb3"
    readonly property color accent: a.accentFromWallpaper && Wallpaper.accent !== "" ? Wallpaper.accent : a.accent
    readonly property color green: "#27ae60"
    readonly property color yellow: "#f6c744"
    readonly property color red: "#da4453"
    readonly property color ringTrack: "#2c3033"

    readonly property string font: a.font
    readonly property real fontSize: a.fontSize
    readonly property real smallSize: a.fontSize - 1

    readonly property int barHeight: a.barHeight
    readonly property int radius: a.radius

    readonly property string wallpaper: Settings.s.wallpaper !== "" ? Settings.s.wallpaper : Quickshell.env("HOME") + "/.config/niri/wallpaper.png"
}
