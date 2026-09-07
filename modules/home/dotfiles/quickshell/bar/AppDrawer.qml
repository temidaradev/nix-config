import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import qs
import qs.services

// Kickoff-style app drawer: search box, app list, session buttons.
// Covers the whole screen (transparent) so a click outside closes it.
PanelWindow {
    id: win
    visible: Launcher.open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: Launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string query: ""
    property int current: 0
    readonly property bool calcMode: query.startsWith("=")
    readonly property bool runMode: query.startsWith(":")
    property string calcResult: ""

    Process {
        id: qalc
        command: ["qalc", "-t", win.query.slice(1)]
        stdout: StdioCollector { onStreamFinished: win.calcResult = text.trim() }
    }
    Timer { id: calcDebounce; interval: 120; onTriggered: if (win.calcMode && win.query.length > 1) qalc.running = true }

    readonly property var apps: {
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        all.sort((a, b) => a.name.localeCompare(b.name))
        const q = query.trim().toLowerCase()
        if (q === "") return all
        const score = e => {
            const n = e.name.toLowerCase()
            if (n.startsWith(q)) return 0
            if (n.includes(q)) return 1
            if ((e.genericName || "").toLowerCase().includes(q)) return 2
            if ((e.comment || "").toLowerCase().includes(q)) return 3
            if ((e.keywords || []).some(k => k.toLowerCase().includes(q))) return 4
            return -1
        }
        return all.map(e => ({ e, s: score(e) })).filter(x => x.s >= 0)
                  .sort((a, b) => a.s - b.s).map(x => x.e)
    }

    onVisibleChanged: if (visible) { query = ""; current = 0; search.text = ""; search.forceActiveFocus() }
    onQueryChanged: { current = 0; if (calcMode) calcDebounce.restart(); else calcResult = "" }

    function launch(entry) {
        if (!entry) return
        entry.execute()
        Launcher.hide()
    }
    function run(cmd) { Quickshell.execDetached(cmd); Launcher.hide() }
    function submit() {
        if (calcMode) { if (calcResult !== "") run(["sh", "-c", "printf %s " + JSON.stringify(calcResult) + " | wl-copy"]) }
        else if (runMode) { const c = query.slice(1).trim(); if (c !== "") run(["sh", "-c", c]) }
        else launch(apps[current])
    }

    MouseArea { anchors.fill: parent; onClicked: Launcher.hide() }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 560; height: 640
        radius: 6
        color: Theme.panelBg
        border.color: Theme.cardBorder; border.width: 1
        MouseArea { anchors.fill: parent }   // swallow clicks inside

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Rectangle {   // search box
                width: parent.width; height: 34
                radius: Theme.radius
                color: Theme.bg2
                border.color: search.activeFocus ? Theme.accent : "transparent"; border.width: 1
                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 8
                    Text { text: ""; color: Theme.fgDim; font.family: Theme.font; font.pointSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    TextInput {
                        id: search
                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                        font.family: Theme.font; font.pointSize: Theme.fontSize
                        clip: true
                        onTextChanged: win.query = text
                        Text {
                            visible: search.text === ""
                            text: "Search apps ·  =2+2 calculates ·  :cmd runs"; color: Theme.fgDim
                            font.family: Theme.font; font.pointSize: Theme.fontSize
                        }
                        Keys.onEscapePressed: Launcher.hide()
                        Keys.onDownPressed: { win.current = Math.min(win.current + 1, win.apps.length - 1); list.positionViewAtIndex(win.current, ListView.Contain) }
                        Keys.onUpPressed: { win.current = Math.max(win.current - 1, 0); list.positionViewAtIndex(win.current, ListView.Contain) }
                        Keys.onReturnPressed: win.submit()
                        Keys.onEnterPressed: win.submit()
                        Keys.onTabPressed: win.current = (win.current + 1) % Math.max(1, win.apps.length)
                    }
                }
            }

            Rectangle {   // "=" calculator / ":" command result
                visible: win.calcMode || win.runMode
                width: parent.width; height: 48
                radius: Theme.radius; color: "#403daee9"
                Row {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                    Text { anchors.verticalCenter: parent.verticalCenter; text: win.calcMode ? "󰃬" : "󰆍"; color: Theme.accent; font.family: Theme.font; font.pointSize: 16 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; width: parent.width - 40
                        Text { width: parent.width; elide: Text.ElideRight; text: win.calcMode ? (win.calcResult || "…") : win.query.slice(1).trim(); color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize + 1 }
                        Text { text: win.calcMode ? "Enter copies the result" : "Enter runs it in a shell"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: win.submit() }
            }

            ListView {
                id: list
                visible: !win.calcMode && !win.runMode
                width: parent.width
                height: parent.height - 34 - 44 - 16
                clip: true
                model: win.apps
                currentIndex: win.current
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 400
                flickDeceleration: 6000
                maximumFlickVelocity: 6000

                delegate: Rectangle {
                    required property DesktopEntry modelData
                    required property int index
                    width: list.width; height: 40
                    radius: Theme.radius
                    color: index === win.current ? "#403daee9" : (hover.containsMouse ? "#1affffff" : "transparent")
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 10
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 26
                            asynchronous: true
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: modelData.name; color: Theme.fg
                                font.family: Theme.font; font.pointSize: Theme.fontSize
                            }
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                visible: text !== ""
                                text: modelData.genericName || modelData.comment || ""
                                color: Theme.fgDim
                                font.family: Theme.font; font.pointSize: Theme.smallSize - 1
                            }
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: win.current = index   // hover only, no auto-scroll
                        onClicked: win.launch(modelData)
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#22ffffff" }

            Row {   // session controls
                width: parent.width; height: 36
                spacing: 6
                layoutDirection: Qt.RightToLeft

                component SessionButton: BarButton {
                    property string glyph
                    property string tip
                    padding: 10
                    implicitHeight: 32
                    BarText { text: glyph; font.pointSize: 13 }
                }
                SessionButton { glyph: "⏻"; onClicked: { Launcher.hide(); Launcher.toggleSession() } }
                SessionButton { glyph: "󰜉"; onClicked: win.run(["systemctl", "reboot"]) }
                SessionButton { glyph: "󰍃"; onClicked: win.run(["niri", "msg", "action", "quit", "--skip-confirmation"]) }
                SessionButton { glyph: "󰌾"; onClicked: { Launcher.hide(); Lock.lock() } }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.apps.length + " apps"
                    color: Theme.fgDim
                    font.family: Theme.font; font.pointSize: Theme.smallSize
                }
            }
        }
    }
}
