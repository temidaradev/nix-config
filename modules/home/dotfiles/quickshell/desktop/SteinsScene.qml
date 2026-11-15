import QtQuick
import Quickshell
import qs
import qs.services

// The Steins;Gate desktop: lab-black with a warm core, clockwork, the world
// line branching diagram, and the divergence meter. Everything is painted
// once; the only motion is a worldline shift (gears turn, tubes roll), so the
// background layer stays idle otherwise.
Item {
    id: scene
    property bool showMeter: true
    property bool showText: true
    property bool interactive: false
    readonly property real s: Math.max(0.45, Math.min(width / 1920, height / 1080))
    readonly property color amber: Theme.sg.accent

    // ------------------------------------------------------------ backdrop
    Canvas {
        id: back
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"), w = width, h = height, k = scene.s
            ctx.reset()
            // warm core behind the meter, fading to lab-black
            const cx = w / 2, cy = h * 0.42
            let g = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(w, h) * 0.75)
            g.addColorStop(0, "#2a1407"); g.addColorStop(0.35, "#140a05"); g.addColorStop(1, "#050302")
            ctx.fillStyle = g; ctx.fillRect(0, 0, w, h)

            // fine blueprint grid
            ctx.strokeStyle = "rgba(255, 158, 44, 0.035)"; ctx.lineWidth = 1
            const step = 48 * k
            for (let x = (w / 2) % step; x < w; x += step) { ctx.beginPath(); ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, h); ctx.stroke() }
            for (let y = (h / 2) % step; y < h; y += step) { ctx.beginPath(); ctx.moveTo(0, y + 0.5); ctx.lineTo(w, y + 0.5); ctx.stroke() }

            // clock dial around the meter (the opening's clockwork)
            const R = Math.min(w, h) * 0.36
            ctx.strokeStyle = "rgba(255, 158, 44, 0.07)"; ctx.lineWidth = 1.2 * k
            ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, R * 0.93, 0, Math.PI * 2); ctx.stroke()
            ctx.strokeStyle = "rgba(255, 158, 44, 0.04)"
            ctx.beginPath(); ctx.arc(cx, cy, R * 1.18, 0, Math.PI * 2); ctx.stroke()
            for (let i = 0; i < 60; i++) {
                const a = i / 60 * Math.PI * 2, big = i % 5 === 0
                const r0 = R * (big ? 0.95 : 0.975), r1 = R
                ctx.strokeStyle = big ? "rgba(255, 170, 70, 0.16)" : "rgba(255, 170, 70, 0.07)"
                ctx.lineWidth = (big ? 2 : 1) * k
                ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0); ctx.lineTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1); ctx.stroke()
            }
            const roman = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
            ctx.fillStyle = "rgba(255, 180, 90, 0.13)"
            ctx.font = Math.round(15 * k) + "px serif"
            ctx.textAlign = "center"; ctx.textBaseline = "middle"
            for (let i = 0; i < 12; i++) {
                const a = i / 12 * Math.PI * 2 - Math.PI / 2
                ctx.fillText(roman[i], cx + Math.cos(a) * R * 1.08, cy + Math.sin(a) * R * 1.08)
            }

            // world line diagram: one past, many futures
            const y0 = h * 0.86, x0 = w * 0.06, x1 = w * 0.94
            const lines = [
                { dy: -0.10, v: "1.130205", hot: false }, { dy: -0.06, v: "1.048596", hot: true },
                { dy: -0.025, v: "0.571024", hot: false }, { dy: 0.02, v: "0.523299", hot: false },
                { dy: 0.055, v: "0.409431", hot: false }, { dy: 0.09, v: "0.337187", hot: false }
            ]
            const bx = w * 0.3
            ctx.lineWidth = 1.4 * k
            ctx.strokeStyle = "rgba(255, 158, 44, 0.20)"
            ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(bx, y0); ctx.stroke()
            ctx.font = Math.round(11 * k) + "px monospace"; ctx.textAlign = "right"; ctx.textBaseline = "bottom"
            for (const l of lines) {
                const ty = y0 + l.dy * h * 0.9
                ctx.strokeStyle = l.hot ? "rgba(255, 170, 60, 0.42)" : "rgba(255, 158, 44, 0.11)"
                ctx.lineWidth = (l.hot ? 1.8 : 1.1) * k
                ctx.beginPath(); ctx.moveTo(bx, y0)
                ctx.bezierCurveTo(bx + w * 0.12, y0, bx + w * 0.1, ty, bx + w * 0.26, ty)
                ctx.lineTo(x1, ty); ctx.stroke()
                ctx.fillStyle = l.hot ? "rgba(255, 190, 110, 0.55)" : "rgba(255, 170, 90, 0.20)"
                ctx.fillText(l.v, x1, ty - 3 * k)
            }
            ctx.fillStyle = "rgba(255, 190, 110, 0.6)"
            ctx.beginPath(); ctx.arc(bx, y0, 3.5 * k, 0, Math.PI * 2); ctx.fill()
            // timeline ticks under the past
            ctx.strokeStyle = "rgba(255, 158, 44, 0.12)"; ctx.lineWidth = 1
            for (let x = x0; x < bx; x += 18 * k) { ctx.beginPath(); ctx.moveTo(x, y0 + 4 * k); ctx.lineTo(x, y0 + (Math.round((x - x0) / (18 * k)) % 5 === 0 ? 11 : 7) * k); ctx.stroke() }
        }
    }

    // ------------------------------------------------------------ gears
    property real spin: 0
    // 150 deg x 12 (minute hand) is a whole number of turns, so the time
    // shown is right again once the gears stop
    NumberAnimation { id: spinAnim; target: scene; property: "spin"; duration: 2800; easing.type: Easing.InOutCubic }
    Connections {
        target: Worldline
        function onShiftingChanged() {
            if (!Worldline.shifting) return
            spinAnim.from = scene.spin % 3600; spinAnim.to = scene.spin % 3600 + 150; spinAnim.restart()
        }
    }

    component Gear: Canvas {
        id: gear
        property int teeth: 24
        property real ratio: 1
        property real alpha: 0.10
        property real phase: 0
        width: 300; height: width
        rotation: phase + scene.spin * ratio
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"), R = width / 2, c = R
            ctx.reset()
            const ro = R * 0.98, ri = R * 0.86, n = teeth
            ctx.beginPath()
            for (let i = 0; i < n; i++) {
                const a0 = i / n * Math.PI * 2, a1 = (i + 0.5) / n * Math.PI * 2, d = Math.PI / n * 0.3
                ctx.lineTo(c + Math.cos(a0 - d) * ri, c + Math.sin(a0 - d) * ri)
                ctx.lineTo(c + Math.cos(a0 + d) * ro, c + Math.sin(a0 + d) * ro)
                ctx.lineTo(c + Math.cos(a1 - d) * ro, c + Math.sin(a1 - d) * ro)
                ctx.lineTo(c + Math.cos(a1 + d) * ri, c + Math.sin(a1 + d) * ri)
            }
            ctx.closePath()
            ctx.fillStyle = "rgba(30, 16, 8, 0.55)"; ctx.fill()
            ctx.strokeStyle = "rgba(255, 158, 44, " + gear.alpha + ")"; ctx.lineWidth = Math.max(1, R / 120); ctx.stroke()
            // rim, spokes, hub
            ctx.beginPath(); ctx.arc(c, c, R * 0.72, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.arc(c, c, R * 0.2, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.arc(c, c, R * 0.08, 0, Math.PI * 2); ctx.stroke()
            for (let i = 0; i < 6; i++) {
                const a = i / 6 * Math.PI * 2, w = 0.11
                ctx.beginPath()
                ctx.moveTo(c + Math.cos(a - w) * R * 0.21, c + Math.sin(a - w) * R * 0.21)
                ctx.lineTo(c + Math.cos(a - w * 0.35) * R * 0.71, c + Math.sin(a - w * 0.35) * R * 0.71)
                ctx.moveTo(c + Math.cos(a + w) * R * 0.21, c + Math.sin(a + w) * R * 0.21)
                ctx.lineTo(c + Math.cos(a + w * 0.35) * R * 0.71, c + Math.sin(a + w * 0.35) * R * 0.71)
                ctx.stroke()
            }
        }
    }
    // meshing pair top-right, a lone one bottom-left, a small one top-left
    Gear { id: g1; teeth: 36; width: 620 * scene.s; x: scene.width - width * 0.62; y: -width * 0.38; alpha: 0.11 }
    Gear { teeth: 18; ratio: -2; phase: 5; width: 320 * scene.s; x: g1.x - width * 0.78; y: g1.y + g1.height * 0.62; alpha: 0.09 }
    Gear { teeth: 28; ratio: 0.8; width: 480 * scene.s; x: -width * 0.42; y: scene.height * 0.48; alpha: 0.07 }
    Gear { teeth: 14; ratio: -1.7; phase: 9; width: 200 * scene.s; x: width * 0.15; y: scene.height * 0.12; alpha: 0.06 }

    // ------------------------------------------------------------ clock hands on the dial
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Item {
        id: dial
        x: scene.width / 2; y: scene.height * 0.42
        readonly property real rad: Math.min(scene.width, scene.height) * 0.36
        // hands only show their outer half, so they never cross the meter
        component Hand: Rectangle {
            property real len: 0.8
            property color tint: "#ff9e2c"
            width: 2 * scene.s; height: dial.rad * len; radius: width / 2
            x: -width / 2; y: -height
            transformOrigin: Item.Bottom
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(tint.r, tint.g, tint.b, 0.30) }
                GradientStop { position: 0.35; color: Qt.rgba(tint.r, tint.g, tint.b, 0.14) }
                GradientStop { position: 0.6; color: "transparent" }
            }
        }
        Hand { len: 0.66; width: 4 * scene.s; rotation: (clock.date.getHours() % 12 + clock.date.getMinutes() / 60) * 30 }
        Hand { len: 0.9; rotation: clock.date.getMinutes() * 6 + scene.spin * 12 }
    }

    // ------------------------------------------------------------ the meter
    Column {
        visible: scene.showMeter
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height * 0.42 - meter.height * 0.62
        spacing: 18 * scene.s

        NixieMeter {
            id: meter
            anchors.horizontalCenter: parent.horizontalCenter
            text: Worldline.display
            tubeWidth: 74 * scene.s
            glowStrength: Worldline.shifting ? 0.7 + (Worldline.display.charCodeAt(7) % 6) / 10 : 1.0   // flicker while rolling
            // the meter shakes a little while the world line is moving
            transform: Translate { id: jitter }
            MouseArea {
                anchors.fill: parent
                enabled: scene.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: Worldline.shift()
            }
        }
        Timer {
            interval: 50; repeat: true; running: Worldline.shifting
            onTriggered: { jitter.x = (Math.random() - 0.5) * 3 * scene.s; jitter.y = (Math.random() - 0.5) * 2 * scene.s }
            onRunningChanged: if (!running) { jitter.x = 0; jitter.y = 0 }
        }

        Text {
            visible: scene.showText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "WORLDLINE  DIVERGENCE"
            color: "#a88760"; font.family: Theme.font; font.pixelSize: 13 * scene.s; font.letterSpacing: 7 * scene.s
        }
        Text {
            visible: scene.showText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Worldline.shifting ? "— SHIFTING —" : (Worldline.value === "1.048596" ? "STEINS GATE" : Worldline.field + "   ·   " + Worldline.worldName)
            color: Worldline.value === "1.048596" ? "#ffb35c" : "#d07a3a"
            font.family: Theme.font; font.pixelSize: 15 * scene.s; font.letterSpacing: 3 * scene.s
        }
    }

    // ------------------------------------------------------------ captions
    Column {
        visible: scene.showText
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.leftMargin: 40 * scene.s; anchors.bottomMargin: 30 * scene.s
        spacing: 2
        Text { text: "未来ガジェット研究所"; color: "#8c6a48"; font.pixelSize: 18 * scene.s; font.letterSpacing: 4 * scene.s }
        Text { text: "FUTURE GADGET LABORATORY  ·  LAB MEM 001"; color: "#5e4630"; font.family: Theme.font; font.pixelSize: 11 * scene.s; font.letterSpacing: 2 * scene.s }
    }
    Text {
        visible: scene.showText
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.rightMargin: 40 * scene.s; anchors.bottomMargin: 30 * scene.s
        text: "El Psy Kongroo."
        color: "#8c6a48"; font.family: Theme.font; font.italic: true; font.pixelSize: 16 * scene.s; font.letterSpacing: 2 * scene.s
    }

    // ------------------------------------------------------------ CRT scanlines + vignette
    Canvas {
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"), w = width, h = height
            ctx.reset()
            ctx.fillStyle = "rgba(0, 0, 0, 0.16)"
            for (let y = 0; y < h; y += 3) ctx.fillRect(0, y, w, 1)
            const g = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.35, w / 2, h / 2, Math.max(w, h) * 0.75)
            g.addColorStop(0, "rgba(0,0,0,0)"); g.addColorStop(1, "rgba(0,0,0,0.6)")
            ctx.fillStyle = g; ctx.fillRect(0, 0, w, h)
        }
    }

    // amber flash when the world line settles
    Rectangle {
        id: flash
        anchors.fill: parent
        color: "#ff9e2c"
        opacity: 0
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flash; property: "opacity"; to: 0.10; duration: 70 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 650; easing.type: Easing.OutCubic }
        }
        Connections { target: Worldline; function onShifted() { if (!Theme.reducedMotion) flashAnim.restart() } }
    }
}
