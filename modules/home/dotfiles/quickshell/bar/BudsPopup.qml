import QtQuick
import Quickshell
import qs
import qs.services

// CMF Buds Pro 2 controls, styled like the other bar popups.
BarPopup {
    id: popup
    visible: Launcher.menu === "buds"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""
    Component.onCompleted: Buds.refresh()

    readonly property var s: Buds.state
    readonly property var levels: ["high", "mid", "low", "adaptive"]
    readonly property bool nc: levels.includes(s.anc)
    property bool showGestures: false

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

    function podText(p) { return p ? (p.charging ? "󰂄 " : "") + p.level + "%" : "—" }

    component Choice: Row {
        id: ch
        property var options: []
        property string current
        signal picked(string key)
        width: parent.width
        spacing: 4
        Repeater {
            model: ch.options
            PopupButton {
                required property var modelData
                width: (ch.width - ch.spacing * (ch.options.length - 1)) / ch.options.length
                label: modelData[1]
                on: ch.current === modelData[0]
                onClicked: ch.picked(modelData[0])
            }
        }
    }
    // One battery cell: label, meter, value.
    component Cell: Column {
        id: cell
        property string label
        property var pod: null
        width: (parent.width - 2 * 10) / 3
        spacing: 4
        Item {
            width: parent.width; implicitHeight: cellLabel.implicitHeight
            Text { id: cellLabel; text: cell.label; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
            Text {
                anchors.right: parent.right
                text: popup.podText(cell.pod)
                color: cell.pod && cell.pod.level < 20 ? Theme.red : Theme.fg
                font.family: Theme.font; font.pointSize: Theme.smallSize - 1
            }
        }
        PopupMeter {
            pct: cell.pod ? cell.pod.level : 0
            accent: cell.pod && cell.pod.level < 20 ? Theme.red : cell.pod?.charging ? Theme.green : Theme.accent
            opacity: cell.pod ? 1 : 0.4
        }
    }

    PopupTitle {
        glyph: "󱡏"
        glyphColor: Buds.connected ? Theme.accent : Theme.fgDim
        text: popup.s.name || "CMF Buds Pro 2"
        sub: !Buds.connected ? "Not connected" : popup.s.firmware ? "FW " + popup.s.firmware : "Connected"
        PopupButton { visible: Buds.connected; label: "󰑐"; onClicked: Buds.refresh() }
    }
    Text {
        visible: !Buds.connected
        width: parent.width; wrapMode: Text.WordWrap
        text: "Take the buds out of the case and connect them over Bluetooth."
        color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
    }

    Row {
        visible: Buds.connected
        width: parent.width; spacing: 10
        Cell { label: "Left"; pod: Buds.battery.left ?? null }
        Cell { label: "Right"; pod: Buds.battery.right ?? null }
        Cell { label: "Case"; pod: Buds.battery.case ?? null }
    }

    // ── Noise control
    PopupSection { visible: Buds.connected && popup.s.anc !== null; text: "Noise control" }
    Choice {
        visible: Buds.connected && popup.s.anc !== null
        options: [["nc", "󰋎  Cancel"], ["transparency", "󰟅  Transparent"], ["off", "Off"]]
        current: popup.nc ? "nc" : (popup.s.anc ?? "")
        onPicked: k => Buds.setAnc(k === "nc" ? (popup.s.ancLevel || "high") : k)
    }
    Choice {
        visible: Buds.connected && popup.nc
        options: [["high", "High"], ["mid", "Mid"], ["low", "Low"], ["adaptive", "Adaptive"]]
        current: popup.s.anc ?? ""
        onPicked: k => Buds.setAnc(k)
    }

    // ── Equaliser
    PopupSection { visible: Buds.connected && popup.s.eq !== null; text: "Equaliser" }
    Flow {
        visible: Buds.connected && popup.s.eq !== null
        width: parent.width; spacing: 4
        Repeater {
            model: [["dirac", "Dirac Opteo"], ["pop", "Pop"], ["rock", "Rock"], ["electronic", "Electronic"], ["vocals", "Enhance vocals"], ["classical", "Classical"], ["custom", "Custom"]]
            PopupButton {
                required property var modelData
                label: modelData[1]
                on: popup.s.eq === modelData[0]
                onClicked: Buds.setEq(modelData[0])
            }
        }
    }
    PopupToggle {
        visible: Buds.connected && popup.s.bass !== null
        label: "Ultra Bass"
        sub: popup.s.bass?.enabled ? "Level " + popup.s.bass.level : "Off"
        on: popup.s.bass?.enabled ?? false
        onToggled: v => Buds.setBass(v, popup.s.bass?.level ?? 3)
    }
    Choice {
        visible: Buds.connected && (popup.s.bass?.enabled ?? false)
        options: [["1", "1"], ["2", "2"], ["3", "3"], ["4", "4"], ["5", "5"]]
        current: String(popup.s.bass?.level ?? "")
        onPicked: k => Buds.setBass(true, Number(k))
    }

    // ── Settings
    PopupSection { visible: Buds.connected && (popup.s.inEar !== null || popup.s.lowLatency !== null || popup.s.spatial !== null); text: "Settings" }
    Column {
        visible: Buds.connected
        width: parent.width; spacing: 6
        PopupToggle { visible: popup.s.inEar !== null; label: "In-ear detection"; sub: "Pause when a bud is removed"; on: popup.s.inEar ?? false; onToggled: v => Buds.setInEar(v) }
        PopupToggle { visible: popup.s.lowLatency !== null; label: "Low lag mode"; sub: "Lower latency for games"; on: popup.s.lowLatency ?? false; onToggled: v => Buds.setLowLatency(v) }
        PopupToggle { visible: popup.s.spatial !== null; label: "Spatial audio"; sub: "Wider soundstage"; on: popup.s.spatial ?? false; onToggled: v => Buds.setSpatial(v) }
    }

    // ── Gestures
    Item {
        visible: Buds.connected && Object.keys(popup.s.gestures || {}).length > 0
        width: parent.width; implicitHeight: gHead.implicitHeight
        PopupSection { id: gHead; text: "Gestures" }
        Text {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            text: popup.showGestures ? "󰅃" : "󰅀"; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: popup.showGestures = !popup.showGestures }
    }
    Repeater {
        model: Buds.connected && popup.showGestures ? ["left", "right"] : []
        Column {
            id: sideCol
            required property string modelData
            width: parent.width; spacing: 4
            Text { text: sideCol.modelData === "left" ? "Left" : "Right"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
            Repeater {
                model: ["tap2", "tap3", "hold", "tap2hold"].filter(k => (popup.s.gestures[sideCol.modelData] || {})[k] !== undefined)
                Item {
                    id: gRow
                    required property string modelData
                    readonly property string current: popup.s.gestures[sideCol.modelData][modelData]
                    readonly property var choices: popup.gestureActions[modelData]
                    width: parent.width; implicitHeight: 30
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: popup.gestureLabels[gRow.modelData]; color: Theme.fg
                        font.family: Theme.font; font.pointSize: Theme.smallSize
                    }
                    PopupButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        label: (popup.actionLabels[gRow.current] ?? gRow.current) + "  󰁔"
                        onClicked: e => {
                            const i = gRow.choices.indexOf(gRow.current)
                            const step = e.button === Qt.RightButton ? -1 : 1
                            Buds.setGesture(sideCol.modelData, gRow.modelData, gRow.choices[(i + step + gRow.choices.length) % gRow.choices.length])
                        }
                    }
                }
            }
        }
    }

    Row {
        spacing: 6; topPadding: 4
        PopupButton {
            visible: Buds.connected
            label: popup.s.finding ? "󰓃  Stop ringing" : "󰓃  Find my buds"
            danger: true; on: false
            color: popup.s.finding ? Theme.red : hovered ? "#2affffff" : Theme.bg2
            onClicked: Buds.find(!popup.s.finding)
        }
        PopupButton { label: "󰕾  Sound"; onClicked: Launcher.toggleMenu("volume", Launcher.menuAnchorX) }
        PopupButton { label: "󰂯  Bluetooth"; onClicked: Launcher.toggleMenu("bluetooth", Launcher.menuAnchorX) }
    }
}
