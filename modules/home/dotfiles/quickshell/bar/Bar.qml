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
        }

        // ---------------- centre: clock + now playing, one button -> dashboard ----------------
        BarButton {
            id: nowPlaying
            anchors.horizontalCenter: parent.horizontalCenter
            padding: 10
            color: Launcher.dashOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
            onClicked: e => {
                if (e.button === Qt.LeftButton) Launcher.toggleDash(nowPlaying.mapToItem(null, 0, 0).x + nowPlaying.width / 2)
                else if (Media.player && e.button === Qt.MiddleButton) Media.player.togglePlaying()
                else if (Media.player) Media.player.next()
            }

                BarText { text: Qt.formatDateTime(clock.date, "ddd d MMM"); color: Theme.fgDim }
                BarText { text: Qt.formatDateTime(clock.date, "HH:mm"); font.bold: true }
                Sep { visible: Media.player !== null }
                readonly property real progress: Media.player && Media.player.length > 0 ? Math.min(1, Media.player.position / Media.player.length) : 0

                Rectangle {
                    visible: Media.player !== null
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; radius: 3; color: Theme.bg3
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true; mipmap: true; sourceSize: Qt.size(44, 44)
                    }
                    Text { visible: Media.artUrl === ""; anchors.centerIn: parent; text: "󰝚"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: 10 }
                }
                Item {   // marquee
                    id: marquee
                    visible: Media.player !== null
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property string full: Media.title + (Media.artist ? "  ·  " + Media.artist : "")
                    readonly property bool overflow: label.implicitWidth > 220
                    width: Math.min(label.implicitWidth, 220)
                    height: label.implicitHeight
                    clip: true
                    BarText {
                        id: label
                        anchors.verticalCenter: undefined
                        text: marquee.full
                        SequentialAnimation on x {
                            id: scroll
                            running: marquee.overflow && !nowPlaying.hovered
                            loops: Animation.Infinite
                            PauseAnimation { duration: 2000 }
                            NumberAnimation { from: 0; to: marquee.width - label.implicitWidth - 12; duration: Math.max(1000, (label.implicitWidth - marquee.width) * 25); easing.type: Easing.Linear }
                            PauseAnimation { duration: 1200 }
                            NumberAnimation { to: 0; duration: 400; easing.type: Easing.InOutQuad }
                            onRunningChanged: if (!running) label.x = 0
                        }
                    }
                }
                Rectangle {   // progress line
                    parent: nowPlaying
                    visible: Media.player !== null
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                    anchors.left: parent.left; anchors.leftMargin: 8
                    width: (parent.width - 16) * nowPlaying.progress
                    height: 2; radius: 1; color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
                }
                Rectangle {
                    parent: nowPlaying
                    visible: Media.player !== null
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                    anchors.left: parent.left; anchors.leftMargin: 8
                    width: parent.width - 16; height: 2; radius: 1; color: "#22ffffff"; z: -1
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

            BarButton {   // peripheral batteries (only when something reports one)
                visible: Devices.all.length > 0
                Repeater {
                    model: Devices.all
                    Row {
                        required property var modelData
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                        BarText { text: modelData.glyph; color: modelData.pct < 20 ? Theme.red : Theme.fg; font.pointSize: 11 }
                        BarText { text: modelData.pct + "%"; font.pointSize: Theme.smallSize }
                    }
                }
                onClicked: Launcher.toggleDash(nowPlaying.mapToItem(null, 0, 0).x + nowPlaying.width / 2)
            }

            Sep {}

            BarButton {   // cpu sparkline
                BarText { text: "󰻠"; color: Theme.accent; font.pointSize: 12 }
                Sparkline { data: SysStats.cpuHist }
                BarText { text: Math.round(SysStats.cpu) + "%"; font.pointSize: Theme.smallSize; width: 30; horizontalAlignment: Text.AlignRight }
                onClicked: Launcher.toggleDash(nowPlaying.mapToItem(null, 0, 0).x + nowPlaying.width / 2)
            }

            BarButton {   // memory sparkline
                BarText { text: "󰍛"; color: Theme.green; font.pointSize: 12 }
                Sparkline { data: SysStats.memHist; color: Theme.green }
                BarText { text: Math.round(SysStats.memUsed / SysStats.memTotal * 100 || 0) + "%"; font.pointSize: Theme.smallSize; width: 30; horizontalAlignment: Text.AlignRight }
                onClicked: Launcher.toggleDash(nowPlaying.mapToItem(null, 0, 0).x + nowPlaying.width / 2)
            }

            BarButton {   // temperatures
                id: tempBtn
                color: Launcher.tempOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                BarText { text: "󰔏"; color: SysStats.temp > 80 ? Theme.red : Theme.accent; font.pointSize: 12 }
                BarText { text: Math.round(SysStats.temp) + "°"; font.pointSize: Theme.smallSize }
                BarText { visible: SysStats.gpuTemp > 0; text: "󰢮"; color: SysStats.gpuTemp > 85 ? Theme.red : Theme.accent; font.pointSize: 12 }
                BarText { visible: SysStats.gpuTemp > 0; text: Math.round(SysStats.gpuTemp) + "°"; font.pointSize: Theme.smallSize }
                onClicked: Launcher.toggleTemps(tempBtn.mapToItem(null, 0, 0).x + tempBtn.width / 2)
            }

            BarButton {   // disk usage of /
                id: diskBtn
                readonly property var rootDisk: SysStats.disks.find(d => d.mount === "/")
                color: Launcher.diskOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                BarText { text: "󰋊"; color: Theme.accent; font.pointSize: 12 }
                BarText { text: diskBtn.rootDisk ? diskBtn.rootDisk.pct + "%" : "–"; font.pointSize: Theme.smallSize }
                onClicked: Launcher.toggleDisks(diskBtn.mapToItem(null, 0, 0).x + diskBtn.width / 2)
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
                onClicked: Launcher.toggleControl()
            }

            Sep {}

            BarButton {   // notifications
                id: bellBtn
                color: Launcher.notifOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                BarText { text: Notifs.dnd ? "󰂛" : (Notifs.count > 0 ? "󰂚" : "󰂜"); font.pointSize: 12 }
                BarText { visible: Notifs.count > 0; text: String(Notifs.count); color: Theme.accent; font.bold: true; font.pointSize: Theme.smallSize }
                onClicked: e => e.button === Qt.RightButton ? Notifs.dnd = !Notifs.dnd : Launcher.toggleNotifs(bellBtn.mapToItem(null, 0, 0).x + bellBtn.width / 2)
            }

            BarButton {   // control center
                color: Launcher.controlOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                BarText { text: "󰒓"; font.pointSize: 12 }
                onClicked: Launcher.toggleControl()
            }

            BarButton {   // sidebar
                color: Launcher.sidebarOpen ? "#40ffffff" : (hovered ? "#2affffff" : "transparent")
                BarText { text: "󰨝"; font.pointSize: 12 }
                onClicked: Launcher.toggleSidebar()
            }
        }
    }
}
