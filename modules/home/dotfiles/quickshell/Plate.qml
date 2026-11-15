import QtQuick
import qs

// Background surface that follows the theme's shape language: a rounded
// rectangle normally, a chamfered HUD plate in Steins;Gate. Use it where a
// Rectangle would be the background: `fill` / `stroke` / `strokeWidth`
// replace color / border.color / border.width. Children draw on top.
Item {
    id: p
    property color color: "transparent"   // alias, so Rectangle sites convert by name only
    property color fill: color
    property color stroke: "transparent"
    property real strokeWidth: 0
    property real radius: Theme.radius
    property real cut: Theme.cut
    property bool brackets: false        // Steins;Gate: accent L-brackets on the uncut corners
    property bool tl: true
    property bool tr: false
    property bool br: true
    property bool bl: false

    Rectangle {
        anchors.fill: parent
        visible: !Theme.steins
        color: p.fill
        radius: p.radius
        border.color: p.stroke
        border.width: p.strokeWidth
    }

    Chamfer {
        anchors.fill: parent
        visible: Theme.steins
        fill: p.fill
        stroke: p.stroke
        strokeWidth: Math.max(1, p.strokeWidth)
        cut: p.cut
        tl: p.tl; tr: p.tr; br: p.br; bl: p.bl
    }

    Loader {
        anchors.fill: parent
        active: Theme.steins && p.brackets
        sourceComponent: Item {
            readonly property real len: Math.min(14, p.width / 4, p.height / 4)
            component Tick: Rectangle { color: Theme.accent }
            // top-right
            Tick { x: parent.width - parent.len; y: -3; width: parent.len + 3; height: 2 }
            Tick { x: parent.width + 1; y: -3; width: 2; height: parent.len + 3 }
            // bottom-left
            Tick { x: -3; y: parent.height + 1; width: parent.len + 3; height: 2 }
            Tick { x: -3; y: parent.height - parent.len; width: 2; height: parent.len + 3 }
        }
    }
}
