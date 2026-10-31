import QtQuick
import Quickshell
import qs
import qs.services

// Sony WH-1000XM5 controls, styled like the other bar popups.
BarPopup {
    id: pop
    visible: Launcher.menu === "sony"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""
    Component.onCompleted: Sony.refresh()

    readonly property var s: Sony.state
    property bool showBands: false
    property bool showSound: false
    property bool showSettings: false
    property bool confirmOff: false

    readonly property var eqPresets: [
        ["off", "Off"], ["bright", "Bright"], ["excited", "Excited"], ["mellow", "Mellow"], ["relaxed", "Relaxed"],
        ["vocal", "Vocal"], ["treble", "Treble"], ["bass", "Bass"], ["speech", "Speech"],
        ["manual", "Manual"], ["custom1", "Custom 1"], ["custom2", "Custom 2"]
    ]
    readonly property var bandLabels: ["Bass", "400", "1k", "2.5k", "6.3k", "16k"]
    readonly property var quickLabels: ({ 0: "None", 1: "Spotify" })
    function quickLabel(code) { return pop.quickLabels[code] ?? "0x" + code.toString(16).padStart(2, "0") }

    // A row of mutually exclusive PopupButtons filling the width.
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
    // Label on the left, a small cycling button on the right.
    component Cycle: Item {
        id: cy
        property string label
        property string sub: ""
        property string value
        signal clicked
        width: parent.width
        implicitHeight: Math.max(30, cyCol.implicitHeight)
        Column {
            id: cyCol
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - cyBtn.width - 8
            Text { width: parent.width; elide: Text.ElideRight; text: cy.label; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize }
            Text { visible: cy.sub !== ""; width: parent.width; elide: Text.ElideRight; text: cy.sub; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
        }
        PopupButton { id: cyBtn; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; label: cy.value + "  󰁔"; onClicked: cy.clicked() }
    }
    // Section header that folds its content.
    component Fold: Item {
        id: fold
        property string text
        property bool open: false
        signal toggle
        width: parent.width
        implicitHeight: foldText.implicitHeight
        PopupSection { id: foldText; text: fold.text }
        Text {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            text: fold.open ? "󰅃" : "󰅀"; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fold.toggle() }
    }
    // Discrete horizontal slider (ambient level 1..20).
    component Steps: Item {
        id: st
        property int value: 0
        property int max: 20
        property bool dragging: false
        property int dragValue: 0
        readonly property int shown: dragging ? dragValue : value
        signal committed(int v)
        width: parent.width; height: 22
        Rectangle {
            id: track
            anchors.left: parent.left; anchors.right: num.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 4; radius: 2; color: Theme.bg3
            Rectangle { width: parent.width * st.shown / st.max; height: parent.height; radius: 2; color: Theme.accent }
            Rectangle {
                x: (parent.width - width) * st.shown / st.max
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7; color: Theme.fg
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -9
                cursorShape: Qt.PointingHandCursor
                function at(mx) { return Math.max(1, Math.min(st.max, Math.round((mx - 9) / track.width * st.max))) }
                onPressed: e => { st.dragValue = at(e.x); st.dragging = true }
                onPositionChanged: e => st.dragValue = at(e.x)
                onReleased: { st.dragging = false; st.committed(st.dragValue) }
            }
        }
        Text {
            id: num
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 30; horizontalAlignment: Text.AlignRight
            text: st.shown; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize
        }
    }
    // Vertical EQ band, -10..+10.
    component Band: Item {
        id: band
        property string label
        property int value: 0
        property bool dragging: false
        property int dragValue: 0
        readonly property int shown: dragging ? dragValue : value
        signal committed(int v)
        width: (parent.width - 5 * 6) / 6
        implicitHeight: 112
        Text {
            id: bandValue
            anchors.horizontalCenter: parent.horizontalCenter
            text: (band.shown > 0 ? "+" : "") + band.shown
            color: band.shown === 0 ? Theme.fgDim : Theme.fg
            font.family: Theme.font; font.pointSize: Theme.smallSize - 2
        }
        Rectangle {
            id: btrack
            anchors.horizontalCenter: parent.horizontalCenter
            y: bandValue.height + 6
            width: 4; height: 72; radius: 2
            color: Theme.bg3
            Rectangle {
                readonly property real mid: btrack.height / 2
                readonly property real pos: btrack.height * (0.5 - band.shown / 20)
                width: parent.width; radius: 2
                y: Math.min(mid, pos); height: Math.abs(mid - pos)
                color: Theme.accent
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: btrack.height * (0.5 - band.shown / 20) - height / 2
                width: 12; height: 12; radius: 6; color: Theme.fg
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                function at(my) { return Math.max(-10, Math.min(10, Math.round((0.5 - (my - 8) / btrack.height) * 20))) }
                onPressed: e => { band.dragValue = at(e.y); band.dragging = true }
                onPositionChanged: e => band.dragValue = at(e.y)
                onReleased: { band.dragging = false; band.committed(band.dragValue) }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
            text: band.label; color: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize - 2
        }
    }

    PopupTitle {
        glyph: "󰋋"
        glyphColor: Sony.connected ? Theme.accent : Theme.fgDim
        text: pop.s.name || "WH-1000XM5"
        sub: Sony.connected
            ? [Sony.level >= 0 ? (Sony.charging ? "󰂄 " : "") + Sony.level + "%" : "", pop.s.codec, pop.s.firmware ? "FW " + pop.s.firmware : ""].filter(x => x).join("  ·  ")
            : "Not connected"
        PopupButton { visible: Sony.connected; label: "󰑐"; onClicked: Sony.refresh() }
    }
    PopupMeter {
        visible: Sony.connected && Sony.level >= 0
        pct: Sony.level
        accent: Sony.level < 20 ? Theme.red : Theme.accent
    }
    Text {
        visible: !Sony.connected
        width: parent.width; wrapMode: Text.WordWrap
        text: "Turn the headphones on and connect them over Bluetooth."
        color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
    }

    // ── Noise control
    PopupSection { visible: Sony.connected && pop.s.anc !== null; text: "Noise control" }
    Choice {
        visible: Sony.connected && pop.s.anc !== null
        options: [["nc", "󰋎  Cancel"], ["ambient", "󰟅  Ambient"], ["off", "Off"]]
        current: pop.s.anc ?? ""
        onPicked: k => Sony.setAnc(k)
    }
    Steps {
        visible: Sony.connected && pop.s.anc === "ambient"
        value: pop.s.ambientLevel
        onCommitted: v => Sony.setAmbient(v)
    }
    PopupToggle {
        visible: Sony.connected && pop.s.anc === "ambient"
        label: "Focus on voice"; on: pop.s.focusVoice
        onToggled: v => Sony.setFocusVoice(v)
    }

    // ── Equaliser
    Fold {
        visible: Sony.connected && pop.s.eq !== null
        text: "Equaliser"; open: pop.showBands
        onToggle: pop.showBands = !pop.showBands
    }
    Flow {
        visible: Sony.connected && pop.s.eq !== null
        width: parent.width; spacing: 4
        Repeater {
            model: pop.eqPresets
            PopupButton {
                required property var modelData
                label: modelData[1]
                on: pop.s.eq?.preset === modelData[0]
                onClicked: Sony.setEq(modelData[0])
            }
        }
    }
    Row {
        visible: Sony.connected && pop.s.eq !== null && pop.showBands
        width: parent.width; spacing: 6
        Repeater {
            model: 6
            Band {
                required property int index
                label: pop.bandLabels[index]
                value: index === 0 ? (pop.s.eq?.bass ?? 0) : (pop.s.eq?.bands[index - 1] ?? 0)
                onCommitted: v => {
                    const bands = (pop.s.eq?.bands ?? [0, 0, 0, 0, 0]).slice()
                    let bass = pop.s.eq?.bass ?? 0
                    if (index === 0) bass = v
                    else bands[index - 1] = v
                    Sony.setBands(bass, bands)
                }
            }
        }
    }

    // ── Devices (multipoint)
    Item {
        visible: Sony.connected && pop.s.multipoint !== null
        width: parent.width; implicitHeight: mpHead.implicitHeight
        PopupSection { id: mpHead; text: "Devices" }
        PopupSwitch {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            scale: 0.8; transformOrigin: Item.BottomRight
            on: pop.s.multipoint ?? false
            onToggled: v => Sony.setMultipoint(v)
        }
    }
    Column {
        visible: Sony.connected && (pop.s.multipoint ?? false)
        width: parent.width; spacing: 1
        Repeater {
            model: (pop.s.multipoint ?? false) ? pop.s.peers : []
            PopupRow {
                required property var modelData
                readonly property bool self: modelData.address === pop.s.localAddress
                glyph: self ? "󰍹" : "󰄜"
                label: modelData.name || modelData.address
                sub: self ? "This computer" : modelData.connected ? "Connected" : "Paired"
                active: modelData.connected
                action: self ? "" : modelData.connected ? "Disconnect" : "Connect"
                onActionClicked: Sony.connectPeer(modelData.address, !modelData.connected)
            }
        }
    }

    // ── Sound quality & Speak-to-Chat
    Fold {
        visible: Sony.connected && (pop.s.dsee !== null || pop.s.soundQuality !== null || pop.s.speakToChat !== null)
        text: "Sound"; open: pop.showSound
        onToggle: pop.showSound = !pop.showSound
    }
    Column {
        visible: Sony.connected && pop.showSound
        width: parent.width; spacing: 6
        PopupToggle { visible: pop.s.dsee !== null; label: "DSEE Extreme"; sub: "Upscale compressed audio"; on: pop.s.dsee ?? false; onToggled: v => Sony.setDsee(v) }
        PopupToggle {
            visible: pop.s.soundQuality !== null
            label: "Prioritise sound quality"
            sub: (pop.s.soundQuality ?? false) ? "LDAC when available" : "Prioritising stable connection"
            on: pop.s.soundQuality ?? false
            onToggled: v => Sony.setSoundQuality(v)
        }
        PopupToggle { visible: pop.s.speakToChat !== null; label: "Speak-to-Chat"; sub: "Pause when you talk"; on: pop.s.speakToChat ?? false; onToggled: v => Sony.setSpeakToChat(v) }
        Choice {
            visible: (pop.s.speakToChat ?? false) && pop.s.stcSensitivity !== null
            options: [["auto", "Auto"], ["high", "High"], ["low", "Low"]]
            current: pop.s.stcSensitivity ?? ""
            onPicked: k => Sony.setStcConfig(k, pop.s.stcTimeout ?? "standard")
        }
        Choice {
            visible: (pop.s.speakToChat ?? false) && pop.s.stcTimeout !== null
            options: [["short", "Short"], ["standard", "Standard"], ["long", "Long"], ["off", "Never"]]
            current: pop.s.stcTimeout ?? ""
            onPicked: k => Sony.setStcConfig(pop.s.stcSensitivity ?? "auto", k)
        }
    }

    // ── Settings
    Fold {
        visible: Sony.connected
        text: "Settings"; open: pop.showSettings
        onToggle: pop.showSettings = !pop.showSettings
    }
    Column {
        visible: Sony.connected && pop.showSettings
        width: parent.width; spacing: 6
        PopupToggle { visible: pop.s.pauseOnRemove !== null; label: "Pause when taken off"; on: pop.s.pauseOnRemove ?? false; onToggled: v => Sony.setPauseOnRemove(v) }
        PopupToggle { visible: pop.s.autoOff !== null; label: "Power off when taken off"; on: pop.s.autoOff === "removed"; onToggled: v => Sony.setAutoOff(v ? "removed" : "off") }
        PopupToggle { visible: pop.s.voiceGuide !== null; label: "Voice guidance"; on: pop.s.voiceGuide ?? false; onToggled: v => Sony.setVoiceGuide(v) }
        PopupToggle { visible: pop.s.touchPanel !== null; label: "Touch sensor"; on: pop.s.touchPanel ?? false; onToggled: v => Sony.setTouchPanel(v) }
        Text { visible: pop.s.ncButton !== null; text: "NC/AMB button cycles"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
        Choice {
            visible: pop.s.ncButton !== null
            options: [["nc_ambient_off", "NC·Amb·Off"], ["nc_ambient", "NC·Amb"], ["nc_off", "NC·Off"], ["ambient_off", "Amb·Off"]]
            current: pop.s.ncButton ?? ""
            onPicked: k => Sony.setNcButton(k)
        }
        Cycle {
            visible: pop.s.assistant !== null
            readonly property var choices: ["google", "alexa", "phone", "off"]
            readonly property var labels: ({ google: "Google", alexa: "Alexa", phone: "Phone", off: "Off" })
            label: "Voice assistant"; sub: "Headphones restart to apply"
            value: labels[pop.s.assistant] ?? "—"
            onClicked: Sony.setAssistant(choices[(choices.indexOf(pop.s.assistant) + 1) % choices.length])
        }
        Repeater {
            model: pop.s.quick ? [["double", "Quick access · double tap"], ["triple", "Quick access · triple tap"]] : []
            Cycle {
                id: qRow
                required property var modelData
                readonly property int current: pop.s.quick[modelData[0]]
                readonly property var choices: [0, 1].concat(current > 1 ? [current] : [])
                label: modelData[1]
                value: pop.quickLabel(current)
                onClicked: {
                    const next = choices[(choices.indexOf(current) + 1) % choices.length]
                    const q = Object.assign({}, pop.s.quick, { [modelData[0]]: next })
                    Sony.setQuick(q.double, q.triple)
                }
            }
        }
    }

    Row {
        spacing: 6; topPadding: 4
        PopupButton {
            visible: Sony.connected && (pop.s.multipoint ?? false)
            label: pop.s.pairing ? "󰂱  Pairing…" : "󰂱  Pair"
            on: pop.s.pairing
            onClicked: Sony.setPairing(!pop.s.pairing)
        }
        PopupButton {
            visible: Sony.connected
            label: pop.confirmOff ? "󰐥  Sure?" : "󰐥  Power off"
            danger: true; on: false
            color: pop.confirmOff ? Theme.red : hovered ? "#2affffff" : Theme.bg2
            onClicked: {
                if (pop.confirmOff) { Sony.powerOff(); pop.confirmOff = false; confirmReset.stop() }
                else { pop.confirmOff = true; confirmReset.restart() }
            }
        }
        PopupButton { label: "󰂯  Bluetooth"; onClicked: Launcher.toggleMenu("bluetooth", Launcher.menuAnchorX) }
    }
    Timer { id: confirmReset; interval: 3000; onTriggered: pop.confirmOff = false }
}
