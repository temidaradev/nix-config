import QtQuick
import Quickshell
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "buds"
    anchorX: Launcher.menuAnchorX
    panelWidth: 400
    padding: 14
    panelColor: n.black
    panelBorder: n.line
    panelRadius: 22
    onDismissed: Launcher.menu = ""
    Component.onCompleted: Buds.refresh()

    readonly property var s: Buds.state
    readonly property var levels: ["high", "mid", "low", "adaptive"]
    readonly property bool nc: levels.includes(s.anc)
    property bool showGestures: false

    QtObject {
        id: n
        readonly property color black: "#000000"
        readonly property color surface: "#111111"
        readonly property color raised: "#1c1c1c"
        readonly property color line: "#262626"
        readonly property color white: "#ffffff"
        readonly property color dim: "#8a8a8a"
        readonly property color red: "#d71921"
    }

    readonly property var actionLabels: ({
        off: "No action", playpause: "Play / pause", next: "Next track", previous: "Previous track",
        assistant: "Voice assistant", volup: "Volume up", voldown: "Volume down",
        anc_cycle: "ANC · Transparency · Off", anc_transparency: "ANC · Transparency",
        anc_off: "ANC · Off", transparency_off: "Transparency · Off"
    })
    readonly property var gestureActions: ({
        tap2: ["playpause", "next", "previous", "assistant", "volup", "voldown", "off"],
        tap3: ["playpause", "next", "previous", "assistant", "volup", "voldown", "off"],
        hold: ["anc_cycle", "anc_transparency", "anc_off", "transparency_off", "assistant", "off"],
        tap2hold: ["volup", "voldown", "assistant", "off"]
    })
    readonly property var gestureLabels: ({ tap2: "Double tap", tap3: "Triple tap", hold: "Tap & hold", tap2hold: "Double tap & hold" })

    component Caps: Text {
        color: n.dim
        font.family: Theme.font; font.pointSize: Theme.smallSize - 1
        font.capitalization: Font.AllUppercase; font.letterSpacing: 1.5
    }
    component Body: Text {
        color: n.white
        font.family: Theme.font; font.pointSize: Theme.smallSize
    }
    component Card: Rectangle {
        default property alias content: inner.data
        width: parent.width
        implicitHeight: inner.implicitHeight + 28
        radius: 16
        color: n.surface
        Column {
            id: inner
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 14
            spacing: 12
        }
    }
    component Pill: Rectangle {
        id: pill
        property string label
        property bool on: false
        property color onColor: n.white
        signal clicked(var e)
        implicitWidth: pillText.implicitWidth + 26
        implicitHeight: 32
        radius: height / 2
        color: on ? onColor : pillMouse.containsMouse ? n.raised : "transparent"
        border.color: on ? onColor : n.line; border.width: 1
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: 120 } }
        Text {
            id: pillText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, pill.width - 12)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            text: pill.label
            color: pill.on ? (pill.onColor === n.white ? n.black : n.white) : n.white
            font.family: Theme.font; font.pointSize: Theme.smallSize - 1
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => pill.clicked(e)
        }
    }
    component Seg: Row {
        id: seg
        property var options: []
        property string current
        signal picked(string key)
        width: parent.width
        spacing: 6
        Repeater {
            model: seg.options
            Pill {
                required property var modelData
                width: (seg.width - seg.spacing * (seg.options.length - 1)) / seg.options.length
                label: modelData[1]
                on: seg.current === modelData[0]
                onClicked: seg.picked(modelData[0])
            }
        }
    }
    component Switch: Rectangle {
        id: sw
        property bool on: false
        signal toggled(bool value)
        width: 44; height: 24; radius: 12
        color: on ? n.red : n.raised
        border.color: on ? n.red : n.line; border.width: 1
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: 140 } }
        Rectangle {
            x: sw.on ? sw.width - width - 4 : 4
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16; radius: 8
            color: n.white
            Behavior on x { enabled: !Theme.reducedMotion; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled(!sw.on) }
    }
    component Toggle: Item {
        id: tg
        property string label
        property string sub: ""
        property bool on: false
        signal toggled(bool value)
        width: parent.width
        implicitHeight: Math.max(28, tgCol.implicitHeight)
        Column {
            id: tgCol
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 56
            spacing: 2
            Body { width: parent.width; elide: Text.ElideRight; text: tg.label }
            Caps { visible: tg.sub !== ""; width: parent.width; elide: Text.ElideRight; text: tg.sub; font.letterSpacing: 0.5; font.capitalization: Font.MixedCase }
        }
        Switch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: tg.on; onToggled: v => tg.toggled(v) }
    }
    component Pod: Rectangle {
        id: pod
        property string label
        property var info: null
        readonly property int pct: info ? info.level : -1
        readonly property bool low: pct >= 0 && pct < 20
        width: (parent.width - 16) / 3
        implicitHeight: podCol.implicitHeight + 28
        radius: 16
        color: n.surface
        Column {
            id: podCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 14
            spacing: 10
            Row {
                spacing: 6
                Caps { text: pod.label; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    visible: pod.info?.charging ?? false
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3; color: n.red
                    SequentialAnimation on opacity {
                        running: parent.visible && !Theme.reducedMotion
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 700 }
                        NumberAnimation { to: 1; duration: 700 }
                    }
                }
            }
            Row {
                spacing: 4
                DotText {
                    text: pod.pct >= 0 ? String(pod.pct) : "--"
                    dot: 3.4; gap: 1.2
                    color: pod.pct < 0 ? n.line : pod.low ? n.red : n.white
                    offColor: "transparent"
                }
                Text {
                    visible: pod.pct >= 0
                    anchors.bottom: parent.bottom; anchors.bottomMargin: -2
                    text: "%"; color: n.dim
                    font.family: Theme.font; font.pointSize: Theme.smallSize - 1
                }
            }
            Row {
                spacing: 3
                Repeater {
                    model: 10
                    Rectangle {
                        required property int index
                        width: 4; height: 4; radius: 2
                        color: pod.pct >= 0 && index < Math.round(pod.pct / 10) ? (pod.low ? n.red : n.white) : n.line
                    }
                }
            }
        }
    }

    Item {
        width: parent.width
        implicitHeight: headCol.implicitHeight
        Column {
            id: headCol
            anchors.left: parent.left; anchors.right: refresh.left
            spacing: 4
            Row {
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: Buds.connected ? n.red : n.line
                }
                Text {
                    text: (pop.s.name || "CMF Buds Pro 2").toUpperCase()
                    color: n.white
                    font.family: Theme.font; font.pointSize: Theme.fontSize + 2; font.bold: true; font.letterSpacing: 2
                }
            }
            Caps {
                leftPadding: 16
                text: Buds.connected ? "Connected" + (pop.s.firmware ? "  ·  FW " + pop.s.firmware : "") : "Not connected"
            }
        }
        Pill {
            id: refresh
            visible: Buds.connected
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 32; label: "󰑐"
            onClicked: Buds.refresh()
        }
    }

    Card {
        visible: !Buds.connected
        Body { width: parent.width; wrapMode: Text.WordWrap; color: n.dim; text: "Take the buds out of the case and connect them over Bluetooth. Controls appear here once the control channel is open." }
        Pill { label: "󰂯  Bluetooth"; onClicked: { const x = Launcher.menuAnchorX; Launcher.toggleMenu("bluetooth", x) } }
    }

    Row {
        visible: Buds.connected
        width: parent.width
        spacing: 8
        Pod { label: "Left"; info: Buds.battery.left ?? null }
        Pod { label: "Right"; info: Buds.battery.right ?? null }
        Pod { label: "Case"; info: Buds.battery.case ?? null }
    }

    Card {
        visible: Buds.connected && pop.s.anc !== null
        Caps { text: "Noise control" }
        Seg {
            options: [["nc", "ANC"], ["transparency", "Transparency"], ["off", "Off"]]
            current: pop.nc ? "nc" : (pop.s.anc ?? "")
            onPicked: k => Buds.setAnc(k === "nc" ? (pop.s.ancLevel || "high") : k)
        }
        Seg {
            visible: pop.nc
            options: [["high", "High"], ["mid", "Mid"], ["low", "Low"], ["adaptive", "Adaptive"]]
            current: pop.s.anc ?? ""
            onPicked: k => Buds.setAnc(k)
        }
    }

    Card {
        visible: Buds.connected && pop.s.eq !== null
        Caps { text: "Equaliser" }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: [["dirac", "Dirac Opteo"], ["pop", "Pop"], ["rock", "Rock"], ["electronic", "Electronic"], ["vocals", "Enhance vocals"], ["classical", "Classical"], ["custom", "Custom"]]
                Pill {
                    required property var modelData
                    label: modelData[1]
                    on: pop.s.eq === modelData[0]
                    onClicked: Buds.setEq(modelData[0])
                }
            }
        }
    }

    Card {
        visible: Buds.connected && pop.s.bass !== null
        Toggle {
            label: "Ultra Bass"
            sub: pop.s.bass?.enabled ? "Level " + pop.s.bass.level : "Off"
            on: pop.s.bass?.enabled ?? false
            onToggled: v => Buds.setBass(v, pop.s.bass?.level ?? 3)
        }
        Row {
            visible: pop.s.bass?.enabled ?? false
            width: parent.width
            spacing: 6
            Repeater {
                model: 5
                Rectangle {
                    id: step
                    required property int index
                    readonly property bool lit: index < (pop.s.bass?.level ?? 0)
                    width: (parent.width - 24) / 5; height: 10; radius: 5
                    color: lit ? n.white : stepMouse.containsMouse ? n.raised : n.black
                    border.color: lit ? n.white : n.line; border.width: 1
                    MouseArea {
                        id: stepMouse
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Buds.setBass(true, step.index + 1)
                    }
                }
            }
        }
    }

    Card {
        visible: Buds.connected && (pop.s.inEar !== null || pop.s.lowLatency !== null || pop.s.spatial !== null)
        Caps { text: "Settings" }
        Toggle { visible: pop.s.inEar !== null; label: "In-ear detection"; sub: "Pause when a bud is removed"; on: pop.s.inEar ?? false; onToggled: v => Buds.setInEar(v) }
        Toggle { visible: pop.s.lowLatency !== null; label: "Low lag mode"; sub: "Lower latency for games"; on: pop.s.lowLatency ?? false; onToggled: v => Buds.setLowLatency(v) }
        Toggle { visible: pop.s.spatial !== null; label: "Spatial audio"; sub: "Wider soundstage"; on: pop.s.spatial ?? false; onToggled: v => Buds.setSpatial(v) }
    }

    Card {
        visible: Buds.connected && Object.keys(pop.s.gestures || {}).length > 0
        Item {
            width: parent.width
            implicitHeight: 18
            Caps { text: "Gestures"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: pop.showGestures ? "󰅃" : "󰅀"; color: n.dim
                font.family: Theme.font; font.pointSize: Theme.fontSize
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.showGestures = !pop.showGestures }
        }
        Repeater {
            model: pop.showGestures ? ["left", "right"] : []
            Column {
                id: sideCol
                required property string modelData
                width: parent.width
                spacing: 6
                Caps { text: sideCol.modelData; color: n.white }
                Repeater {
                    model: ["tap2", "tap3", "hold", "tap2hold"].filter(k => (pop.s.gestures[sideCol.modelData] || {})[k] !== undefined)
                    Item {
                        id: gRow
                        required property string modelData
                        readonly property string current: pop.s.gestures[sideCol.modelData][modelData]
                        readonly property var choices: pop.gestureActions[modelData]
                        width: parent.width
                        implicitHeight: 32
                        Body { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: pop.gestureLabels[gRow.modelData]; color: n.dim }
                        Pill {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: 190
                            label: (pop.actionLabels[gRow.current] ?? gRow.current) + "  󰁔"
                            onClicked: e => {
                                const i = gRow.choices.indexOf(gRow.current)
                                const step = e.button === Qt.RightButton ? -1 : 1
                                const next = gRow.choices[(i + step + gRow.choices.length) % gRow.choices.length]
                                Buds.setGesture(sideCol.modelData, gRow.modelData, next)
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        visible: Buds.connected
        spacing: 6
        Pill {
            label: pop.s.finding ? "󰓃  Stop ringing" : "󰓃  Find my buds"
            on: pop.s.finding ?? false
            onColor: n.red
            onClicked: Buds.find(!pop.s.finding)
        }
        Pill { label: "󰂯  Bluetooth"; onClicked: { const x = Launcher.menuAnchorX; Launcher.toggleMenu("bluetooth", x) } }
    }
}
