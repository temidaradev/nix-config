import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Settings app: edits ~/.local/state/quickshell/settings.json live.
// Nix defaults come from quickshell-settings.nix; Export copies a snippet for it.
PanelWindow {
    id: win
    visible: Launcher.settingsOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-settings"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property string tab: "appearance"
    readonly property var tabs: [
        { id: "appearance", glyph: "󰏘", label: "Appearance" },
        { id: "bar", glyph: "󰍜", label: "Bar" },
        { id: "clock", glyph: "󰥔", label: "Clock & media" },
        { id: "launch", glyph: "󱓞", label: "Quick launch" },
        { id: "misc", glyph: "󰒓", label: "Weather, OSD, notifications" }
    ]

    MouseArea { anchors.fill: parent; onClicked: Launcher.settingsOpen = false }

    // ---------- widgets ----------
    component Label: Text { color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.fontSize }
    component Hint: Text { color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; wrapMode: Text.Wrap }
    component Heading: Text { color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize + 2; bottomPadding: 4 }

    component Row_: Item {
        property string label
        property string hint: ""
        default property alias control: slot.data
        width: parent.width; height: Math.max(40, slot.implicitHeight + 8, hintText.visible ? 46 : 0)
        Column {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - slot.width - 12
            Label { text: label }
            Hint { id: hintText; visible: hint !== ""; text: hint; width: parent.width }
        }
        Row { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6 }
    }
    component Toggle: Rectangle {
        property bool on: false
        signal toggled(bool value)
        width: 44; height: 24; radius: 12
        color: on ? Theme.accent : Theme.bg3
        Rectangle { x: parent.on ? parent.width - width - 3 : 3; y: 3; width: 18; height: 18; radius: 9; color: Theme.fg
            Behavior on x { NumberAnimation { duration: 120 } } }
        MouseArea { anchors.fill: parent; onClicked: parent.toggled(!parent.on) }
    }
    component Num: Slider {
        id: s
        property int decimals: 0
        signal changed(real value)
        width: 200; height: 24
        stepSize: decimals > 0 ? 0.05 : 1
        onMoved: changed(value)
        background: Rectangle {
            x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - 2
            width: s.availableWidth; height: 4; radius: 2; color: Theme.bg3
            Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
        }
        handle: Rectangle {
            x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
            y: s.topPadding + s.availableHeight / 2 - height / 2
            width: 14; height: 14; radius: 7; color: Theme.fg
        }
    }
    component NumRow: Row {
        property alias value: num.value
        property alias from: num.from
        property alias to: num.to
        property alias decimals: num.decimals
        property string unit: ""
        signal changed(real value)
        spacing: 8
        Num { id: num; onChanged: v => parent.changed(v) }
        Label { width: 52; horizontalAlignment: Text.AlignRight; text: (num.decimals > 0 ? num.value.toFixed(2) : Math.round(num.value)) + unit; anchors.verticalCenter: parent.verticalCenter }
    }
    component Field: Rectangle {
        property alias text: input.text
        property string placeholder: ""
        signal accepted(string value)
        width: 220; height: 28; radius: Theme.radius; color: Theme.bg3
        border.color: input.activeFocus ? Theme.accent : "transparent"; border.width: 1
        TextInput {
            id: input
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize
            clip: true
            onEditingFinished: parent.accepted(text)
            Text { visible: input.text === "" && !input.activeFocus; anchors.verticalCenter: parent.verticalCenter; text: placeholder; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize }
        }
    }
    component Btn: BarButton {
        property string label
        property bool primary: false
        padding: 12; implicitHeight: 30
        color: primary ? Theme.accent : (hovered ? "#2affffff" : Theme.bg3)
        BarText { text: label; font.pointSize: Theme.smallSize; color: primary ? "#1b1e20" : Theme.fg }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 820; height: 600
        radius: 8
        color: Theme.panelBg
        border.color: Theme.cardBorder; border.width: 1
        MouseArea { anchors.fill: parent }

        // ---------- sidebar tabs ----------
        Rectangle {
            id: nav
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 1
            width: 210
            radius: 8; color: "#14ffffff"
            Column {
                anchors.fill: parent; anchors.margins: 10; spacing: 4
                Heading { text: "Settings"; leftPadding: 8; topPadding: 6 }
                Repeater {
                    model: win.tabs
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 36
                        radius: Theme.radius
                        color: win.tab === modelData.id ? "#403daee9" : (tm.containsMouse ? "#2affffff" : "transparent")
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; spacing: 10
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.glyph; color: win.tab === modelData.id ? Theme.accent : Theme.fgDim; font.family: Theme.font; font.pointSize: 13 }
                            Label { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.pointSize: Theme.smallSize }
                        }
                        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; onClicked: win.tab = modelData.id }
                    }
                }
            }
            Column {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: 10; spacing: 6
                Hint { width: parent.width; text: Settings.hasOverrides ? "Overrides active (state file)" : "Using Nix defaults" }
                Btn { width: parent.width; label: "󰆏  Export as Nix"; onClicked: Settings.exportNix() }
                Btn { width: parent.width; label: "󰜉  Reset to defaults"; visible: Settings.hasOverrides; onClicked: Settings.reset() }
            }
        }

        // ---------- pages ----------
        Flickable {
            anchors.left: nav.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 20
            contentHeight: page.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: page
                width: parent.width
                spacing: 2

                // ===== appearance =====
                Column {
                    visible: win.tab === "appearance"
                    width: parent.width; spacing: 2
                    Heading { text: "Appearance" }
                    Row_ {
                        label: "Accent colour"; hint: "Used for the active workspace, sliders, highlights"
                        Repeater {
                            model: ["#3daee9", "#27ae60", "#f6c744", "#f67400", "#da4453", "#9b59b6", "#1abc9c", "#fcfcfc"]
                            Rectangle {
                                required property string modelData
                                width: 24; height: 24; radius: 12; color: modelData
                                border.color: Theme.fg; border.width: Settings.s.appearance.accent.toLowerCase() === modelData ? 2 : 0
                                MouseArea { anchors.fill: parent; onClicked: Settings.set("appearance.accent", modelData) }
                            }
                        }
                        Field { width: 90; text: Settings.s.appearance.accent; onAccepted: v => { if (/^#[0-9a-fA-F]{6}$/.test(v)) Settings.set("appearance.accent", v.toLowerCase()) } }
                    }
                    Row_ { label: "Panel opacity"
                        NumRow { from: 0.3; to: 1; decimals: 2; value: Settings.s.appearance.panelOpacity; onChanged: v => Settings.set("appearance.panelOpacity", Math.round(v * 100) / 100) } }
                    Row_ { label: "Bar height"; hint: "Popups and OSD follow it"
                        NumRow { from: 26; to: 48; value: Settings.s.appearance.barHeight; unit: " px"; onChanged: v => Settings.set("appearance.barHeight", Math.round(v)) } }
                    Row_ { label: "Corner radius"
                        NumRow { from: 0; to: 12; value: Settings.s.appearance.radius; unit: " px"; onChanged: v => Settings.set("appearance.radius", Math.round(v)) } }
                    Row_ { label: "Font size"
                        NumRow { from: 8; to: 14; value: Settings.s.appearance.fontSize; unit: " pt"; onChanged: v => Settings.set("appearance.fontSize", Math.round(v)) } }
                    Row_ { label: "Font family"
                        Field { text: Settings.s.appearance.font; onAccepted: v => { if (v.trim() !== "") Settings.set("appearance.font", v.trim()) } } }
                    Row_ { label: "Wallpaper"; hint: "Use the picker in the control center; this shows the current path"
                        Hint { width: 300; elide: Text.ElideLeft; text: Wallpaper.current; horizontalAlignment: Text.AlignRight } }
                }

                // ===== bar widgets =====
                Column {
                    visible: win.tab === "bar"
                    width: parent.width; spacing: 2
                    Heading { text: "Bar widgets" }
                    Hint { width: parent.width; text: "Right side of the bar, in order. Hidden widgets keep their popups reachable by keybind."; bottomPadding: 6 }
                    Repeater {
                        model: [
                            { k: "tray", l: "System tray" }, { k: "layout", l: "Keyboard layout" }, { k: "volume", l: "Volume" },
                            { k: "bluetooth", l: "Bluetooth" }, { k: "battery", l: "Peripheral batteries" }, { k: "cpu", l: "CPU sparkline" },
                            { k: "memory", l: "Memory sparkline" }, { k: "temps", l: "Temperatures" }, { k: "disk", l: "Disk usage" },
                            { k: "network", l: "Network rate" }, { k: "notifications", l: "Notification bell" }, { k: "control", l: "Control center button" },
                            { k: "sidebar", l: "Sidebar button" }
                        ]
                        Row_ {
                            required property var modelData
                            label: modelData.l
                            Toggle { on: Settings.s.bar[modelData.k]; onToggled: v => Settings.set("bar." + modelData.k, v) }
                        }
                    }
                }

                // ===== clock & media =====
                Column {
                    visible: win.tab === "clock"
                    width: parent.width; spacing: 2
                    Heading { text: "Clock & now playing" }
                    Row_ { label: "Time format"; hint: "Qt format: HH:mm, hh:mm AP, HH:mm:ss"
                        Field { width: 140; text: Settings.s.bar.clockFormat; onAccepted: v => { if (v.trim() !== "") Settings.set("bar.clockFormat", v.trim()) } } }
                    Row_ { label: "Date format"; hint: "ddd d MMM, dd.MM.yyyy, or empty to hide"
                        Field { width: 140; text: Settings.s.bar.dateFormat; onAccepted: v => Settings.set("bar.dateFormat", v.trim()) } }
                    Row_ { label: "Show now playing in the bar"
                        Toggle { on: Settings.s.bar.nowPlaying; onToggled: v => Settings.set("bar.nowPlaying", v) } }
                    Row_ { label: "Title width before scrolling"
                        NumRow { from: 100; to: 500; value: Settings.s.bar.marqueeWidth; unit: " px"; onChanged: v => Settings.set("bar.marqueeWidth", Math.round(v)) } }
                }

                // ===== quick launch =====
                Column {
                    visible: win.tab === "launch"
                    width: parent.width; spacing: 6
                    Heading { text: "Quick launch" }
                    Hint { width: parent.width; text: "Desktop entry ids shown in the sidebar. Type an id (e.g. org.kde.dolphin, kitty) or an app name and press Enter." }
                    Row {
                        spacing: 6
                        Field { id: addField; width: 320; placeholder: "app id or name…"; onAccepted: v => {} }
                        Btn { label: "Add"; primary: true; onClicked: win.addPinned(addField.text) }
                    }
                    Repeater {
                        model: Settings.s.pinned
                        Rectangle {
                            required property string modelData
                            required property int index
                            readonly property var e: win.entryFor(modelData)
                            width: parent.width; height: 34
                            radius: Theme.radius; color: "#12ffffff"
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4; spacing: 8
                                Image { anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; source: Quickshell.iconPath(e ? e.icon : "", "application-x-executable"); sourceSize: Qt.size(40, 40) }
                                Label { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28 - 200; elide: Text.ElideRight; text: (e ? e.name : "(not found)") + "   "; font.pointSize: Theme.smallSize }
                                Hint { anchors.verticalCenter: parent.verticalCenter; width: 110; elide: Text.ElideRight; text: modelData }
                                Btn { padding: 6; implicitHeight: 24; label: "󰅃"; onClicked: win.movePinned(index, -1) }
                                Btn { padding: 6; implicitHeight: 24; label: "󰅀"; onClicked: win.movePinned(index, 1) }
                                Btn { padding: 6; implicitHeight: 24; label: "󰅖"; onClicked: win.removePinned(index) }
                            }
                        }
                    }
                }

                // ===== misc =====
                Column {
                    visible: win.tab === "misc"
                    width: parent.width; spacing: 2
                    Heading { text: "Weather" }
                    Row_ { label: "City"; hint: "Open-Meteo place name"
                        Field { text: Settings.s.weather.city; onAccepted: v => { if (v.trim() !== "") { Settings.set("weather.city", v.trim()); Weather.setCity(v.trim()) } } } }
                    Heading { text: "Volume OSD"; topPadding: 12 }
                    Row_ { label: "Hide after"
                        NumRow { from: 500; to: 4000; value: Settings.s.osd.timeoutMs; unit: " ms"; onChanged: v => Settings.set("osd.timeoutMs", Math.round(v / 100) * 100) } }
                    Row_ { label: "Distance from bottom"
                        NumRow { from: 20; to: 300; value: Settings.s.osd.bottomMargin; unit: " px"; onChanged: v => Settings.set("osd.bottomMargin", Math.round(v)) } }
                    Heading { text: "Notifications"; topPadding: 12 }
                    Row_ { label: "Popup timeout"; hint: "Critical ones stay until dismissed"
                        NumRow { from: 2000; to: 15000; value: Settings.s.notifications.timeoutMs; unit: " ms"; onChanged: v => Settings.set("notifications.timeoutMs", Math.round(v / 500) * 500) } }
                    Row_ { label: "Max popups on screen"
                        NumRow { from: 1; to: 10; value: Settings.s.notifications.maxPopups; onChanged: v => Settings.set("notifications.maxPopups", Math.round(v)) } }
                }
            }
        }

        BarButton {
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
            padding: 6; implicitHeight: 26
            BarText { text: "󰅖"; color: Theme.fgDim }
            onClicked: Launcher.settingsOpen = false
        }
    }

    // ---------- pinned helpers ----------
    readonly property var apps: DesktopEntries.applications.values
    function entryFor(id) {
        const l = id.toLowerCase()
        return apps.find(e => e.id.toLowerCase() === l) || apps.find(e => e.id.toLowerCase().endsWith("." + l) || l.endsWith("." + e.id.toLowerCase()))
            || apps.find(e => e.name.toLowerCase() === l) || null
    }
    function addPinned(text) {
        const e = entryFor(text.trim())
        if (!e) return
        if (Settings.s.pinned.indexOf(e.id) >= 0) return
        Settings.set("pinned", Settings.s.pinned.concat([e.id]))
    }
    function removePinned(i) { Settings.set("pinned", Settings.s.pinned.filter((_, k) => k !== i)) }
    function movePinned(i, d) {
        const a = Settings.s.pinned.slice(); const j = i + d
        if (j < 0 || j >= a.length) return
        const t = a[i]; a[i] = a[j]; a[j] = t
        Settings.set("pinned", a)
    }
}
