import org.kde.ksvg 1.0 as KSvg
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.plasma.plasmoid 2.0

Item {
    id: backgroundSidebar

    property string sidebarListActive: "All Music"
    signal favClicked()
    signal changeCurrentList()



    P5Support.DataSource {
        id: runCommand
        engine: "executable"
        connectedSources: []

        onNewData: function (source, data) {
            var exitCode = data["exit code"]
            var exitStatus = data["exit status"]
            var stdout = data["stdout"]
            var stderr = data["stderr"]
            exited(source, exitCode, exitStatus, stdout, stderr)
            disconnectSource(source) // cmd finished
        }

        function exec(cmd) {
            runCommand.connectSource(cmd)
        }

        signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)
    }

    KSvg.FrameSvgItem {
        imagePath: "dialogs/background"
        clip: true
        width: parent.width
        height: parent.height
    }

    onSidebarListActiveChanged: changeCurrentList()

    Column {
        width: parent.width - 6
        height: 60
        spacing: 16
        anchors.top: parent.top
        anchors.topMargin: 20
        Rectangle {
            color: sidebarListActive === "All Music" ? Kirigami.Theme.highlightColor : "transparent"
            width: parent.width - 12
            height: 24
            radius: height/2
            anchors.left: parent.left
            anchors.leftMargin: 6
            Row {
                width: parent.width - 8
                height: 22
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                Kirigami.Icon {
                    id: iconList
                    source: "view-media-playlist"
                    width: 22
                    height: 22
                    color: sidebarListActive === "All Music" ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: allMusic
                    width: parent.width - iconList.width - parent.spacing
                    height: iconList.height
                    text: "All Music"
                    verticalAlignment: Text.AlignVCenter
                    color: sidebarListActive === "All Music" ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 12
                }

            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    sidebarListActive = "All Music"
                    //favGenModel()
                }
            }
        }

        Rectangle {
            color: sidebarListActive === "Favorites" ? Kirigami.Theme.highlightColor : "transparent"
            width: parent.width - 12
            height: 24
            radius: height/2
            anchors.left: parent.left
            anchors.leftMargin: 6
            Row {
                width: parent.width - 8
                height: 22
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                Kirigami.Icon {
                    id: iconFav
                    source: "love"
                    width: 22
                    height: 22
                    color: sidebarListActive === "Favorites" ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: favoritesTracks
                    width: parent.width - iconList.width - parent.spacing
                    height: iconFav.height
                    text: "Favorites"
                    verticalAlignment: Text.AlignVCenter
                    color: sidebarListActive === "Favorites" ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 12
                }

            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    sidebarListActive = "Favorites"
                    favClicked()
                }
            }
        }


    }

    Text {
        id: version
        text: "ALfA " + Plasmoid.metaData.version
        color: Kirigami.Theme.textColor
        font.pixelSize: 11
        anchors.bottom: donate.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 16
    }
    Text {
        id: donate
        text: "Donate"
        color: Kirigami.Theme.textColor
        font.pixelSize: 11
        font.bold: true
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        MouseArea {
            anchors.fill: parent
            onClicked: {
                executable.exec("xdg-open 'https://www.paypal.com/paypalme/zayronxio'");
            }
        }
    }



}
