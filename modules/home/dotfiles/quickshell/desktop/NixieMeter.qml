import QtQuick
import qs

// A row of nixie tubes on a dark chassis (the divergence meter, or a clock).
Item {
    id: meter
    property string text: "1.048596"
    property real tubeWidth: 64
    property real gap: tubeWidth * 0.14
    property bool chassis: true
    property real glowStrength: 1.0
    implicitWidth: tubes.width + (chassis ? tubeWidth * 0.7 : 0)
    implicitHeight: tubes.height + (chassis ? tubeWidth * 0.55 : 0)
    width: implicitWidth; height: implicitHeight

    Rectangle {     // chassis plate
        visible: meter.chassis
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: meter.tubeWidth * 0.62
        radius: meter.tubeWidth * 0.08
        gradient: Gradient {
            GradientStop { position: 0; color: "#2e231a" }
            GradientStop { position: 0.08; color: "#1c1510" }
            GradientStop { position: 1; color: "#0a0806" }
        }
        border.width: 1; border.color: "#3d2f22"
        Repeater {     // rivets
            model: 2
            Rectangle {
                required property int index
                width: meter.tubeWidth * 0.09; height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: index === 0 ? meter.tubeWidth * 0.14 : parent.width - meter.tubeWidth * 0.14 - width
                gradient: Gradient { GradientStop { position: 0; color: "#8a7560" } GradientStop { position: 1; color: "#2a2018" } }
            }
        }
    }

    Row {
        id: tubes
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: meter.chassis ? meter.tubeWidth * 0.3 : 0
        spacing: meter.gap
        Repeater {
            model: meter.text.length
            Nixie {
                required property int index
                ch: meter.text[index]
                tubeWidth: meter.tubeWidth
                glowStrength: meter.glowStrength
            }
        }
    }
}
