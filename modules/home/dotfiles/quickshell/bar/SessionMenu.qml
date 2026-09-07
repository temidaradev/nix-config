import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Big-button session menu: lock, suspend, logout, reboot, shutdown.
// Arrow keys / Enter / Escape work; click outside closes.
PanelWindow {
    id: win
    visible: Launcher.sessionOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "#a01b1e20"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-session"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int current: 0
    onVisibleChanged: if (visible) { current = 0; keys.forceActiveFocus() }

    readonly property var actions: [
        { glyph: "󰌾", label: "Lock",     run: () => { Launcher.sessionOpen = false; Lock.lock() } },
        { glyph: "󰤄", label: "Suspend",  run: () => { Launcher.sessionOpen = false; Quickshell.execDetached(["sh", "-c", "qs ipc call lock lock; systemctl suspend"]) } },
        { glyph: "󰍃", label: "Log out",  run: () => Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]) },
        { glyph: "󰜉", label: "Reboot",   run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { glyph: "⏻", label: "Shut down", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]

    MouseArea { anchors.fill: parent; onClicked: Launcher.sessionOpen = false }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Launcher.sessionOpen = false
        Keys.onLeftPressed: win.current = (win.current + win.actions.length - 1) % win.actions.length
        Keys.onRightPressed: win.current = (win.current + 1) % win.actions.length
        Keys.onTabPressed: win.current = (win.current + 1) % win.actions.length
        Keys.onReturnPressed: win.actions[win.current].run()
        Keys.onEnterPressed: win.actions[win.current].run()
        Keys.onPressed: e => {
            const map = { l: 0, s: 1, e: 2, r: 3, p: 4 }
            const k = e.text.toLowerCase()
            if (map[k] !== undefined) { win.actions[map[k]].run(); e.accepted = true }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 24
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Quickshell.env("USER") + "@" + Niri.hostname
            color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.fontSize + 2
        }
        Row {
            spacing: 18
            Repeater {
                model: win.actions
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.current
                    width: 150; height: 150
                    radius: 12
                    color: sel ? Theme.accent : Theme.panelBg
                    border.color: sel ? Theme.accent : Theme.cardBorder; border.width: 1
                    scale: sel ? 1.04 : 1
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    Column {
                        anchors.centerIn: parent; spacing: 10
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.glyph; color: sel ? "#1b1e20" : Theme.fg; font.family: Theme.font; font.pointSize: 40 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: sel ? "#1b1e20" : Theme.fg; font.bold: sel; font.family: Theme.font; font.pointSize: Theme.fontSize }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: win.current = index
                        onClicked: modelData.run()
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "L · S · E · R · P   or arrows + Enter   ·   Esc to close"
            color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
        }
    }
}
