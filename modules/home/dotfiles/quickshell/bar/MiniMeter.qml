import QtQuick
import QtQuick.Effects
import qs
import qs.services

// The divergence meter, bar-sized: one dark glass tube per character with a
// glowing amber cathode. When the focused workspace changes it flickers
// random digits for half a second (a purely visual glitch; the world line
// itself does not move), then settles back on Worldline.display.
Item {
    id: m
    property real tubeHeight: Theme.barHeight - 12
    readonly property real tubeWidth: Math.round(tubeHeight * 0.5)
    property string glitch: ""
    readonly property string shown: glitch !== "" ? glitch : Worldline.display
    implicitWidth: tubes.width
    implicitHeight: tubeHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // ---- flicker on workspace switch
    readonly property var focusedWs: Niri.workspaces.find(w => w.is_focused)?.id ?? -1
    onFocusedWsChanged: if (Theme.steins && !Theme.reducedMotion && !Worldline.shifting) { flick.n = 0; flick.restart() }
    function scramble() {
        let s = ""
        for (let i = 0; i < Worldline.display.length; i++)
            s += Worldline.display[i] === "." ? "." : (Math.random() < 0.7 ? String(Math.floor(Math.random() * 10)) : Worldline.display[i])
        return s
    }
    Timer {
        id: flick
        property int n: 0
        interval: 50; repeat: true
        onTriggered: { if (++n >= 10) { stop(); m.glitch = "" } else m.glitch = m.scramble() }
    }

    // ---- glass envelopes
    Row {
        id: tubes
        spacing: 2
        Repeater {
            model: m.shown.length
            Rectangle {
                required property int index
                width: m.tubeWidth; height: m.tubeHeight
                radius: width / 2.4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#241509" }
                    GradientStop { position: 0.5; color: "#0b0603" }
                    GradientStop { position: 1.0; color: "#1c1007" }
                }
                border.width: 1
                border.color: Qt.rgba(1, 0.62, 0.17, 0.22)
                Rectangle {   // glass highlight
                    x: 2; y: 3; width: 1; height: parent.height - 8
                    color: "#20fff2e0"
                }
            }
        }
    }

    // ---- faint glow: a blurred amber copy of the digits behind them
    MultiEffect {
        source: digits
        x: digits.x; y: digits.y; width: digits.width; height: digits.height
        autoPaddingEnabled: true
        blurEnabled: true; blur: 0.7; blurMax: 10
        colorization: 1.0; colorizationColor: "#ff8a1a"
        brightness: 0.25
        opacity: m.glitch !== "" ? 0.55 : 0.8
    }

    // ---- lit cathodes
    Row {
        id: digits
        x: tubes.x; y: tubes.y
        spacing: tubes.spacing
        Repeater {
            model: m.shown.length
            Item {
                required property int index
                width: m.tubeWidth; height: m.tubeHeight
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: m.shown[index] === "." ? m.tubeHeight * 0.28 : 0
                    text: m.shown[index] === "." ? "•" : m.shown[index]
                    color: m.glitch !== "" ? "#ffd7a0" : "#ffc27a"
                    font.family: "Noto Sans"; font.weight: Font.Normal
                    font.pixelSize: m.shown[index] === "." ? m.tubeHeight * 0.4 : m.tubeHeight * 0.78
                }
            }
        }
    }
}
