import QtQuick
import QtQuick.Shapes
import qs

// Plasma-style ring gauge, arc grows counter-clockwise from 6 o'clock.
Item {
    id: g
    property real value: 0          // 0..100
    property string label: ""
    property string center: value.toFixed(0) + "%"
    property color color: Theme.accent
    property real size: 96
    width: size; height: size + (label !== "" ? 18 : 0)

    Shape {
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
                sweepAngle: -Math.max(0, Math.min(100, g.value)) * 3.6
                Behavior on sweepAngle { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        Text { anchors.centerIn: parent; text: g.center; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize }
    }
    Text {
        visible: g.label !== ""
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        text: g.label; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
    }
}
