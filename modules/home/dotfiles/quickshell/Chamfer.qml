import QtQuick
import QtQuick.Shapes

// A plate with 45-degree cut corners (Steins;Gate HUD shape). By default the
// top-left and bottom-right corners are cut, which reads as a slanted tab.
Shape {
    id: c
    property color fill: "transparent"
    property color stroke: "transparent"
    property real strokeWidth: 1
    property real cut: 8
    property bool tl: true
    property bool tr: false
    property bool br: true
    property bool bl: false

    preferredRendererType: Shape.CurveRenderer
    readonly property bool stroked: stroke.a > 0 && strokeWidth > 0
    readonly property real h: stroked ? strokeWidth / 2 : 0          // keep the stroke inside the item
    readonly property real k: Math.max(0, Math.min(cut, (width - 2 * h) / 2, (height - 2 * h) / 2))
    readonly property real x0: h
    readonly property real y0: h
    readonly property real x1: width - h
    readonly property real y1: height - h

    ShapePath {
        fillColor: c.fill
        strokeColor: c.stroked ? c.stroke : "transparent"
        strokeWidth: c.stroked ? c.strokeWidth : 0
        joinStyle: ShapePath.MiterJoin
        startX: c.x0 + (c.tl ? c.k : 0); startY: c.y0
        PathLine { x: c.x1 - (c.tr ? c.k : 0); y: c.y0 }
        PathLine { x: c.x1; y: c.y0 + (c.tr ? c.k : 0) }
        PathLine { x: c.x1; y: c.y1 - (c.br ? c.k : 0) }
        PathLine { x: c.x1 - (c.br ? c.k : 0); y: c.y1 }
        PathLine { x: c.x0 + (c.bl ? c.k : 0); y: c.y1 }
        PathLine { x: c.x0; y: c.y1 - (c.bl ? c.k : 0) }
        PathLine { x: c.x0; y: c.y0 + (c.tl ? c.k : 0) }
        PathLine { x: c.x0 + (c.tl ? c.k : 0); y: c.y0 }
    }
}
