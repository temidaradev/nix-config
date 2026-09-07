import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs
import qs.services

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.panelBg
    WlrLayershell.namespace: "qs-bar"

    SystemClock { id: clock; precision: SystemClock.Seconds }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [bar.sink] }
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    component Sep: Rectangle {
        width: 1; height: 16
        anchors.verticalCenter: parent.verticalCenter
        color: "#33ffffff"
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        // ---------------- left ----------------
        Row {
            anchors.left: parent.left
            height: parent.height
            spacing: 4

            BarButton {   // app drawer
                padding: 6
                color: Launcher.open ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 20
                    source: Quickshell.iconPath("nix-snowflake", "start-here")
                }
                onClicked: Launcher.toggle()
            }

            Workspaces { screenName: bar.screen.name }

            Sep {}

            Rectangle {   // crypto ticker
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height - 10
                width: tick.implicitWidth + 12
                radius: Theme.radius
                color: "#1a3daee9"
                Row {
                    id: tick
                    anchors.centerIn: parent
                    spacing: 6
                    BarText { text: "◎"; color: Theme.accent; font.bold: true }
                    BarText { text: Crypto.pair.replace("-", "/") + ": "; font.bold: true }
                    BarText { text: Crypto.price; font.bold: true }
                }
            }
        }

        // ---------------- right ----------------
        Row {
            anchors.right: parent.right
            height: parent.height
            spacing: 2

            Tray { bar: bar }

            Sep {}

            BarButton {   // keyboard layout
                BarText { text: Niri.layout || "us"; font.bold: true }
                onClicked: Niri.nextLayout()
            }

            BarButton {   // volume
                BarText { text: bar.muted ? "󰖁" : (bar.volume < 0.01 ? "󰕿" : bar.volume < 0.5 ? "󰖀" : "󰕾"); font.pointSize: 12 }
                onClicked: e => {
                    if (e.button === Qt.LeftButton) Launcher.toggleControl()
                    else if (bar.sink?.audio) bar.sink.audio.muted = !bar.sink.audio.muted
                }
                onWheel: e => {
                    if (!bar.sink?.audio) return
                    const v = bar.sink.audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)
                    bar.sink.audio.volume = Math.max(0, Math.min(1, v))
                }
            }

            BarButton {   // bluetooth
                BarText { text: "󰂯"; font.pointSize: 12 }
                onClicked: e => e.button === Qt.RightButton ? Quickshell.execDetached(["blueman-manager"]) : Launcher.toggleControl()
            }

            BarButton {   // cpu
                BarText { text: "󰻠"; color: Theme.accent; font.pointSize: 12 }
                BarText { text: Math.round(SysStats.cpu) + "%" }
                onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
            }

            BarButton {   // memory
                BarText { text: "󰍛"; color: Theme.accent; font.pointSize: 12 }
                BarText { text: Math.round(SysStats.memUsed / SysStats.memTotal * 100 || 0) + "%" }
                onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
            }

            BarButton {   // network speed
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -2
                    Row { spacing: 3
                        BarText { text: "󰁅"; color: Theme.accent; font.pointSize: 7 }
                        BarText { text: SysStats.fmtRate(SysStats.rx); font.pointSize: 7 } }
                    Row { spacing: 3
                        BarText { text: "󰁝"; color: Theme.accent; font.pointSize: 7 }
                        BarText { text: SysStats.fmtRate(SysStats.tx); font.pointSize: 7 } }
                }
            }

            BarButton {   // now playing
                id: nowPlaying
                visible: Media.player !== null
                color: Launcher.mediaOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 2; color: Theme.bg3
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true; mipmap: true; sourceSize: Qt.size(36, 36)
                    }
                }
                BarText {
                    text: Media.title + (Media.artist ? " (" + Media.artist + ")" : "")
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 180)
                }
                onClicked: e => {
                    if (!Media.player) return
                    if (e.button === Qt.LeftButton) Launcher.toggleMedia(nowPlaying.mapToItem(null, 0, 0).x + nowPlaying.width / 2)
                    else if (e.button === Qt.MiddleButton) Media.player.togglePlaying()
                    else Media.player.next()
                }
            }

            BarButton {   // notifications
                BarText { text: Notifs.dnd ? "󰂛" : (Notifs.count > 0 ? "󰂚" : "󰂜"); font.pointSize: 12 }
                BarText { visible: Notifs.count > 0; text: String(Notifs.count); color: Theme.accent; font.bold: true; font.pointSize: Theme.smallSize }
                onClicked: e => e.button === Qt.RightButton ? Notifs.dnd = !Notifs.dnd : Launcher.toggleControl()
            }

            BarButton {   // control center
                color: Launcher.controlOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                BarText { text: "󰒓"; font.pointSize: 12 }
                onClicked: Launcher.toggleControl()
            }

            BarButton {   // clock -> calendar
                color: Launcher.calendarOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -3
                    BarText { text: Qt.formatDateTime(clock.date, "HH:mm"); font.bold: true; anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter }
                    BarText { text: Qt.formatDateTime(clock.date, "d.MM.yyyy"); font.pointSize: 7; color: Theme.fgDim; anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter }
                }
                onClicked: Launcher.toggleCalendar()
            }
        }
    }
}
