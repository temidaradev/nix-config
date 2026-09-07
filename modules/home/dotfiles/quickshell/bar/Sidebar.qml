                            Item {
                                width: parent.width; height: 22
                                Row {
                                    spacing: 6; height: parent.height
                                    Rectangle { width: 18; height: 18; radius: 3; color: modelData.is_active ? Theme.accent : Theme.bg3; anchors.verticalCenter: parent.verticalCenter
                                        Text { anchors.centerIn: parent; text: modelData.name || modelData.idx; color: modelData.is_active ? "#1b1e20" : Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 } }
                                    Text { text: "Workspace " + (modelData.name || modelData.idx); color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { anchors.fill: parent; onClicked: Niri.focusWorkspace(modelData.idx) }
                            }import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services

// Right-edge panel: quick launch, windows per workspace, clipboard, timer, media.
PanelWindow {
    id: win
    visible: Launcher.sidebarOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-sidebar"
    onVisibleChanged: if (visible) Clipboard.refresh()
    Timer { interval: 4000; repeat: true; running: win.visible; onTriggered: Clipboard.refresh() }

    property var pinned: ["org.kde.dolphin", "zen-beta", "code", "dev.zed.Zed", "discord", "moe.kopuz.kopuz", "com.mitchellh.ghostty", "steam", "thunderbird", "org.jellyfin.JellyfinDesktop"]
    readonly property var apps: DesktopEntries.applications.values
    function entry(id) { const l = id.toLowerCase(); return apps.find(e => e.id.toLowerCase() === l) || apps.find(e => e.id.toLowerCase().endsWith("." + l) || l.endsWith("." + e.id.toLowerCase())) || null }
    readonly property var launchers: pinned.map(id => entry(id)).filter(e => e !== null)

    MouseArea { anchors.fill: parent; onClicked: Launcher.sidebarOpen = false }

    Rectangle {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.topMargin: Theme.barHeight
        width: 380
        color: Theme.panelBg
        border.color: Theme.cardBorder; border.width: 1
        MouseArea { anchors.fill: parent }

        Flickable {
            anchors.fill: parent; anchors.margins: 14
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 10

                component Section: Row {
                    property string title
                    property alias extra: extraSlot.data
                    width: parent.width
                    Text { text: title; width: parent.width - extraSlot.width; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; font.capitalization: Font.AllUppercase; topPadding: 8; anchors.verticalCenter: parent.verticalCenter }
                    Row { id: extraSlot; spacing: 4; anchors.verticalCenter: parent.verticalCenter }
                }
                component Card: Rectangle {
                    width: parent.width
                    radius: Theme.radius; color: Theme.bg2
                    default property alias content: inner.data
                    implicitHeight: inner.implicitHeight + 20
                    Column { id: inner; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; spacing: 6 }
                }
                component SmallButton: BarButton {
                    property string label
                    padding: 8; implicitHeight: 24
                    color: hovered ? "#2affffff" : Theme.bg3
                    BarText { text: label; font.pointSize: Theme.smallSize - 1 }
                }

                // ---- quick launch ----
                Section { title: "Quick launch" }
                Card {
                    Grid {
                        columns: 5; width: parent.width; rowSpacing: 6; columnSpacing: 6
                        Repeater {
                            model: win.launchers
                            Rectangle {
                                required property var modelData
                                width: (parent.width - 24) / 5; height: 58
                                radius: Theme.radius
                                color: ma.containsMouse ? "#2affffff" : "transparent"
                                Column {
                                    anchors.centerIn: parent; spacing: 4
                                    IconImage { anchors.horizontalCenter: parent.horizontalCenter; implicitSize: 28; asynchronous: true; source: Quickshell.iconPath(modelData.icon, "application-x-executable") }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; width: 58; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; text: modelData.name; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 3 }
                                }
                                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: { modelData.execute(); Launcher.sidebarOpen = false } }
                            }
                        }
                    }
                }

                // ---- windows per workspace ----
                Section { title: "Windows" }
                Card {
                    Repeater {
                        model: Niri.workspaces
                        Column {
                            required property var modelData
                            readonly property var wins: Niri.windows.filter(w => w.workspace_id === modelData.id)
                            visible: wins.length > 0
                            width: parent.width; spacing: 2
                            Row {
                                spacing: 6
                                Rectangle { width: 18; height: 18; radius: 3; color: modelData.is_active ? Theme.accent : Theme.bg3; anchors.verticalCenter: parent.verticalCenter
                                    Text { anchors.centerIn: parent; text: modelData.name || modelData.idx; color: modelData.is_active ? "#1b1e20" : Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 } }
                                Text { text: "Workspace " + (modelData.name || modelData.idx); color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; anchors.verticalCenter: parent.verticalCenter }
                                MouseArea { anchors.fill: parent; onClicked: Niri.focusWorkspace(modelData.idx) }
                            }
                            Repeater {
                                model: parent.wins
                                Rectangle {
                                    required property var modelData
                                    readonly property var e: win.entry(modelData.app_id || "")
                                    width: parent.width; height: 28
                                    radius: Theme.radius
                                    color: modelData.id === Niri.focusedWindow ? "#303daee9" : (wm.containsMouse ? "#2affffff" : "transparent")
                                    Row {
                                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4; spacing: 8
                                        IconImage { anchors.verticalCenter: parent.verticalCenter; implicitSize: 16; asynchronous: true; source: Quickshell.iconPath(e ? e.icon : (modelData.app_id || ""), "application-x-executable") }
                                        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24 - 28; elide: Text.ElideRight; text: modelData.title || modelData.app_id; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize }
                                        BarButton { padding: 4; implicitHeight: 20; anchors.verticalCenter: parent.verticalCenter; onClicked: Niri.closeWindow(modelData.id)
                                            BarText { text: "󰅖"; color: Theme.fgDim; font.pointSize: Theme.smallSize - 1 } }
                                    }
                                    MouseArea { id: wm; anchors.fill: parent; anchors.rightMargin: 28; hoverEnabled: true; onClicked: { Niri.focusWindow(modelData.id); Launcher.sidebarOpen = false } }
                                }
                            }
                        }
                    }
                    Text { visible: Niri.windows.length === 0; text: "No windows open"; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize }
                }

                // ---- clipboard ----
                Section {
                    title: "Clipboard"
                    SmallButton { visible: Clipboard.items.length > 0; label: "Wipe"; onClicked: Clipboard.wipe() }
                }
                Card {
                    Repeater {
                        model: Clipboard.items.slice(0, 12)
                        Rectangle {
                            required property var modelData
                            width: parent.width; height: 28
                            radius: Theme.radius
                            color: cm.containsMouse ? "#2affffff" : "transparent"
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4; spacing: 8
                                Text { anchors.verticalCenter: parent.verticalCenter; width: 16; text: modelData.image ? "󰋩" : "󰅍"; color: Theme.accent; font.family: Theme.font; font.pointSize: 11 }
                                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24 - 28; elide: Text.ElideRight; text: modelData.image ? "Image" : modelData.text; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                                BarButton { padding: 4; implicitHeight: 20; anchors.verticalCenter: parent.verticalCenter; onClicked: Clipboard.remove(modelData)
                                    BarText { text: "󰅖"; color: Theme.fgDim; font.pointSize: Theme.smallSize - 1 } }
                            }
                            MouseArea { id: cm; anchors.fill: parent; anchors.rightMargin: 28; hoverEnabled: true; onClicked: { Clipboard.copy(modelData); Launcher.sidebarOpen = false } }
                        }
                    }
                    Text { visible: Clipboard.items.length === 0; text: "Clipboard history is empty"; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize }
                }

                // ---- timer ----
                Section { title: "Timer" }
                Card {
                    Row {
                        width: parent.width; spacing: 10
                        Text { text: Pomodoro.display; width: 90; color: Pomodoro.left === 0 ? Theme.red : Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: 22; anchors.verticalCenter: parent.verticalCenter }
                        Row {
                            spacing: 6; anchors.verticalCenter: parent.verticalCenter
                            BarButton { padding: 10; implicitHeight: 30; color: Pomodoro.running ? Theme.accent : (hovered ? "#2affffff" : Theme.bg3); onClicked: Pomodoro.toggle()
                                BarText { text: Pomodoro.running ? "󰏤" : "󰐊"; color: Pomodoro.running ? "#1b1e20" : Theme.fg; font.pointSize: 12 } }
                            BarButton { padding: 10; implicitHeight: 30; color: hovered ? "#2affffff" : Theme.bg3; onClicked: Pomodoro.reset()
                                BarText { text: "󰜉"; font.pointSize: 12 } }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 5; radius: 3; color: Theme.bg3
                        Rectangle { width: parent.width * (Pomodoro.total > 0 ? 1 - Pomodoro.left / Pomodoro.total : 0); height: parent.height; radius: 3; color: Theme.accent }
                    }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [5, 15, 25, 45, 60]
                            SmallButton { required property int modelData; label: modelData + " min"; color: Pomodoro.total === modelData * 60 ? "#403daee9" : (hovered ? "#2affffff" : Theme.bg3); onClicked: Pomodoro.set(modelData) }
                        }
                    }
                }

                // ---- media ----
                Section { title: "Now playing"; visible: Media.player !== null }
                Card {
                    visible: Media.player !== null
                    Row {
                        width: parent.width; spacing: 10
                        Rectangle {
                            width: 56; height: 56; radius: 4; color: Theme.bg3; clip: true
                            Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true; sourceSize: Qt.size(112, 112) }
                        }
                        Column {
                            width: parent.width - 66; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { width: parent.width; elide: Text.ElideRight; text: Media.title; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize }
                            Text { width: parent.width; elide: Text.ElideRight; text: Media.artist; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize }
                            Row {
                                spacing: 14; topPadding: 4
                                BarButton { padding: 4; implicitHeight: 24; onClicked: Media.player?.previous()
                                    BarText { text: "󰒮"; font.pointSize: 12 } }
                                BarButton { padding: 4; implicitHeight: 24; onClicked: Media.player?.togglePlaying()
                                    BarText { text: Media.playing ? "󰏤" : "󰐊"; font.pointSize: 12 } }
                                BarButton { padding: 4; implicitHeight: 24; onClicked: Media.player?.next()
                                    BarText { text: "󰒭"; font.pointSize: 12 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
