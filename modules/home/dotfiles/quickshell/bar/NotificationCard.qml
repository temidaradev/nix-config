import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs

Rectangle {
    id: card
    property Notification n
    property bool compact: false
    signal clicked
    signal closed

    readonly property bool critical: n && n.urgency === NotificationUrgency.Critical
    implicitHeight: body.implicitHeight + 20
    radius: 6
    color: Theme.panelBg
    border.color: critical ? Theme.red : Theme.cardBorder; border.width: 1

    MouseArea { anchors.fill: parent; onClicked: card.clicked() }

    Row {
        id: body
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 10
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
                    width: parent.width - appName.width - 6
                    elide: Text.ElideRight
                    text: card.n ? card.n.summary : ""
                    color: Theme.fg; font.bold: true
                    font.family: Theme.font; font.pointSize: Theme.fontSize
                }
                Text {
                    id: appName
                    text: card.n ? card.n.appName : ""
                    color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 2
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
                    Rectangle {
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
