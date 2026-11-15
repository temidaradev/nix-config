pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Divergence meter state for the Steins;Gate theme. `value` is the worldline
// we are on; `display` is what the nixie tubes show (it rolls during a shift).
// Shifts happen on demand (click the meter, `qs ipc call worldline shift`),
// when the theme is switched on, and as a rare Reading Steiner event.
// Persisted in ~/.local/state/quickshell/worldline.
Singleton {
    id: root

    // Worldlines from the visual novel / anime. 1.048596 is Steins Gate.
    readonly property var known: [
        { v: "1.048596", name: "Steins Gate" },
        { v: "0.571024", name: "α · SERN dystopia" },
        { v: "0.571046", name: "α · Mayuri" },
        { v: "0.523299", name: "α · IBN 5100" },
        { v: "0.456903", name: "α · Faris" },
        { v: "0.409431", name: "α · Ruka" },
        { v: "0.337187", name: "α · Moeka" },
        { v: "0.334581", name: "α · Suzuha" },
        { v: "1.130205", name: "β · World War III" },
        { v: "1.130426", name: "β · Kurisu" },
        { v: "1.382733", name: "β · Mayuri" },
        { v: "0.000000", name: "Origin" }
    ]

    property string value: "1.048596"
    property string display: value
    property bool shifting: false
    readonly property string field: value === "1.048596" ? "STEINS GATE" : (value.startsWith("0.") ? "α ATTRACTOR FIELD" : "β ATTRACTOR FIELD")
    readonly property string worldName: (known.find(k => k.v === value) || { name: "Unknown worldline" }).name
    signal shifted

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/quickshell/worldline"

    FileView {
        path: root.stateFile
        printErrors: false
        onLoaded: { const t = text().trim(); if (/^\d\.\d{6}$/.test(t)) { root.value = t; root.display = t } }
    }

    // Steins Gate is the attractor: most shifts converge back to it.
    function pickTarget() {
        if (value !== "1.048596" && Math.random() < 0.5) return "1.048596"
        const pool = known.filter(k => k.v !== value)
        if (Math.random() < 0.15) {   // an unrecorded worldline
            const d = Math.random() < 0.5 ? 0 : 1
            return d + "." + String(Math.floor(Math.random() * 1e6)).padStart(6, "0")
        }
        return pool[Math.floor(Math.random() * pool.length)].v
    }

    function shift(target) {
        if (shifting) return
        _target = target && /^\d\.\d{6}$/.test(target) ? target : pickTarget()
        if (Theme.reducedMotion) { _finish(); return }
        _tick = 0
        shifting = true
        roll.start()
    }

    property string _target: value
    property int _tick: 0
    readonly property int _ticks: 46          // ~2.8 s of rolling cathodes
    function _finish() {
        roll.stop()
        value = _target
        display = _target
        shifting = false
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "sh", stateFile, value])
        shifted()
    }

    // Digits lock left to right, the decimal point never moves.
    Timer {
        id: roll
        interval: 60; repeat: true
        onTriggered: {
            root._tick++
            const locked = Math.floor(Math.max(0, root._tick - 14) / 4)
            let s = ""
            for (let i = 0; i < 8; i++) {
                if (i === 1) { s += "."; continue }
                const pos = i === 0 ? 0 : i - 1
                s += pos < locked ? root._target[i] : String(Math.floor(Math.random() * 10))
            }
            root.display = s
            if (root._tick >= root._ticks) root._finish()
        }
    }

    // Reading Steiner: every so often the world line drifts on its own.
    Timer {
        interval: 47 * 60 * 1000; repeat: true
        running: Theme.steins && !Lock.locked && !Idle.away
        onTriggered: if (Math.random() < 0.35) root.shift()
    }
    Connections {
        target: Theme
        function onSteinsChanged() { if (Theme.steins) root.shift("1.048596") }
    }

    IpcHandler {
        target: "worldline"
        function shift(): void { root.shift() }
        function to(v: string): void { root.shift(v) }
        function get(): string { return root.value + " " + root.worldName }
    }
}
