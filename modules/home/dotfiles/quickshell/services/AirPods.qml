pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// AirPods over Apple's AAP channel (see pkgs/airpods).
//
// Some things an iPhone/Mac does host-side are done here instead:
//  * pause media when an AirPod comes out, resume when it goes back in
//  * lower the volume while you talk (Conversation Awareness only *reports* speech)
//  * warn once when a bud runs low
Singleton {
    id: root

    readonly property var empty: ({ connected: false, name: "", address: "", model: "", info: null, left: null, right: null, case: null, leftEar: null, rightEar: null, anc: null, strength: null, conversation: null, adaptiveVolume: null, offOption: null, oneBud: null, swipe: null, earDetect: null, caseTone: null, sleepDetect: null, chime: null, cycle: null, eq: null, speaking: false, mic: null, pressSpeed: null, holdDuration: null, swipeSpeed: null, callControl: null, controls: ({}) })
    property var state: empty

    readonly property bool connected: state.connected
    // the lower bud is what runs out first
    readonly property int level: {
        const pods = [state.left, state.right].filter(p => p)
        return pods.length ? Math.min(...pods.map(p => p.level)) : -1
    }
    readonly property bool charging: [state.left, state.right].some(p => p?.charging)

    // ── host-side preferences, kept in ~/.local/state/quickshell/airpods.json
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    // "one" pause when either comes out, "both" only when both are out, "off"
    property string autoPause: "one"
    property bool duck: true
    property int duckTo: 20          // percent of the volume before you spoke
    function savePrefs() { prefs.setText(JSON.stringify({ autoPause: root.autoPause, duck: root.duck, duckTo: root.duckTo })) }
    function setAutoPause(v) { root.autoPause = v; savePrefs() }
    function setDuck(v) { root.duck = v; savePrefs() }

    function send(line) { if (proc.running) proc.write(line + "\n") }
    function setAnc(mode) { send("anc " + mode) }
    function setStrength(v) { send("strength " + v) }
    function setChime(v) { send("chime " + v) }
    function setCycle(mask) { send("cycle " + mask) }
    function setFlag(name, on) { send(name + " " + (on ? "on" : "off")) }
    function setEq(on) { send("eq " + (on ? "on" : "off")) }
    function setEqBands(low, mid, high) { send(["eqbands", low, mid, high].join(" ")) }
    function setNumber(name, v) { send(name + " " + v) }     // mic, pressspeed, holdduration, swipespeed
    function setCallControl(v) { send("callcontrol " + v) }
    function rename(name) { if (name.trim() !== "") send("rename " + name.trim()) }
    function refresh() { send("refresh") }

    // ── is audio actually going to the AirPods?
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }
    readonly property bool isOutput: connected && state.address !== ""
        && (sink?.name ?? "").includes(state.address.replace(/:/g, "_"))

    // ── pause / resume on ear detection
    readonly property bool leftIn: state.leftEar === "ear"
    readonly property bool rightIn: state.rightEar === "ear"
    readonly property bool earKnown: state.leftEar !== null || state.rightEar !== null
    readonly property bool wantPaused: autoPause === "one" ? !(leftIn && rightIn) : !(leftIn || rightIn)
    property var pausedByUs: []
    onWantPausedChanged: {
        if (!connected || !earKnown || autoPause === "off") return
        if (wantPaused) {
            if (!isOutput) return
            const playing = Mpris.players.values.filter(p => p.isPlaying && p.canPause)
            for (const p of playing) p.pause()
            pausedByUs = playing
        } else {
            for (const p of pausedByUs) if (p && p.canPlay) p.play()
            pausedByUs = []
        }
    }
    onConnectedChanged: if (!connected) { pausedByUs = []; restoreVolume() }

    // ── duck while speaking
    property real volumeBefore: -1
    function restoreVolume() {
        if (volumeBefore >= 0 && sink?.audio) sink.audio.volume = volumeBefore
        volumeBefore = -1
    }
    readonly property bool speaking: state.speaking
    onSpeakingChanged: {
        if (speaking && duck && isOutput && sink?.audio && volumeBefore < 0) {
            volumeBefore = sink.audio.volume
            sink.audio.volume = volumeBefore * duckTo / 100
        } else if (!speaking) {
            restoreVolume()
        }
    }

    // ── low battery warning, once per bud per discharge
    property var warned: ({})
    function checkBattery(side, pod) {
        if (!pod) return
        if (pod.charging || pod.level > 20) { if (warned[side]) { const w = Object.assign({}, warned); delete w[side]; warned = w } return }
        if (pod.level <= 15 && !warned[side]) {
            warned = Object.assign({}, warned, { [side]: true })
            Quickshell.execDetached(["notify-send", "-a", "AirPods", "-i", "audio-headphones", "AirPods battery low",
                (side === "left" ? "Left" : "Right") + " AirPod is at " + pod.level + "%"])
        }
    }
    onStateChanged: { checkBattery("left", state.left); checkBattery("right", state.right) }

    Process { command: ["mkdir", "-p", root.stateDir]; running: true }
    FileView {
        id: prefs
        path: root.stateDir + "/airpods.json"
        onLoaded: {
            try {
                const p = JSON.parse(text())
                if (typeof p.autoPause === "string") root.autoPause = p.autoPause
                if (typeof p.duck === "boolean") root.duck = p.duck
                if (typeof p.duckTo === "number") root.duckTo = p.duckTo
            } catch (e) {}
        }
    }

    Process {
        id: proc
        running: true
        command: ["airpods"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try { root.state = JSON.parse(data) } catch (e) { console.log("airpods:", e, data) }
            }
        }
        onExited: { root.state = root.empty; restart.start() }
    }
    Timer { id: restart; interval: 5000; onTriggered: proc.running = true }
}
