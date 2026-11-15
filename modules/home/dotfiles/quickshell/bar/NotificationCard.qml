import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

Plate {
    id: card
    property Notification n
    property bool compact: false
    signal clicked
    signal closed

    readonly property bool critical: n && n.urgency === NotificationUrgency.Critical
    implicitHeight: body.implicitHeight + 20 + (Theme.steins ? header.height : 0)
    readonly property date arrived: (n && Notifs.arrived[n.id]) || new Date()
    radius: Theme.r(6)
    color: Theme.panelBg
    stroke: critical ? Theme.red : Theme.cardBorder; strokeWidth: 1

    MouseArea { anchors.fill: parent; onClicked: card.clicked() }

    // Steins;Gate: incoming D-mail. Header with sender and arrival time,
    // an amber signal bar down the left edge (red when critical).
    Rectangle {
        visible: Theme.steins
        x: 0; y: Theme.cut; width: 3; height: parent.height - 2 * Theme.cut
        color: card.critical ? Theme.red : Theme.accent
    }
    Item {
        id: header
        visible: Theme.steins
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 14; anchors.rightMargin: 12
        height: Theme.steins ? 26 : 0
        Text {
            anchors.left: parent.left; anchors.right: stamp.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: "✉  D-MAIL  ·  FROM " + ((card.n && card.n.appName) ? card.n.appName : "UNKNOWN").toUpperCase()
            color: card.critical ? Theme.red : Theme.cyan
            font.family: Theme.font; font.pointSize: Theme.smallSize - 2; font.letterSpacing: 1.2
        }
        Text {
            id: stamp
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(card.arrived, "HH:mm")
            color: Theme.accent
            font.family: Theme.font; font.pointSize: Theme.smallSize - 1; font.bold: true
        }
        Rectangle {   // divider
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.62, 0.17, 0.45) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    Row {
        id: body
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: Theme.steins ? header.bottom : parent.top
        anchors.margins: 10; anchors.leftMargin: Theme.steins ? 14 : 10
        spacing: 10

        Item {
            width: 36; height: 36
            IconImage {
                anchors.fill: parent
                source: card.n ? (card.n.image !== "" ? card.n.image : Quickshell.iconPath(card.n.appIcon, "dialog-information")) : ""
                asynchronous: true
            }
        }

        Column {
            width: parent.width - 36 - 10 - 24
            spacing: 2
            Row {
                width: parent.width; spacing: 6
                Text {
                    width: parent.width - (appName.visible ? appName.width + 6 : 0)
                    elide: Text.ElideRight
                    text: card.n ? card.n.summary : ""
                    color: Theme.fg; font.bold: true
                    font.family: Theme.font; font.pointSize: Theme.fontSize
                }
                Text {
                    id: appName
                    visible: !Theme.steins   // the D-mail header names the sender
                    text: card.n ? card.n.appName : ""
                    color: Theme.ink(0x66); font.family: Theme.font; font.pointSize: Theme.smallSize - 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: card.n ? card.n.body : ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.compact ? 2 : 6
                elide: Text.ElideRight
                color: Theme.fgDim
                font.family: Theme.font; font.pointSize: Theme.smallSize
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Row {
                visible: !card.compact && card.n && card.n.actions.length > 0
                spacing: 6; topPadding: 4
                Repeater {
                    model: card.n ? card.n.actions : []
                    Plate {
                        required property var modelData
                        width: at.implicitWidth + 16; height: 22
                        radius: Theme.radius; color: Theme.bg2
                        Text { id: at; anchors.centerIn: parent; text: modelData.text; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                        MouseArea { anchors.fill: parent; onClicked: { modelData.invoke(); card.closed() } }
                    }
                }
            }
        }

        BarButton {
            padding: 4; implicitHeight: 22
            BarText { text: "󰅖"; color: Theme.fgDim; font.pointSize: Theme.smallSize }
            onClicked: card.closed()
        }
    }
}
