import QtQuick
import QtQuick.Shapes
import qs

// Plasma-style ring gauge, arc grows counter-clockwise from 6 o'clock.
// Steins;Gate: an analogue lab dial instead (ticks, needle, readout).
Item {
    id: g
    property real value: 0          // 0..100
    property string label: ""
    property string center: value.toFixed(0) + "%"
    property color color: Theme.accent
    property real size: 96
    width: size; height: size + (label !== "" ? 18 : 0)
    readonly property real clamped: Math.max(0, Math.min(100, value))

    Shape {
        visible: !Theme.steins
        width: g.size; height: g.size
        anchors.horizontalCenter: parent.horizontalCenter
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.ringTrack; strokeWidth: 5; fillColor: "transparent"
            PathAngleArc { centerX: g.size / 2; centerY: g.size / 2; radiusX: g.size / 2 - 4; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: g.color; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: g.size / 2; centerY: g.size / 2; radiusX: g.size / 2 - 4; radiusY: radiusX
                startAngle: 90
                sweepAngle: -g.clamped * 3.6
                Behavior on sweepAngle { enabled: !Theme.reducedMotion; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        Text { anchors.centerIn: parent; text: g.center; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize }
    }

    Loader {
        active: Theme.steins
        width: g.size; height: g.size
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: Item {
            id: dial
            readonly property real r: width / 2
            // 270-degree sweep: 0 at 7:30, 100 at 4:30 (0 deg = 12 o'clock)
            function angle(v) { return -135 + v * 2.7 }

            Canvas {   // face: bezel, ticks, numerals, hot band. Painted once per size.
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d"), r = width / 2, c = r
                    ctx.reset()
                    const toRad = d => (d - 90) * Math.PI / 180
                    // bezel and face
                    let grad = ctx.createRadialGradient(c, c * 0.8, r * 0.1, c, c, r)
                    grad.addColorStop(0, "#1f1309"); grad.addColorStop(1, "#080503")
                    ctx.fillStyle = grad
                    ctx.beginPath(); ctx.arc(c, c, r - 1, 0, Math.PI * 2); ctx.fill()
                    ctx.lineWidth = 2; ctx.strokeStyle = "#5a3a1a"
                    ctx.beginPath(); ctx.arc(c, c, r - 1.5, 0, Math.PI * 2); ctx.stroke()
                    ctx.lineWidth = 1; ctx.strokeStyle = "#2a1a0c"
                    ctx.beginPath(); ctx.arc(c, c, r - 5, 0, Math.PI * 2); ctx.stroke()
                    // hot band 80-100
                    ctx.lineWidth = 3; ctx.strokeStyle = "rgba(255, 158, 44, 0.55)"
                    ctx.beginPath(); ctx.arc(c, c, r - 9, toRad(dial.angle(80)), toRad(dial.angle(100))); ctx.stroke()
                    // ticks: minor every 5, major every 10
                    for (let v = 0; v <= 100; v += 5) {
                        const a = toRad(dial.angle(v)), major = v % 10 === 0
                        const r0 = r - (major ? 15 : 12), r1 = r - 7
                        ctx.strokeStyle = major ? "#ffdcae" : "#a88760"
                        ctx.lineWidth = major ? 1.6 : 1
                        ctx.beginPath(); ctx.moveTo(c + Math.cos(a) * r0, c + Math.sin(a) * r0); ctx.lineTo(c + Math.cos(a) * r1, c + Math.sin(a) * r1); ctx.stroke()
                    }
                    // numerals across the top (0 and 100 would sit on the readout)
                    ctx.fillStyle = "#c9a57a"; ctx.font = Math.max(7, Math.round(r * 0.2)) + "px monospace"
                    ctx.textAlign = "center"; ctx.textBaseline = "middle"
                    for (const v of [25, 50, 75]) {
                        const a = toRad(dial.angle(v)), rr = r - 23
                        ctx.fillText(String(v), c + Math.cos(a) * rr, c + Math.sin(a) * rr)
                    }
                }
            }

            // digital readout in the lower half, like a meter's window
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.66
                width: readout.implicitWidth + 8; height: readout.implicitHeight + 2
                color: "#0a0604"; border.width: 1; border.color: "#3a2614"
                Text {
                    id: readout
                    anchors.centerIn: parent
                    text: g.center
                    color: Theme.accent
                    font.family: Theme.font; font.pointSize: Theme.smallSize - 1
                }
            }

            // needle
            Rectangle {
                id: needle
                width: 2; height: dial.r - 10
                x: dial.r - width / 2; y: dial.r - height
                antialiasing: true
                transformOrigin: Item.Bottom
                rotation: dial.angle(g.clamped)
                Behavior on rotation { enabled: !Theme.reducedMotion; NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.cyan }
                    GradientStop { position: 0.7; color: "#ffdcae" }
                    GradientStop { position: 1.0; color: "#ffdcae" }
                }
            }
            Rectangle {   // hub
                width: 9; height: 9; radius: 4.5
                x: dial.r - 4.5; y: dial.r - 4.5
                color: "#2a1c10"; border.width: 1.5; border.color: Theme.accent
            }
        }
    }

    Text {
        visible: g.label !== ""
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        text: g.label; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
    }
}
