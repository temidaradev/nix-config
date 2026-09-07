import QtQuick
import qs
import qs.services

// Grid of images from ~/Pictures/Wallpapers plus the built-in one.
BarPopup {
    id: pick
    visible: Launcher.wallpaperOpen
    panelWidth: 560
    onDismissed: Launcher.wallpaperOpen = false
    onVisibleChanged: if (visible) Wallpaper.rescan()

    Row {
        width: parent.width
        Text { text: "Wallpaper"; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize; width: parent.width - 200; anchors.verticalCenter: parent.verticalCenter }
        Text { text: Wallpaper.dir.replace(/^\/home\/[^/]+/, "~"); color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; width: 200; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; anchors.verticalCenter: parent.verticalCenter }
    }

    Grid {
        columns: 3; spacing: 8; width: parent.width
        Repeater {
            model: Wallpaper.available
            Rectangle {
                required property string modelData
                readonly property bool active: modelData === Wallpaper.current
                width: (parent.width - 16) / 3; height: width * 9 / 16
                radius: Theme.radius
                color: Theme.bg2
                border.color: active ? Theme.accent : (ma.containsMouse ? "#66ffffff" : "transparent"); border.width: 2
                clip: true
                Image {
                    anchors.fill: parent; anchors.margins: 2
                    source: "file://" + modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; smooth: true; mipmap: true
                    sourceSize: Qt.size(360, 202)
                }
                Text {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 6
                    text: modelData.split("/").pop()
                    elide: Text.ElideMiddle
                    color: Theme.fg; style: Text.Outline; styleColor: "#aa000000"
                    font.family: Theme.font; font.pointSize: Theme.smallSize - 2
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: Wallpaper.set(modelData) }
            }
        }
    }

    Text {
        visible: Wallpaper.available.length <= 1
        width: parent.width; wrapMode: Text.Wrap
        text: "Drop images into " + Wallpaper.dir.replace(/^\/home\/[^/]+/, "~") + " and reopen this panel."
        color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
    }
}
