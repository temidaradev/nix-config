import QtQuick
import Quickshell
import qs
import qs.services

// AirPods controls, styled like the other bar popups.
BarPopup {
    id: pop
    visible: Launcher.menu === "airpods"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""
    Component.onCompleted: AirPods.refresh()

    readonly property var s: AirPods.state
    property bool showSettings: false
    property bool showEq: false
    property bool renaming: false
    wantsKeyboard: renaming

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
    // Horizontal slider that commits on release.
    component Level: Item {
        id: lv
        property string label
        property int value: 0
        property int from: 0
        property int to: 100
        property bool dragging: false
        property int dragValue: 0
        readonly property int shown: dragging ? dragValue : value
        signal committed(int v)
        width: parent.width; height: 22
        Text {
            id: lvLabel
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: 86; elide: Text.ElideRight
            text: lv.label; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize - 1
        }
        Rectangle {
            id: track
            anchors.left: lvLabel.right; anchors.right: num.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 4; radius: 2; color: Theme.bg3
            readonly property real frac: (lv.shown - lv.from) / (lv.to - lv.from)
            Rectangle { width: parent.width * track.frac; height: parent.height; radius: 2; color: Theme.accent }
            Rectangle {
                x: (parent.width - width) * track.frac
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7; color: Theme.fg
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -9
                cursorShape: Qt.PointingHandCursor
                function at(mx) { return Math.max(lv.from, Math.min(lv.to, Math.round(lv.from + (mx - 9) / track.width * (lv.to - lv.from)))) }
                onPressed: e => { lv.dragValue = at(e.x); lv.dragging = true }
                onPositionChanged: e => lv.dragValue = at(e.x)
                onReleased: { lv.dragging = false; lv.committed(lv.dragValue) }
            }
        }
        Text {
            id: num
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 30; horizontalAlignment: Text.AlignRight
            text: lv.shown; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize
        }
    }
    // One battery cell: label, meter, value.
    component Cell: Column {
        id: cell
        property string label
        property var pod: null
        property string ear: ""
        width: (parent.width - 2 * 10) / 3
        spacing: 4
        Item {
            width: parent.width; implicitHeight: cellLabel.implicitHeight
            Text { id: cellLabel; text: cell.label; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
            Text {
                anchors.right: parent.right
                text: AirPods.state && cell.pod ? pop.podText(cell.pod) : "—"
                color: cell.pod && cell.pod.level < 20 ? Theme.red : Theme.fg
                font.family: Theme.font; font.pointSize: Theme.smallSize - 1
            }
        }
        PopupMeter {
            pct: cell.pod ? cell.pod.level : 0
            accent: cell.pod && cell.pod.level < 20 ? Theme.red : cell.pod?.charging ? Theme.green : Theme.accent
            opacity: cell.pod ? 1 : 0.4
        }
        Text {
            visible: cell.ear !== ""
            text: cell.ear; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize - 2
        }
    }

    PopupTitle {
        glyph: "󱡏"
        glyphColor: AirPods.connected ? Theme.accent : Theme.fgDim
        text: pop.s.name || "AirPods"
        sub: !AirPods.connected ? "Not connected"
            : [pop.s.info?.model || (pop.s.model ? "0x" + pop.s.model : ""), pop.s.info?.firmware ? "FW " + pop.s.info.firmware.split(".")[0] : "", AirPods.isOutput ? "Playing here" : "Not the output"].filter(x => x).join("  ·  ")
        PopupButton { visible: AirPods.connected; label: "󰑐"; onClicked: AirPods.refresh() }
    }
    Text {
        visible: !AirPods.connected
        width: parent.width; wrapMode: Text.WordWrap
        text: "Take the AirPods out of the case and connect them over Bluetooth."
        color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
    }

    Row {
        visible: AirPods.connected
        width: parent.width; spacing: 10
        readonly property var earText: ({ ear: "In ear", out: "Out", case: "In case" })
        Cell { label: "Left"; pod: pop.s.left; ear: parent.earText[pop.s.leftEar] ?? "" }
        Cell { label: "Right"; pod: pop.s.right; ear: parent.earText[pop.s.rightEar] ?? "" }
        Cell { label: "Case"; pod: pop.s.case }
    }

    // ── Noise control
    PopupSection { visible: AirPods.connected; text: "Noise control" }
    Choice {
        visible: AirPods.connected
        options: (pop.s.offOption === false ? [] : [["off", "Off"]]).concat([["nc", "Cancel"], ["transparency", "Transparent"], ["adaptive", "Adaptive"]])
        current: pop.s.anc ?? ""
        onPicked: k => AirPods.setAnc(k)
    }
    Level {
        visible: AirPods.connected && pop.s.anc === "adaptive" && pop.s.strength !== null
        label: "Strength"
        value: pop.s.strength ?? 0
        onCommitted: v => AirPods.setStrength(v)
    }
    PopupToggle {
        visible: AirPods.connected && pop.s.conversation !== null
        label: "Conversation Awareness"; sub: "Lower media and let voices in when you talk"
        on: pop.s.conversation ?? false
        onToggled: v => AirPods.setFlag("ca", v)
    }
    PopupToggle {
        visible: AirPods.connected && pop.s.adaptiveVolume !== null
        label: "Personalised Volume"; sub: "Adjust media volume to your surroundings"
        on: pop.s.adaptiveVolume ?? false
        onToggled: v => AirPods.setFlag("advol", v)
    }
    PopupToggle {
        visible: AirPods.connected && (pop.s.conversation ?? false)
        label: "Lower volume while I talk"; sub: "Done by this computer, to " + AirPods.duckTo + "% of the volume"
        on: AirPods.duck
        onToggled: v => AirPods.setDuck(v)
    }

    // ── Equaliser
    Item {
        visible: AirPods.connected && pop.s.eq !== null
        width: parent.width; implicitHeight: eqHead.implicitHeight
        PopupSection { id: eqHead; text: "Equaliser" }
        PopupSwitch {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            scale: 0.8; transformOrigin: Item.BottomRight
            on: pop.s.eq?.on ?? false
            onToggled: v => AirPods.setEq(v)
        }
    }
    Column {
        visible: AirPods.connected && (pop.s.eq?.on ?? false)
        width: parent.width; spacing: 4
        Repeater {
            model: [["low", "Bass"], ["mid", "Mids"], ["high", "Treble"]]
            Level {
                required property var modelData
                label: modelData[1]
                value: pop.s.eq?.[modelData[0]] ?? 50
                onCommitted: v => {
                    const e = Object.assign({}, pop.s.eq, { [modelData[0]]: v })
                    AirPods.setEqBands(e.low, e.mid, e.high)
                }
            }
        }
    }

    // ── Settings
    Item {
        visible: AirPods.connected
        width: parent.width; implicitHeight: setHead.implicitHeight
        PopupSection { id: setHead; text: "Settings" }
        Text {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            text: pop.showSettings ? "󰅃" : "󰅀"; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.showSettings = !pop.showSettings }
    }
    Column {
        visible: AirPods.connected && pop.showSettings
        width: parent.width; spacing: 6
        PopupToggle { visible: pop.s.swipe !== null; label: "Volume swipe"; sub: "Swipe the stem to change volume"; on: pop.s.swipe ?? false; onToggled: v => AirPods.setFlag("swipe", v) }
        PopupToggle { visible: pop.s.oneBud !== null; label: "Noise control with one AirPod"; on: pop.s.oneBud ?? false; onToggled: v => AirPods.setFlag("onebud", v) }
        PopupToggle { visible: pop.s.offOption !== null; label: "Allow Off mode"; on: pop.s.offOption ?? false; onToggled: v => AirPods.setFlag("offoption", v) }
        PopupToggle { visible: pop.s.earDetect !== null; label: "Automatic ear detection"; on: pop.s.earDetect ?? false; onToggled: v => AirPods.setFlag("eardetect", v) }
        PopupToggle { visible: pop.s.caseTone !== null; label: "Case sounds"; on: pop.s.caseTone ?? false; onToggled: v => AirPods.setFlag("casetone", v) }
        PopupToggle { visible: pop.s.sleepDetect !== null; label: "Sleep detection"; sub: "Pause media when you fall asleep"; on: pop.s.sleepDetect ?? false; onToggled: v => AirPods.setFlag("sleep", v) }
        Text { text: "Pause media when"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        Choice {
            options: [["one", "One is out"], ["both", "Both are out"], ["off", "Never"]]
            current: AirPods.autoPause
            onPicked: k => AirPods.setAutoPause(k)
        }
        Text { visible: pop.s.pressSpeed !== null; text: "Press speed"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        Choice {
            visible: pop.s.pressSpeed !== null
            options: [["0", "Default"], ["1", "Slower"], ["2", "Slowest"]]
            current: String(pop.s.pressSpeed)
            onPicked: k => AirPods.setNumber("pressspeed", k)
        }
        Text { visible: pop.s.holdDuration !== null; text: "Press and hold duration"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        Choice {
            visible: pop.s.holdDuration !== null
            options: [["0", "Default"], ["1", "Shorter"], ["2", "Shortest"]]
            current: String(pop.s.holdDuration)
            onPicked: k => AirPods.setNumber("holdduration", k)
        }
        Text { visible: (pop.s.swipe ?? false) && pop.s.swipeSpeed !== null; text: "Volume swipe length"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        Choice {
            visible: (pop.s.swipe ?? false) && pop.s.swipeSpeed !== null
            // 0 is what these AirPods report before it was ever changed
            options: [["1", "Default"], ["2", "Longer"], ["3", "Longest"]]
            current: String(Math.max(1, pop.s.swipeSpeed ?? 1))
            onPicked: k => AirPods.setNumber("swipespeed", k)
        }
        Text { visible: pop.s.callControl !== null; text: "During calls, press once to"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        Choice {
            visible: pop.s.callControl !== null
            options: [["mute", "Mute · twice ends"], ["end", "End · twice mutes"]]
            current: pop.s.callControl ?? ""
            onPicked: k => AirPods.setCallControl(k)
        }
        Text { visible: pop.s.mic !== null; text: "Microphone"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        Choice {
            visible: pop.s.mic !== null
            options: [["0", "Automatic"], ["2", "Always left"], ["1", "Always right"]]
            current: String(pop.s.mic)
            onPicked: k => AirPods.setNumber("mic", k)
        }
        Item {
            width: parent.width; height: 30
            Rectangle {
                anchors.left: parent.left; anchors.right: renameBtn.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                height: 26; radius: Theme.radius; color: Theme.bg2
                border.color: nameInput.activeFocus ? Theme.accent : "transparent"; border.width: 1
                TextInput {
                    id: nameInput
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true; maximumLength: 32
                    color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
                    text: pop.s.name
                    onActiveFocusChanged: pop.renaming = activeFocus
                    Keys.onReturnPressed: { AirPods.rename(text); focus = false }
                    Keys.onEscapePressed: { text = pop.s.name; focus = false }
                    MouseArea { anchors.fill: parent; enabled: !pop.renaming; cursorShape: Qt.IBeamCursor; onClicked: { pop.renaming = true; nameInput.forceActiveFocus() } }
                }
            }
            PopupButton {
                id: renameBtn
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                label: "Rename"
                onClicked: { AirPods.rename(nameInput.text); nameInput.focus = false }
            }
        }
        Level {
            visible: pop.s.chime !== null
            label: "Chime volume"
            value: pop.s.chime ?? 0
            onCommitted: v => AirPods.setChime(v)
        }
        Column {
            visible: pop.s.cycle !== null
            width: parent.width; spacing: 4
            Text { text: "Press and hold cycles"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
            Row {
                width: parent.width; spacing: 4
                Repeater {
                    model: [[1, "Off"], [2, "Cancel"], [4, "Transparent"], [8, "Adaptive"]]
                    PopupButton {
                        required property var modelData
                        readonly property int mask: pop.s?.cycle ?? 0
                        width: (parent.width - 12) / 4
                        label: modelData[1]
                        on: (mask & modelData[0]) !== 0
                        onClicked: AirPods.setCycle(mask ^ modelData[0])
                    }
                }
            }
        }
    }

    Row {
        spacing: 6; topPadding: 4
        PopupButton { label: "󰕾  Sound"; onClicked: Launcher.toggleMenu("volume", Launcher.menuAnchorX) }
        PopupButton { label: "󰂯  Bluetooth"; onClicked: Launcher.toggleMenu("bluetooth", Launcher.menuAnchorX) }
    }
}
