import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import qs
import qs.services

// Noctalia-style control panel on the right edge: icon tabs on the left,
// one page per tab. Mod+S or the bar button; `qs ipc call sidebar toggle`.
PanelWindow {
    id: win
    visible: Launcher.sidebarOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-sidebar"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property string tab: Launcher.sidebarTab
    onTabChanged: Launcher.sidebarTab = tab
    readonly property var tabs: [
        { id: "home",          glyph: "󰋜", label: "Home" },
        { id: "media",         glyph: "󰝚", label: "Media" },
        { id: "audio",         glyph: "󰕾", label: "Audio" },
        { id: "system",        glyph: "󰍛", label: "System" },
        { id: "network",       glyph: "󰛳", label: "Network" },
        { id: "bluetooth",     glyph: "󰂯", label: "Bluetooth" },
        { id: "weather",       glyph: "󰖕", label: "Weather" },
        { id: "calendar",      glyph: "󰃭", label: "Calendar" },
        { id: "notifications", glyph: "󰂚", label: "Notifications" },
        { id: "screentime",    glyph: "󱎫", label: "Screen time" },
        { id: "power",         glyph: "󰁹", label: "Power" }
    ]
    function open(t) { tab = t }
    onVisibleChanged: if (visible) { Clipboard.refresh(); Capture.refresh(); Power.refresh(); Network.refresh(); ScreenTime.flush() }
    Timer { interval: 4000; repeat: true; running: win.visible; onTriggered: Capture.refresh() }

    // ---- pipewire ----
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => !n.isStream && n.isSink)
    readonly property var sources: nodes.filter(n => !n.isStream && !n.isSink)
    readonly property var streams: nodes.filter(n => n.isStream)
    PwObjectTracker { objects: win.nodes }
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    function nodeName(n) { return n.nickname || n.description || n.name }
    function streamName(n) { const p = n.properties || {}; return (p["application.name"] || p["node.name"] || n.name) + (p["media.name"] ? "  ·  " + p["media.name"] : "") }

    // ---- bluetooth ----
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btKnown: adapter ? Bluetooth.devices.values.filter(d => d.paired || d.connected).sort((a, b) => (b.connected - a.connected)) : []
    readonly property var btFound: adapter ? Bluetooth.devices.values.filter(d => !d.paired && !d.connected && d.name && d.name !== "") : []
    Binding { target: Network; property: "active"; value: win.visible }

    property int stRange: 1

    MouseArea { anchors.fill: parent; onClicked: Launcher.sidebarOpen = false }

    // ---------- building blocks ----------
    component Label: Text { color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.fontSize }
    component Dim: Text { color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
    component Heading: Text { color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize + 3; bottomPadding: 6 }
    component Section: Text { color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; font.capitalization: Font.AllUppercase; topPadding: 10 }
    component Card: Rectangle {
        width: parent.width
        radius: Theme.radius; color: Theme.bg2
        default property alias content: inner.data
        property alias spacing: inner.spacing
        signal clicked
        implicitHeight: inner.implicitHeight + 20
        MouseArea { anchors.fill: parent; z: -1; onClicked: parent.clicked() }
        Column { id: inner; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; spacing: 6 }
    }
    component KV: Row {
        property string k; property string v
        width: parent.width
        Dim { width: parent.width * 0.4; text: k; font.pointSize: Theme.smallSize }
        Label { width: parent.width * 0.6; horizontalAlignment: Text.AlignRight; elide: v.includes("\n") ? Text.ElideNone : Text.ElideMiddle; wrapMode: v.includes("\n") ? Text.WordWrap : Text.NoWrap; text: v; font.pointSize: Theme.smallSize }
    }
    component SmallButton: BarButton {
        property string label
        property bool on: false
        padding: 8; implicitHeight: 26
        color: on ? Theme.accent : (hovered ? "#2affffff" : Theme.bg3)
        BarText { text: label; font.pointSize: Theme.smallSize - 1; color: on ? "#1b1e20" : Theme.fg }
    }
    component Toggle: Rectangle {
        property bool on: false
        signal toggled(bool value)
        width: 44; height: 24; radius: 12
        color: on ? Theme.accent : Theme.bg3
        Rectangle { x: parent.on ? parent.width - width - 3 : 3; y: 3; width: 18; height: 18; radius: 9; color: Theme.fg; Behavior on x { NumberAnimation { duration: 120 } } }
        MouseArea { anchors.fill: parent; onClicked: parent.toggled(!parent.on) }
    }
    component ToggleRow: Row {
        property string label; property string sub: ""
        property bool on: false
        signal toggled(bool value)
        width: parent.width; height: 36
        Column { width: parent.width - 50; anchors.verticalCenter: parent.verticalCenter
            Label { text: label; font.pointSize: Theme.smallSize }
            Dim { visible: sub !== ""; text: sub } }
        Toggle { anchors.verticalCenter: parent.verticalCenter; on: parent.on; onToggled: v => parent.toggled(v) }
    }
    component Vol: Slider {
        id: s
        property string glyph
        property bool mutedState: false
        property var node
        signal toggleMute
        width: parent.width; height: 26
        from: 0; to: 1
        leftPadding: 34; rightPadding: 44
        readonly property real nodeVolume: node?.audio?.volume ?? 0
        onNodeVolumeChanged: if (!pressed) value = nodeVolume
        Component.onCompleted: value = nodeVolume
        onMoved: if (node?.audio) node.audio.volume = value
        Text { x: 4; anchors.verticalCenter: parent.verticalCenter; text: s.glyph; color: s.mutedState ? Theme.fgDim : Theme.fg; font.family: Theme.font; font.pointSize: 13
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: s.toggleMute() } }
        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Math.round(s.value * 100) + "%"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize }
        background: Rectangle { x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - 2; width: s.availableWidth; height: 4; radius: 2; color: Theme.bg3
            Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: s.mutedState ? Theme.fgDim : Theme.accent } }
        handle: Rectangle { x: s.leftPadding + s.visualPosition * (s.availableWidth - width); y: s.topPadding + s.availableHeight / 2 - height / 2; width: 14; height: 14; radius: 7; color: Theme.fg }
    }
    component ListRow: Rectangle {
        property string glyph
        property string label
        property string sub: ""
        property bool active: false
        property string action: ""
        signal clicked
        signal actionClicked
        width: parent.width; height: 34
        radius: Theme.radius
        color: ma.containsMouse ? "#2affffff" : "transparent"
        Row {
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; width: 20; text: glyph; color: active ? Theme.accent : Theme.fg; font.family: Theme.font; font.pointSize: 13 }
            Column { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28 - (action !== "" ? 90 : 0)
                Label { width: parent.width; elide: Text.ElideRight; text: label; color: active ? Theme.accent : Theme.fg; font.pointSize: Theme.smallSize }
                Dim { visible: sub !== ""; width: parent.width; elide: Text.ElideRight; text: sub } }
            SmallButton { visible: action !== ""; anchors.verticalCenter: parent.verticalCenter; label: action; onClicked: parent.parent.actionClicked() }
        }
        MouseArea { id: ma; anchors.fill: parent; anchors.rightMargin: action !== "" ? 90 : 0; hoverEnabled: true; onClicked: parent.clicked() }
    }
    component Shortcut: Rectangle {
        property string glyph; property string label
        property bool on: false
        signal clicked
        width: (parent.width - 3 * 8) / 4; height: 62
        radius: Theme.radius
        color: on ? Theme.red : (sm.containsMouse ? "#2affffff" : Theme.bg3)
        Column { anchors.centerIn: parent; spacing: 4
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: glyph; color: on ? "#1b1e20" : Theme.fg; font.family: Theme.font; font.pointSize: 18 }
            Dim { anchors.horizontalCenter: parent.horizontalCenter; text: label; color: on ? "#1b1e20" : Theme.fgDim; font.pointSize: Theme.smallSize - 2 } }
        MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }

    Rectangle {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.topMargin: Theme.barHeight
        width: 540
        color: Theme.panelBg
        border.color: Theme.cardBorder; border.width: 1
        MouseArea { anchors.fill: parent }

        // ---------- tab rail ----------
        Rectangle {
            id: rail
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 1
            width: 56
            color: "#14ffffff"
            Column {
                anchors.top: parent.top; anchors.topMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                Repeater {
                    model: win.tabs
                    Rectangle {
                        required property var modelData
                        width: 40; height: 40; radius: Theme.radius
                        color: win.tab === modelData.id ? "#403daee9" : (tm.containsMouse ? "#2affffff" : "transparent")
                        Text { anchors.centerIn: parent; text: modelData.glyph; color: win.tab === modelData.id ? Theme.accent : Theme.fgDim; font.family: Theme.font; font.pointSize: 15 }
                        Rectangle {   // badge for notifications
                            visible: modelData.id === "notifications" && Notifs.count > 0
                            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                            width: 8; height: 8; radius: 4; color: Theme.accent
                        }
                        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; onClicked: win.tab = modelData.id }
                    }
                }
            }
            Rectangle {   // session
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 8
                width: 40; height: 40; radius: Theme.radius
                color: pm.containsMouse ? "#2affffff" : "transparent"
                Text { anchors.centerIn: parent; text: "⏻"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: 14 }
                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: { Launcher.sidebarOpen = false; Launcher.toggleSession() } }
            }
        }

        Flickable {
            anchors.left: rail.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 14
            contentHeight: page.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: page
                width: parent.width
                spacing: 8

                // ================= HOME =================
                Column {
                    visible: win.tab === "home"
                    width: parent.width; spacing: 8
                    Card {
                        Row {
                            width: parent.width; spacing: 12
                            Rectangle {
                                width: 56; height: 56; radius: 28; color: Theme.accent; clip: true
                                Text { anchors.centerIn: parent; text: Quickshell.env("USER").slice(0, 1).toUpperCase(); color: "#1b1e20"; font.bold: true; font.family: Theme.font; font.pointSize: 22; visible: face.status !== Image.Ready }
                                Image { id: face; anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; sourceSize: Qt.size(112, 112) }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter; width: parent.width - 68; spacing: 2
                                Label { text: Quickshell.env("USER") + "@" + Niri.hostname; font.bold: true }
                                Dim { text: "up " + SysStats.uptime + "   ·   " + Qt.formatDateTime(new Date(), "dddd, d MMMM") }
                                Dim { text: SysInfo.os }
                            }
                        }
                    }
                    Row {
                        width: parent.width; spacing: 8
                        Card {   // weather summary
                            width: (parent.width - 8) / 2
                            Row { spacing: 10
                                Text { text: Weather.ready ? Weather.glyph(Weather.current.code, Weather.current.night) : "󰖐"; color: Theme.accent; font.family: Theme.font; font.pointSize: 24; anchors.verticalCenter: parent.verticalCenter }
                                Column { anchors.verticalCenter: parent.verticalCenter
                                    Label { text: Weather.ready ? Weather.current.temp + "°" : "—"; font.bold: true; font.pointSize: Theme.fontSize + 3 }
                                    Dim { text: Weather.ready ? Weather.describe(Weather.current.code) : (Weather.error || "Loading…") } } }
                            onClicked: win.tab = "weather"
                        }
                        Card {   // media summary
                            width: (parent.width - 8) / 2
                            Row { width: parent.width; spacing: 10
                                Rectangle { width: 40; height: 40; radius: 4; color: Theme.bg3; clip: true
                                    Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true; sourceSize: Qt.size(80, 80) }
                                    Text { visible: Media.artUrl === ""; anchors.centerIn: parent; text: "󰝚"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: 14 } }
                                Column { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 50
                                    Label { width: parent.width; elide: Text.ElideRight; text: Media.player ? Media.title : "Nothing playing"; font.bold: true; font.pointSize: Theme.smallSize }
                                    Dim { width: parent.width; elide: Text.ElideRight; text: Media.artist } } }
                            onClicked: win.tab = "media"
                        }
                    }
                    Section { text: "Shortcuts" }
                    Card {
                        Flow {
                            width: parent.width; spacing: 8
                            Shortcut { glyph: "󰩭"; label: "Area shot"; onClicked: { Launcher.sidebarOpen = false; Capture.shotArea() } }
                            Shortcut { glyph: "󰖯"; label: "Window"; onClicked: { Launcher.sidebarOpen = false; Capture.shotWindow() } }
                            Shortcut { glyph: "󰍹"; label: "Screen"; onClicked: { Launcher.sidebarOpen = false; Capture.shotScreen() } }
                            Shortcut { glyph: Capture.recording ? "󰙦" : "󰑊"; label: Capture.recording ? Math.floor(Capture.recSeconds / 60) + ":" + (Capture.recSeconds % 60 < 10 ? "0" : "") + Capture.recSeconds % 60 : "Record"; on: Capture.recording
                                onClicked: { if (!Capture.recording) Launcher.sidebarOpen = false; Capture.toggleRecord() } }
                            Shortcut { glyph: "󰈊"; label: "Colour"; onClicked: { Launcher.sidebarOpen = false; Capture.pickColor() } }
                            Shortcut { glyph: "󰸉"; label: "Wallpaper"; onClicked: Launcher.toggleWallpaper() }
                            Shortcut { glyph: "󰌾"; label: "Lock"; onClicked: { Launcher.sidebarOpen = false; Lock.lock() } }
                            Shortcut { glyph: "󱄅"; label: "Rebuild"; onClicked: { Launcher.sidebarOpen = false; Power.rebuild() } }
                        }
                        Row {   // picked colours + recent shots
                            visible: Capture.colors.length > 0
                            spacing: 6
                            Repeater { model: Capture.colors
                                Rectangle { required property string modelData; width: 44; height: 22; radius: 3; color: modelData; border.color: "#44ffffff"; border.width: 1
                                    Text { anchors.centerIn: parent; text: modelData.slice(1); color: Qt.color(modelData).hslLightness > 0.6 ? "#000" : "#fff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 4 }
                                    MouseArea { anchors.fill: parent; onClicked: Capture.copyColor(modelData) } } }
                        }
                        Row {
                            visible: Capture.recent.length > 0
                            width: parent.width; spacing: 6
                            Repeater { model: Capture.recent
                                Rectangle { required property string modelData; width: (parent.width - 30) / 6; height: width * 9 / 16; radius: 3; color: Theme.bg3; clip: true
                                    Image { anchors.fill: parent; source: "file://" + modelData; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; sourceSize: Qt.size(120, 68) }
                                    MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["sh", "-c", "wl-copy < '" + modelData + "' && notify-send -a Screenshots 'Copied to clipboard' '" + modelData.split("/").pop() + "'"]) } } }
                        }
                    }
                    Section { text: "Clipboard" }
                    Card {
                        Repeater {
                            model: Clipboard.items.slice(0, 6)
                            ListRow { required property var modelData; glyph: modelData.image ? "󰋩" : "󰅍"; label: modelData.image ? "Image" : modelData.text; height: 28
                                onClicked: { Clipboard.copy(modelData); Launcher.sidebarOpen = false } }
                        }
                        Dim { visible: Clipboard.items.length === 0; text: "Clipboard history is empty" }
                        Dim { visible: Clipboard.items.length > 6; text: "Type /clip in the launcher for the full history" }
                    }
                }

                // ================= MEDIA =================
                Column {
                    visible: win.tab === "media"
                    width: parent.width; spacing: 8
                    Heading { text: "Media" }
                    Dim { visible: Media.players.length === 0; text: "No MPRIS players running" }
                    Repeater {
                        model: Media.players
                        Card {
                            required property MprisPlayer modelData
                            readonly property MprisPlayer p: modelData
                            readonly property bool sel: p === Media.player
                            border.color: sel ? Theme.accent : "transparent"; border.width: 1
                            Row {
                                width: parent.width; spacing: 12
                                Rectangle { width: 72; height: 72; radius: 4; color: Theme.bg3; clip: true
                                    Image { anchors.fill: parent; source: p.trackArtUrl || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true; sourceSize: Qt.size(144, 144) } }
                                Column { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 84; spacing: 2
                                    Label { width: parent.width; elide: Text.ElideRight; text: p.trackTitle || "—"; font.bold: true }
                                    Dim { width: parent.width; elide: Text.ElideRight; text: p.trackArtist || "" }
                                    Row { spacing: 6; topPadding: 4
                                        SmallButton { label: p.identity; on: sel; onClicked: Media.select(p) }
                                        Dim { anchors.verticalCenter: parent.verticalCenter; text: p.isPlaying ? "playing" : "paused" } }
                                }
                            }
                            Rectangle { width: parent.width; height: 4; radius: 2; color: Theme.bg3
                                Rectangle { width: p.length > 0 ? parent.width * Math.min(1, p.position / p.length) : 0; height: parent.height; radius: 2; color: Theme.accent } }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 22
                                BarButton { padding: 6; onClicked: p.previous(); BarText { text: "󰒮"; font.pointSize: 14 } }
                                BarButton { padding: 6; onClicked: p.togglePlaying(); BarText { text: p.isPlaying ? "󰏤" : "󰐊"; font.pointSize: 18 } }
                                BarButton { padding: 6; onClicked: p.next(); BarText { text: "󰒭"; font.pointSize: 14 } }
                            }
                        }
                    }
                }

                // ================= AUDIO =================
                Column {
                    visible: win.tab === "audio"
                    width: parent.width; spacing: 8
                    Heading { text: "Audio" }
                    Card {
                        Section { text: "Output  ·  " + (win.sink ? win.nodeName(win.sink) : "none"); topPadding: 0 }
                        Vol { glyph: mutedState ? "󰖁" : "󰕾"; node: win.sink; mutedState: win.sink?.audio?.muted ?? false; onToggleMute: if (win.sink?.audio) win.sink.audio.muted = !win.sink.audio.muted }
                        Section { text: "Input  ·  " + (win.source ? win.nodeName(win.source) : "none") }
                        Vol { glyph: mutedState ? "󰍭" : "󰍬"; node: win.source; mutedState: win.source?.audio?.muted ?? false; onToggleMute: if (win.source?.audio) win.source.audio.muted = !win.source.audio.muted }
                    }
                    Section { text: "Output devices" }
                    Card {
                        Repeater { model: win.sinks
                            ListRow { required property var modelData; glyph: modelData === win.sink ? "󰄬" : "󰓃"; label: win.nodeName(modelData); active: modelData === win.sink; onClicked: Pipewire.preferredDefaultAudioSink = modelData } }
                    }
                    Section { text: "Input devices" }
                    Card {
                        Repeater { model: win.sources
                            ListRow { required property var modelData; glyph: modelData === win.source ? "󰄬" : "󰍬"; label: win.nodeName(modelData); active: modelData === win.source; onClicked: Pipewire.preferredDefaultAudioSource = modelData } }
                    }
                    Section { text: "Applications" }
                    Card {
                        Dim { visible: win.streams.length === 0; text: "No application is playing or recording" }
                        Repeater {
                            model: win.streams
                            Column {
                                required property var modelData
                                width: parent.width; spacing: 2
                                Dim { width: parent.width; elide: Text.ElideRight; text: (modelData.isSink ? "󰝚  " : "󰍬  ") + win.streamName(modelData) }
                                Vol { glyph: mutedState ? "󰖁" : "󰕾"; node: modelData; mutedState: modelData.audio?.muted ?? false; onToggleMute: modelData.audio.muted = !modelData.audio.muted }
                            }
                        }
                    }
                    Row { spacing: 6
                        SmallButton { label: "pavucontrol"; onClicked: { Launcher.sidebarOpen = false; Quickshell.execDetached(["pavucontrol"]) } } }
                }

                // ================= SYSTEM =================
                Column {
                    visible: win.tab === "system"
                    width: parent.width; spacing: 8
                    Heading { text: "System" }
                    Card {
                        KV { k: "User"; v: SysInfo.user }
                        KV { k: "Host"; v: SysInfo.host }
                        KV { k: "Board"; v: SysInfo.board }
                        KV { k: "BIOS"; v: SysInfo.bios }
                        KV { k: "OS"; v: SysInfo.os }
                        KV { k: "Kernel"; v: SysInfo.kernel }
                        KV { k: "Packages"; v: SysInfo.packages > 0 ? SysInfo.packages + " (nix)" : "…" }
                        KV { k: "Session"; v: SysInfo.session }
                        KV { k: "WM"; v: SysInfo.wm }
                        KV { k: "Shell"; v: SysInfo.shell }
                        KV { k: "CPU"; v: SysInfo.cpu + "  ·  " + SysStats.cores + " threads" }
                        KV { k: "GPU"; v: SysInfo.gpu + (SysInfo.gpuDriver ? "  (" + SysInfo.gpuDriver + ")" : "") }
                        KV { k: "Memory"; v: SysInfo.memory }
                        KV { k: "Disk /"; v: SysInfo.rootDisk }
                        KV { k: "Display"; v: SysInfo.display }
                        KV { k: "Locale"; v: SysInfo.locale }
                        KV { k: "Uptime"; v: SysStats.uptime }
                    }
                    Section { text: "Live" }
                    Card {
                        Row { width: parent.width
                            Gauge { width: parent.width / 3; size: 80; value: SysStats.cpu; label: "CPU  " + Math.round(SysStats.temp) + "°"; center: Math.round(SysStats.cpu) + "%" }
                            Gauge { width: parent.width / 3; size: 80; value: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal * 100 : 0; label: "Memory"; color: Theme.green }
                            Gauge { width: parent.width / 3; size: 80; value: SysStats.gpuTemp; label: "GPU  " + Math.round(SysStats.gpuTemp) + "°"; center: SysStats.gpu > 0 ? Math.round(SysStats.gpu) + "%" : "–"; color: Theme.yellow } }
                        Row { width: parent.width; spacing: 8
                            Dim { text: "CPU"; width: 36; anchors.verticalCenter: parent.verticalCenter }
                            Sparkline { width: parent.width - 44; height: 36; data: SysStats.cpuHist } }
                        Row { width: parent.width; spacing: 8
                            Dim { text: "MEM"; width: 36; anchors.verticalCenter: parent.verticalCenter }
                            Sparkline { width: parent.width - 44; height: 36; data: SysStats.memHist; color: Theme.green } }
                        KV { k: "Memory"; v: SysStats.fmtBytes(SysStats.memUsed) + " / " + SysStats.fmtBytes(SysStats.memTotal) }
                        KV { k: "Swap"; v: SysStats.fmtBytes(SysStats.swapUsed, 0) + " / " + SysStats.fmtBytes(SysStats.swapTotal, 0) }
                        KV { k: "Network"; v: "󰁅 " + SysStats.fmtRate(SysStats.rx) + "   󰁝 " + SysStats.fmtRate(SysStats.tx) }
                    }
                    Section { text: "Storage" }
                    Card {
                        Repeater { model: SysStats.disks
                            DiskRow { required property var modelData; disk: modelData; width: parent.width } }
                        KV { visible: SysStats.nvmeTemp > 0; k: "NVMe temperature"; v: Math.round(SysStats.nvmeTemp) + " °C" }
                    }
                    Section { text: "NixOS" }
                    Card {
                        Row { spacing: 6
                            SmallButton { label: "󱄅  Rebuild"; onClicked: { Launcher.sidebarOpen = false; Power.rebuild() } }
                            SmallButton { label: "󰚰  Update flake"; onClicked: { Launcher.sidebarOpen = false; Power.update() } }
                            SmallButton { label: "󰃢  Clean store"; onClicked: { Launcher.sidebarOpen = false; Power.clean() } } }
                    }
                }

                // ================= NETWORK =================
                Column {
                    visible: win.tab === "network"
                    width: parent.width; spacing: 8
                    Heading { text: "Network" }
                    Card {
                        KV { k: "Connection"; v: Network.primary ? Network.primary.connection + "  (" + Network.primary.name + ")" : "Disconnected" }
                        KV { k: "Type"; v: Network.primary ? Network.primary.type : "—" }
                        KV { k: "IPv4"; v: Network.primary ? Network.primary.ip4 : "—" }
                        KV { visible: Network.vpn !== null; k: "VPN"; v: Network.vpn ? Network.vpn.connection + "  " + Network.vpn.ip4 : "" }
                        KV { visible: Network.current !== null; k: "Wi-Fi"; v: Network.current ? Network.current.ssid + "  ·  " + Network.current.signal + "%  ·  " + Network.current.band : "" }
                    }
                    Section { text: "Wi-Fi"; visible: Network.hasWifi }
                    Card {
                        visible: Network.hasWifi
                        ToggleRow { label: "Wi-Fi"; on: Network.wifi.length > 0 || Network.current !== null; onToggled: v => Network.toggleWifi(v) }
                        Repeater {
                            model: Network.wifi.slice(0, 12)
                            ListRow {
                                required property var modelData
                                glyph: modelData.signal > 66 ? "󰤨" : modelData.signal > 33 ? "󰤥" : "󰤟"
                                label: modelData.ssid; sub: modelData.signal + "%  ·  " + modelData.band + (modelData.secure ? "  ·  󰌾" : "")
                                active: modelData.inUse
                                action: modelData.inUse ? "Disconnect" : "Connect"
                                onActionClicked: modelData.inUse ? Network.disconnect(Network.primary ? Network.primary.connection : modelData.ssid) : Network.connect(modelData.ssid)
                                onClicked: if (!modelData.inUse) Network.connect(modelData.ssid)
                            }
                        }
                    }
                    Section { text: "Interfaces" }
                    Card {
                        Repeater { model: Network.devices
                            ListRow { required property var modelData
                                glyph: modelData.type === "wifi" ? "󰤨" : modelData.type === "ethernet" ? "󰈀" : modelData.type === "wireguard" || modelData.type === "tun" ? "󰖂" : "󰛳"
                                label: modelData.name + (modelData.connection ? "  ·  " + modelData.connection : ""); sub: modelData.state + (modelData.ip4 ? "  ·  " + modelData.ip4 : "")
                                active: modelData.state === "connected"
                                action: modelData.state === "connected" && modelData.connection ? "Down" : ""
                                onActionClicked: Network.disconnect(modelData.connection) } }
                    }
                    Row { spacing: 6
                        SmallButton { label: "Edit connections"; onClicked: { Launcher.sidebarOpen = false; Quickshell.execDetached(["nm-connection-editor"]) } } }
                }

                // ================= BLUETOOTH =================
                Column {
                    visible: win.tab === "bluetooth"
                    width: parent.width; spacing: 8
                    Heading { text: "Bluetooth" }
                    Card {
                        ToggleRow { label: "Bluetooth"; sub: win.adapter ? (win.adapter.enabled ? "On" : "Off") : "No adapter"; on: win.adapter?.enabled ?? false; onToggled: v => { if (win.adapter) win.adapter.enabled = v } }
                        ToggleRow { visible: win.adapter?.enabled ?? false; label: "Discover nearby devices"; sub: (win.adapter?.discovering ?? false) ? "Scanning…" : ""; on: win.adapter?.discovering ?? false; onToggled: v => { if (win.adapter) win.adapter.discovering = v } }
                    }
                    Section { text: "My devices" }
                    Card {
                        Dim { visible: win.btKnown.length === 0; text: "No paired devices" }
                        Repeater {
                            model: win.btKnown
                            ListRow {
                                required property var modelData
                                glyph: modelData.connected ? "󰂱" : "󰂲"
                                label: modelData.name
                                sub: (modelData.connected ? "Connected" : "Paired") + (modelData.batteryAvailable ? "  ·  󰁹 " + Math.round(modelData.battery * 100) + "%" : "")
                                active: modelData.connected
                                action: modelData.connected ? "Disconnect" : "Connect"
                                onActionClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                            }
                        }
                    }
                    Section { text: "Nearby"; visible: win.btFound.length > 0 }
                    Card {
                        visible: win.btFound.length > 0
                        Repeater {
                            model: win.btFound.slice(0, 10)
                            ListRow { required property var modelData; glyph: "󰂯"; label: modelData.name; sub: modelData.address; action: "Pair"; onActionClicked: modelData.pair(); onClicked: modelData.pair() }
                        }
                    }
                }

                // ================= WEATHER =================
                Column {
                    visible: win.tab === "weather"
                    width: parent.width; spacing: 8
                    Heading { text: "Weather" }
                    Card {
                        Dim { visible: Weather.error !== ""; text: Weather.error; color: Theme.red }
                        Dim { visible: !Weather.ready && Weather.error === ""; text: "Loading…" }
                        Row {
                            visible: Weather.ready
                            width: parent.width; spacing: 14
                            Text { text: Weather.ready ? Weather.glyph(Weather.current.code, Weather.current.night) : ""; color: Theme.accent; font.family: Theme.font; font.pointSize: 44; anchors.verticalCenter: parent.verticalCenter }
                            Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Label { text: Weather.ready ? Weather.current.temp + "°" : ""; font.bold: true; font.pointSize: 28 }
                                Label { text: Weather.ready ? Weather.describe(Weather.current.code) : ""; font.pointSize: Theme.fontSize }
                                Dim { text: Weather.place } }
                        }
                        KV { visible: Weather.ready; k: "Feels like"; v: Weather.ready ? Weather.current.feels + "°" : "" }
                        KV { visible: Weather.ready; k: "Wind"; v: Weather.ready ? Weather.current.wind + " km/h" : "" }
                        KV { visible: Weather.ready; k: "Humidity"; v: Weather.ready ? Weather.current.humidity + "%" : "" }
                    }
                    Section { text: "Forecast" }
                    Card {
                        Repeater {
                            model: Weather.daily
                            Row {
                                required property var modelData
                                required property int index
                                width: parent.width; height: 30
                                Dim { width: 70; anchors.verticalCenter: parent.verticalCenter; text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "dddd"); font.pointSize: Theme.smallSize }
                                Text { width: 34; anchors.verticalCenter: parent.verticalCenter; text: Weather.glyph(modelData.code, false); color: Theme.fg; font.family: Theme.font; font.pointSize: 15 }
                                Dim { width: parent.width - 70 - 34 - 90; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: Weather.describe(modelData.code) }
                                Label { width: 90; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: modelData.max + "°  /  " + modelData.min + "°"; font.pointSize: Theme.smallSize }
                            }
                        }
                    }
                    Dim { text: "City: " + Settings.s.weather.city + "  (quickshell-settings.nix → weather.city)" }
                }

                // ================= CALENDAR =================
                Column {
                    visible: win.tab === "calendar"
                    width: parent.width; spacing: 8
                    Heading { text: "Calendar" }
                    Card { CalendarView { width: parent.width } }
                    Dim { text: Qt.formatDate(new Date(), "dddd, d MMMM yyyy") }
                }

                // ================= NOTIFICATIONS =================
                Column {
                    visible: win.tab === "notifications"
                    width: parent.width; spacing: 8
                    Row { width: parent.width
                        Heading { text: "Notifications" + (Notifs.count > 0 ? "  " + Notifs.count : ""); width: parent.width - 170 }
                        Row { spacing: 6
                            SmallButton { label: Notifs.dnd ? "󰂛 DND on" : "󰂚 DND off"; on: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
                            SmallButton { visible: Notifs.count > 0; label: "Clear"; onClicked: Notifs.clearAll() } } }
                    Dim { visible: Notifs.count === 0; text: "No notifications" }
                    Repeater {
                        model: Notifs.history.slice().reverse()
                        NotificationCard { required property var modelData; n: modelData; width: page.width; onClicked: Notifs.activate(n); onClosed: Notifs.dismiss(n) }
                    }
                }

                // ================= SCREEN TIME =================
                Column {
                    id: st
                    visible: win.tab === "screentime"
                    width: parent.width; spacing: 8
                    readonly property var apps: ScreenTime.usage(win.stRange)
                    readonly property var days: ScreenTime.daily(win.stRange === 1 ? 7 : win.stRange)
                    readonly property real total: apps.reduce((s, a) => s + a.seconds, 0)
                    readonly property real maxDay: Math.max(1, ...days.map(d => d.seconds))
                    Row { width: parent.width
                        Heading { text: "Screen time"; width: parent.width - 220 }
                        Row { spacing: 4
                            SmallButton { label: "Today"; on: win.stRange === 1; onClicked: win.stRange = 1 }
                            SmallButton { label: "3 days"; on: win.stRange === 3; onClicked: win.stRange = 3 }
                            SmallButton { label: "14 days"; on: win.stRange === 14; onClicked: win.stRange = 14 } } }
                    Card {
                        Label { text: ScreenTime.fmt(st.total) + (win.stRange === 1 ? " today" : " in the last " + win.stRange + " days"); font.bold: true; font.pointSize: Theme.fontSize + 3 }
                        Row {   // daily bars
                            width: parent.width; height: 90; spacing: 6
                            Repeater {
                                model: st.days
                                Column {
                                    required property var modelData
                                    width: (parent.width - 6 * (st.days.length - 1)) / st.days.length
                                    height: parent.height
                                    Item { width: parent.width; height: parent.height - 16
                                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 3
                                            height: Math.max(2, parent.height * modelData.seconds / st.maxDay)
                                            color: modelData.date === ScreenTime.today() ? Theme.accent : "#553daee9" } }
                                    Dim { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.pointSize: Theme.smallSize - 3 }
                                }
                            }
                        }
                    }
                    Section { text: "By application" }
                    Card {
                        Dim { visible: st.apps.length === 0; text: "Nothing tracked yet" }
                        Repeater {
                            model: st.apps.slice(0, 12)
                            Column {
                                required property var modelData
                                readonly property real frac: modelData.seconds / Math.max(1, st.total)
                                width: parent.width; spacing: 3
                                Row { width: parent.width; spacing: 8
                                    IconImage { anchors.verticalCenter: parent.verticalCenter; implicitSize: 18; asynchronous: true; source: Apps.icon(modelData.app) }
                                    Label { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 26 - 110; elide: Text.ElideRight; text: Apps.entry(modelData.app)?.name ?? modelData.app; font.pointSize: Theme.smallSize }
                                    Dim { anchors.verticalCenter: parent.verticalCenter; width: 110; horizontalAlignment: Text.AlignRight; text: ScreenTime.fmt(modelData.seconds) + "  ·  " + Math.round(frac * 100) + "%" } }
                                Rectangle { width: parent.width; height: 4; radius: 2; color: Theme.bg3
                                    Rectangle { width: parent.width * frac; height: parent.height; radius: 2; color: Theme.accent } }
                            }
                        }
                    }
                    Row { spacing: 6
                        SmallButton { label: "Reset data"; onClicked: ScreenTime.reset() } }
                }

                // ================= POWER =================
                Column {
                    visible: win.tab === "power"
                    width: parent.width; spacing: 8
                    Heading { text: "Power" }
                    Card {
                        visible: Battery.present
                        Row { spacing: 12
                            Text { text: Battery.glyph; color: Battery.low ? Theme.red : (Battery.charging ? Theme.green : Theme.fg); font.family: Theme.font; font.pointSize: 30; anchors.verticalCenter: parent.verticalCenter }
                            Column { anchors.verticalCenter: parent.verticalCenter
                                Label { text: Battery.pct + "%"; font.bold: true; font.pointSize: Theme.fontSize + 6 }
                                Dim { text: (Battery.charging ? "Charging" : Battery.full ? "Full" : "Discharging") + (Battery.timeText ? "  ·  " + Battery.timeText : "") } } }
                        Rectangle { width: parent.width; height: 6; radius: 3; color: Theme.bg3
                            Rectangle { width: parent.width * Battery.pct / 100; height: parent.height; radius: 3; color: Battery.low ? Theme.red : (Battery.charging ? Theme.green : Theme.accent) } }
                    }
                    Card {
                        visible: !Battery.present
                        Dim { text: "Desktop: no battery" }
                    }
                    Section { text: "Display"; visible: Brightness.present }
                    Card {
                        visible: Brightness.present
                        Vol {
                            id: bri
                            glyph: "󰃠"; node: null
                            Component.onCompleted: value = Brightness.level
                            onMoved: Brightness.set(value)
                            Connections { target: Brightness; function onLevelChanged() { if (!bri.pressed) bri.value = Brightness.level } }
                        }
                    }
                    Section { text: Power.watt ? "Policy (watt)" : "Profile" }
                    Card {
                        Row { visible: !Power.watt; spacing: 6
                            Repeater { model: Power.profiles
                                SmallButton { required property string modelData; label: modelData.replace("-", " "); on: Power.profile === modelData; onClicked: Power.set(modelData) } } }
                        Column { visible: Power.watt; width: parent.width; spacing: 2
                            Row { spacing: 8
                                Text { text: Battery.onAc ? "󰚥" : "󰁹"; color: Battery.onAc ? Theme.green : Theme.accent; font.family: Theme.font; font.pointSize: 13 }
                                Label { text: Battery.onAc ? "Wall power: maximum performance" : "Battery: power saving"; font.bold: true; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter } }
                            Dim { text: "Managed by watt; charge held between 40 and 80 %" } }
                    }
                    Section { text: "Peripherals"; visible: Devices.all.length > 0 }
                    Card {
                        visible: Devices.all.length > 0
                        Repeater { model: Devices.all
                            Row { required property var modelData; width: parent.width; spacing: 8
                                Text { text: modelData.glyph; width: 20; color: Theme.fg; font.family: Theme.font; font.pointSize: 12 }
                                Label { text: modelData.name; width: parent.width - 28 - 120; elide: Text.ElideRight; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle { width: 80; height: 6; radius: 3; color: Theme.bg3; anchors.verticalCenter: parent.verticalCenter
                                    Rectangle { width: parent.width * modelData.pct / 100; height: parent.height; radius: 3; color: modelData.pct < 20 ? Theme.red : Theme.green } }
                                Dim { text: modelData.pct + "%" + (modelData.charging ? " 󱐋" : ""); width: 40; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter } } }
                    }
                }

                Item { width: 1; height: 8 }
            }
        }
    }
}
