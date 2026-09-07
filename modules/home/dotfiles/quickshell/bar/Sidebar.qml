import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services

// Right-edge panel: weather, quick launch, todo, windows, capture, clipboard,
// timer, power/system actions, media.
PanelWindow {
    id: win
    visible: Launcher.sidebarOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-sidebar"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onVisibleChanged: if (visible) { Clipboard.refresh(); Capture.refresh(); Power.refresh() }
    Timer { interval: 4000; repeat: true; running: win.visible; onTriggered: { Clipboard.refresh(); Capture.refresh() } }

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

                component Section: Item {
                    property string title
                    property alias extra: extraSlot.data
                    width: parent.width; height: 30
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: title; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; font.capitalization: Font.AllUppercase }
                    Row { id: extraSlot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4 }
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
                    property bool on: false
                    padding: 8; implicitHeight: 26
                    color: on ? Theme.accent : (hovered ? "#2affffff" : Theme.bg3)
                    BarText { text: label; font.pointSize: Theme.smallSize - 1; color: on ? "#1b1e20" : Theme.fg }
                }
                component IconButton: BarButton {
                    property string glyph
                    property string label
                    property bool on: false
                    padding: 8; implicitHeight: 40
                    color: on ? Theme.red : (hovered ? "#2affffff" : Theme.bg3)
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 0
                        BarText { anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter; text: glyph; font.pointSize: 13; color: on ? "#1b1e20" : Theme.fg }
                        BarText { anchors.verticalCenter: undefined; anchors.horizontalCenter: parent.horizontalCenter; text: label; font.pointSize: Theme.smallSize - 3; color: on ? "#1b1e20" : Theme.fgDim }
                    }
                }
                component ListItem: Rectangle {
                    property string glyph
                    property string text
                    property bool active: false
                    property bool strike: false
                    signal clicked
                    signal removed
                    width: parent.width; height: 28
                    radius: Theme.radius
                    color: active ? "#303daee9" : (lm.containsMouse ? "#2affffff" : "transparent")
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4; spacing: 8
                        Text { anchors.verticalCenter: parent.verticalCenter; width: 16; text: glyph; color: Theme.accent; font.family: Theme.font; font.pointSize: 11 }
                        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24 - 28; elide: Text.ElideRight; text: parent.parent.text; color: strike ? Theme.fgDim : Theme.fg; font.strikeout: strike; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                        BarButton { padding: 4; implicitHeight: 20; anchors.verticalCenter: parent.verticalCenter; onClicked: parent.parent.removed()
                            BarText { text: "󰅖"; color: Theme.fgDim; font.pointSize: Theme.smallSize - 1 } }
                    }
                    MouseArea { id: lm; anchors.fill: parent; anchors.rightMargin: 28; hoverEnabled: true; onClicked: parent.clicked() }
                }

                // ---- weather ----
                Section {
                    title: "Weather"
                    Rectangle {
                        width: 130; height: 22; radius: Theme.radius; color: Theme.bg3
                        TextInput {
                            id: cityInput
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: Weather.city; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
                            clip: true
                            onAccepted: { Weather.setCity(text); focus = false }
                        }
                    }
                }
                Card {
                    Text { visible: Weather.error !== ""; text: Weather.error; color: Theme.red; font.family: Theme.font; font.pointSize: Theme.smallSize }
                    Text { visible: !Weather.ready && Weather.error === ""; text: "Loading…"; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize }
                    Row {
                        visible: Weather.ready
                        width: parent.width; spacing: 12
                        Text { text: Weather.ready ? Weather.glyph(Weather.current.code, Weather.current.night) : ""; color: Theme.accent; font.family: Theme.font; font.pointSize: 30; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: Weather.ready ? Weather.current.temp + "°" : ""; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: 20 }
                            Text { text: Weather.ready ? Weather.describe(Weather.current.code) + "  ·  " + Weather.place : ""; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                            Text { text: Weather.ready ? "feels " + Weather.current.feels + "°  ·  󰖝 " + Weather.current.wind + " km/h  ·  󰖎 " + Weather.current.humidity + "%" : ""; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
                        }
                    }
                    Row {
                        visible: Weather.ready
                        width: parent.width
                        Repeater {
                            model: Weather.daily
                            Column {
                                required property var modelData
                                required property int index
                                width: parent.width / 5; spacing: 1
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd"); color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.glyph(modelData.code, false); color: Theme.fg; font.family: Theme.font; font.pointSize: 14 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.max + "° " + modelData.min + "°"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
                            }
                        }
                    }
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

                // ---- todo ----
                Section {
                    title: "Todo" + (Todo.open > 0 ? "  " + Todo.open : "")
                    SmallButton { visible: Todo.items.some(i => i.done); label: "Clear done"; onClicked: Todo.clearDone() }
                }
                Card {
                    Rectangle {
                        width: parent.width; height: 28; radius: Theme.radius; color: Theme.bg3
                        border.color: todoInput.activeFocus ? Theme.accent : "transparent"; border.width: 1
                        TextInput {
                            id: todoInput
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize
                            clip: true
                            onAccepted: { Todo.add(text); text = "" }
                            Text { visible: todoInput.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Add a task and press Enter"; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize }
                        }
                    }
                    Repeater {
                        model: Todo.items
                        ListItem {
                            required property var modelData
                            required property int index
                            glyph: modelData.done ? "󰄲" : "󰄱"; text: modelData.text; strike: modelData.done
                            onClicked: Todo.toggle(index)
                            onRemoved: Todo.remove(index)
                        }
                    }
                    Text { visible: Todo.items.length === 0; text: "Nothing to do"; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize }
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
                            Item {
                                width: parent.width; height: 22
                                Row {
                                    spacing: 6; height: parent.height
                                    Rectangle { width: 18; height: 18; radius: 3; color: modelData.is_active ? Theme.accent : Theme.bg3; anchors.verticalCenter: parent.verticalCenter
                                        Text { anchors.centerIn: parent; text: modelData.name || modelData.idx; color: modelData.is_active ? "#1b1e20" : Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 } }
                                    Text { text: "Workspace " + (modelData.name || modelData.idx); color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; anchors.verticalCenter: parent.verticalCenter }
                                }
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

                // ---- capture ----
                Section { title: "Capture" }
                Card {
                    Row {
                        width: parent.width; spacing: 6
                        IconButton { width: (parent.width - 24) / 5; glyph: "󰩭"; label: "Area"; onClicked: { Launcher.sidebarOpen = false; Capture.shotArea() } }
                        IconButton { width: (parent.width - 24) / 5; glyph: "󰖯"; label: "Window"; onClicked: { Launcher.sidebarOpen = false; Capture.shotWindow() } }
                        IconButton { width: (parent.width - 24) / 5; glyph: "󰍹"; label: "Screen"; onClicked: { Launcher.sidebarOpen = false; Capture.shotScreen() } }
                        IconButton { width: (parent.width - 24) / 5; glyph: Capture.recording ? "󰙦" : "󰑊"; label: Capture.recording ? Math.floor(Capture.recSeconds / 60) + ":" + (Capture.recSeconds % 60 < 10 ? "0" : "") + Capture.recSeconds % 60 : "Record"; on: Capture.recording
                            onClicked: { if (!Capture.recording) Launcher.sidebarOpen = false; Capture.toggleRecord() } }
                        IconButton { width: (parent.width - 24) / 5; glyph: "󰈊"; label: "Colour"; onClicked: { Launcher.sidebarOpen = false; Capture.pickColor() } }
                    }
                    Row {   // picked colours
                        visible: Capture.colors.length > 0
                        spacing: 6
                        Repeater {
                            model: Capture.colors
                            Rectangle {
                                required property string modelData
                                width: 38; height: 22; radius: 3; color: modelData
                                border.color: "#44ffffff"; border.width: 1
                                Text { anchors.centerIn: parent; text: modelData.slice(1); color: Qt.lighter(modelData, 1.0).hslLightness > 0.6 ? "#000" : "#fff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 4 }
                                MouseArea { anchors.fill: parent; onClicked: Capture.copyColor(modelData) }
                            }
                        }
                    }
                    Row {   // recent screenshots
                        visible: Capture.recent.length > 0
                        width: parent.width; spacing: 6
                        Repeater {
                            model: Capture.recent
                            Rectangle {
                                required property string modelData
                                width: (parent.width - 30) / 6; height: width * 9 / 16
                                radius: 3; color: Theme.bg3; clip: true
                                Image { anchors.fill: parent; source: "file://" + modelData; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; sourceSize: Qt.size(120, 68) }
                                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["sh", "-c", "wl-copy < '" + modelData + "' && notify-send -a Screenshots 'Copied to clipboard' '" + modelData.split("/").pop() + "'"]) }
                            }
                        }
                    }
                }

                // ---- clipboard ----
                Section {
                    title: "Clipboard"
                    SmallButton { visible: Clipboard.items.length > 0; label: "Wipe"; onClicked: Clipboard.wipe() }
                }
                Card {
                    Repeater {
                        model: Clipboard.items.slice(0, 10)
                        ListItem {
                            required property var modelData
                            glyph: modelData.image ? "󰋩" : "󰅍"; text: modelData.image ? "Image" : modelData.text
                            onClicked: { Clipboard.copy(modelData); Launcher.sidebarOpen = false }
                            onRemoved: Clipboard.remove(modelData)
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
                            SmallButton { required property int modelData; label: modelData + " min"; on: Pomodoro.total === modelData * 60; onClicked: Pomodoro.set(modelData) }
                        }
                    }
                }

                // ---- power & system ----
                Section { title: "Power profile" }
                Card {
                    Row {
                        spacing: 6
                        Repeater {
                            model: Power.profiles
                            SmallButton { required property string modelData; label: modelData.replace("-", " "); on: Power.profile === modelData; onClicked: Power.set(modelData) }
                        }
                    }
                }
                Section { title: "NixOS" }
                Card {
                    Row {
                        width: parent.width; spacing: 6
                        IconButton { width: (parent.width - 12) / 3; glyph: "󱄅"; label: "Rebuild"; onClicked: { Launcher.sidebarOpen = false; Power.rebuild() } }
                        IconButton { width: (parent.width - 12) / 3; glyph: "󰚰"; label: "Update flake"; onClicked: { Launcher.sidebarOpen = false; Power.update() } }
                        IconButton { width: (parent.width - 12) / 3; glyph: "󰃢"; label: "Clean store"; onClicked: { Launcher.sidebarOpen = false; Power.clean() } }
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
                Item { width: 1; height: 8 }
            }
        }
    }
}
