import QtQuick
import QtQuick.Effects
import qs

// One nixie tube, built like the divergence meter's: glass envelope, the
// unlit cathode stack behind, the lit cathode with its orange glow, and the
// hexagonal anode mesh in front. `ch` is a digit, "." or ":" (or " " for off).
Item {
    id: tube
    property string ch: "0"
    property real tubeWidth: 60
    property color glow: "#ff9e2c"
    property color core: "#ffd7a0"
    property real glowStrength: 1.0
    width: tubeWidth
    height: tubeWidth * 2.55

    readonly property bool isDigit: /^[0-9]$/.test(ch)
    readonly property real glassH: height * 0.88
    readonly property real r: width / 2

    // ---- glass envelope (smooth top, as on the anime meter)
    Rectangle {
        id: glass
        width: parent.width; height: tube.glassH
        radius: tube.r
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#3a1e0e10" }
            GradientStop { position: 0.18; color: "#2a2a1608" }
            GradientStop { position: 0.5; color: "#18100804" }
            GradientStop { position: 0.85; color: "#2a2a1608" }
            GradientStop { position: 1.0; color: "#40201008" }
        }
        border.width: 1
        border.color: Qt.rgba(1, 0.75, 0.5, 0.16)
        // a warm wash from the lit cathode reflecting inside the glass
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            visible: tube.ch !== " "
            gradient: Gradient {
                GradientStop { position: 0.15; color: "transparent" }
                GradientStop { position: 0.55; color: Qt.rgba(tube.glow.r, tube.glow.g, tube.glow.b, 0.10 * tube.glowStrength) }
                GradientStop { position: 0.95; color: "transparent" }
            }
        }
        // specular streak
        Rectangle {
            x: parent.width * 0.13; y: parent.height * 0.1
            width: Math.max(1.5, parent.width * 0.035); height: parent.height * 0.6
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#26fff2e0" }
                GradientStop { position: 0.5; color: "#0afff2e0" }
                GradientStop { position: 1; color: "#00fff2e0" }
            }
        }
        // getter/top of the tube
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.035
            width: parent.width * 0.34; height: Math.max(2, parent.width * 0.05)
            radius: height / 2
            color: "#40b0a090"
        }
    }

    // ---- cathodes
    Item {
        id: cathodes
        x: tube.width * 0.1; width: tube.width * 0.8
        y: tube.glassH * 0.13; height: tube.glassH * 0.72
        readonly property real px: height * 0.98

        // unlit cathode stack: every numeral, overlapped, dull wire
        Repeater {
            model: tube.isDigit || tube.ch === " " ? ["1", "6", "2", "7", "5", "0", "4", "9", "8", "3"] : []
            Text {
                required property string modelData
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: modelData
                color: "#6b4c34"
                opacity: 0.13
                font.family: "Noto Sans"; font.weight: Font.ExtraLight
                font.pixelSize: cathodes.px
            }
        }

        // glow halo: a blurred, tinted copy under the wire (GPU renderers)
        MultiEffect {
            source: lit
            anchors.fill: lit
            visible: tube.ch !== " "
            autoPaddingEnabled: true
            blurEnabled: true; blur: 1.0; blurMax: 44; blurMultiplier: 0.6
            colorization: 1.0; colorizationColor: tube.glow
            brightness: 0.35
            opacity: Math.min(1, 0.9 * tube.glowStrength)
        }

        // lit cathode: hot core with an orange sheath (also the software fallback)
        Item {
            id: lit
            anchors.fill: parent
            Text {
                anchors.fill: parent
                visible: tube.isDigit
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: tube.ch
                color: tube.core
                style: Text.Outline; styleColor: Qt.rgba(tube.glow.r, tube.glow.g, tube.glow.b, 0.85)
                font.family: "Noto Sans"; font.weight: Font.ExtraLight
                font.pixelSize: cathodes.px
            }
            Rectangle {     // decimal point, low in the tube
                visible: tube.ch === "."
                width: tube.width * 0.16; height: width; radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.8 - height / 2
                color: tube.core
                border.width: Math.max(1, width * 0.18); border.color: tube.glow
            }
            Column {         // colon for the clock
                visible: tube.ch === ":"
                anchors.centerIn: parent
                spacing: parent.height * 0.2
                Repeater {
                    model: 2
                    Rectangle { width: tube.width * 0.15; height: width; radius: width / 2; color: tube.core; border.width: Math.max(1, width * 0.18); border.color: tube.glow }
                }
            }
        }
    }

    // ---- anode mesh in front of the cathodes (drawn once per size)
    Canvas {
        anchors.fill: glass
        opacity: 0.55
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.save()
            ctx.beginPath()
            const rr = width / 2
            ctx.moveTo(0, rr); ctx.arc(rr, rr, rr, Math.PI, 0); ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
            ctx.clip()
            ctx.strokeStyle = "rgba(40, 24, 14, 0.85)"
            ctx.lineWidth = Math.max(0.6, width / 110)
            const s = Math.max(4, width / 9)          // hex cell size
            const h = s * Math.sqrt(3) / 2
            for (let row = 0, y = 0; y < height + h; row++, y += h) {
                const off = (row % 2) * s * 1.5
                for (let x = -s * 3 + off; x < width + s * 3; x += s * 3) {
                    ctx.beginPath()
                    for (let k = 0; k <= 6; k++) {
                        const a = Math.PI / 3 * k
                        const px = x + s * Math.cos(a), py = y + s * Math.sin(a)
                        if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                    }
                    ctx.stroke()
                }
            }
            ctx.restore()
        }
    }

    // ---- base and pins
    Rectangle {
        y: tube.glassH - 2
        width: parent.width; height: parent.height - tube.glassH + 2
        radius: 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#2a2018" }
            GradientStop { position: 0.4; color: "#14100c" }
            GradientStop { position: 1; color: "#080605" }
        }
        border.width: 1; border.color: "#3a2c20"
        Row {
            anchors.centerIn: parent
            spacing: tube.width * 0.12
            Repeater {
                model: 4
                Rectangle { width: Math.max(1.5, tube.width * 0.04); height: width; radius: width / 2; color: "#7a6450" }
            }
        }
    }
}
