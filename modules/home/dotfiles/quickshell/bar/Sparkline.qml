import QtQuick
import qs

// Tiny area chart of the last N samples (0..100).
Canvas {
    id: c
    property var data: []
    property color color: Theme.accent
    property real max: 100
    width: 46; height: 16
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    onDataChanged: requestPaint()
    onColorChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const n = data.length
        if (n < 2) return
        const step = width / 59
        const x0 = width - (n - 1) * step
        ctx.beginPath()
        ctx.moveTo(x0, height)
        for (let i = 0; i < n; i++) ctx.lineTo(x0 + i * step, height - Math.min(1, data[i] / max) * (height - 1) - 0.5)
        ctx.lineTo(width, height)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.3)
        ctx.fill()
        ctx.beginPath()
        for (let i = 0; i < n; i++) {
            const x = x0 + i * step, y = height - Math.min(1, data[i] / max) * (height - 1) - 0.5
            i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
        }
        ctx.strokeStyle = color
        ctx.lineWidth = 1.2
        ctx.stroke()
    }
}
