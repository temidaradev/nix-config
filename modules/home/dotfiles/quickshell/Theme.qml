pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Breeze Dark
    readonly property color panelBg: "#f21b1e20"
    readonly property color cardBg: "#ee1b1e20"
    readonly property color cardBorder: "#33ffffff"
    readonly property color bg2: "#292c30"
    readonly property color bg3: "#31363b"
    readonly property color fg: "#fcfcfc"
    readonly property color fgDim: "#a9aeb3"
    readonly property color accent: "#3daee9"
    readonly property color green: "#27ae60"
    readonly property color yellow: "#f6c744"
    readonly property color red: "#da4453"
    readonly property color ringTrack: "#2c3033"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property real fontSize: 10       // pt, like Plasma
    readonly property real smallSize: 9

    readonly property int barHeight: 36
    readonly property int radius: 4

    readonly property string wallpaper: Quickshell.env("HOME") + "/.config/niri/wallpaper.png"
}
