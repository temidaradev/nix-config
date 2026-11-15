pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Two palettes: "normal" (Breeze Dark) and "steinsgate" (divergence-meter
// amber on lab-black). The mode lives in ~/.local/state/quickshell/theme and is
// written by `shell-theme` (niri.nix), which also re-themes niri and ghostty.
Singleton {
    id: root
    readonly property var a: Settings.s.appearance

    property string mode: "normal"
    readonly property bool steins: mode === "steinsgate"
    function toggle() { Quickshell.execDetached(["shell-theme", "toggle"]) }
    function setMode(m) { Quickshell.execDetached(["shell-theme", m]) }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/theme"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.mode = text().trim() === "steinsgate" ? "steinsgate" : "normal"
        onLoadFailed: root.mode = "normal"
    }
    IpcHandler {
        target: "theme"
        function toggle(): void { root.toggle() }
        function set(mode: string): void { root.setMode(mode) }
        function get(): string { return root.mode }
    }

    // Steins;Gate: nixie glow #ff9e2c (the official divergence-meter CG
    // temperature), warm unlit-cathode browns, CRT phosphor green, lab red.
    readonly property var sg: ({
        panel: "#100a06", bg2: "#1f150c", bg3: "#2a1c10", fg: "#ffdcae", fgDim: "#a88760",
        accent: "#ff9e2c", onAccent: "#160b03", green: "#8fd16a", yellow: "#ffcc4d", red: "#e8452c", cyan: "#5fd4e0",
        ring: "#2b1d11", ink: "#ffc78a", border: "#4dff9e2c", desktop: "#0a0604", backdrop: "#140b05"
    })

    readonly property real opacity: a.panelOpacity
    readonly property color _panel: steins ? sg.panel : "#1b1e20"
    readonly property color panelBg: Qt.rgba(_panel.r, _panel.g, _panel.b, opacity)
    readonly property color cardBg: panelBg
    readonly property color bg0: _panel
    readonly property color cardBorder: steins ? sg.border : "#33ffffff"
    readonly property color bg2: steins ? sg.bg2 : "#292c30"
    readonly property color bg3: steins ? sg.bg3 : "#31363b"
    readonly property color fg: steins ? sg.fg : "#fcfcfc"
    readonly property color fgDim: steins ? sg.fgDim : "#a9aeb3"
    readonly property color accent: steins ? sg.accent : (a.accentFromWallpaper && Wallpaper.accent !== "" ? Wallpaper.accent : a.accent)
    readonly property color onAccent: steins ? sg.onAccent : "#1b1e20"     // text drawn on an accent fill
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.28)
    // Steins;Gate roles: amber = main accent, green = good, cyan = second
    // accent (info, links, D-mail), red = errors only.
    readonly property color cyan: steins ? sg.cyan : accent
    readonly property color green: steins ? sg.green : "#27ae60"
    readonly property color yellow: steins ? sg.yellow : "#f6c744"
    readonly property color red: steins ? sg.red : "#da4453"
    readonly property color ringTrack: steins ? sg.ring : "#2c3033"
    readonly property color desktopBg: steins ? sg.desktop : "#6e84ac"
    readonly property color backdropBg: steins ? sg.backdrop : "#3d4a63"

    // Translucent highlight (hover, separators, dim text): white normally,
    // warm amber-cream in Steins;Gate. alpha is 0..255 like the old "#XXffffff".
    readonly property color _ink: steins ? sg.ink : "#ffffff"
    function ink(alpha) { return Qt.rgba(_ink.r, _ink.g, _ink.b, alpha / 255) }
    function panel(alpha) { return Qt.rgba(_panel.r, _panel.g, _panel.b, alpha) }

    readonly property string font: a.font
    readonly property real fontSize: a.fontSize
    readonly property real smallSize: a.fontSize - 1

    readonly property int barHeight: a.barHeight
    // Steins;Gate shapes are hard-edged: square corners, chamfered plates
    // (see Plate.qml / Chamfer.qml) and diamond knobs.
    readonly property int radius: steins ? 0 : a.radius
    readonly property real cut: 7
    function r(n) { return steins ? 0 : n }          // for fixed radii
    readonly property real knobRotation: steins ? 45 : 0
    readonly property bool reducedMotion: a.reducedMotion === "auto" ? Battery.saving : a.reducedMotion === true

    readonly property string wallpaper: Settings.s.wallpaper !== "" ? Settings.s.wallpaper : Quickshell.env("HOME") + "/.config/niri/wallpaper.png"
}
