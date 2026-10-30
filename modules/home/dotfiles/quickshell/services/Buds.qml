pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var empty: ({ connected: false, name: "", firmware: "", battery: {}, anc: null, ancLevel: "high", eq: null, bass: null, inEar: null, lowLatency: null, spatial: null, gestures: {}, finding: false })
    property var state: empty

    readonly property bool connected: state.connected
    readonly property var battery: state.battery || {}
    readonly property int level: {
        const b = [battery.left, battery.right].filter(x => x)
        return b.length ? Math.min(...b.map(x => x.level)) : -1
    }
    readonly property bool charging: [battery.left, battery.right].some(x => x && x.charging)

    function send(line) { if (proc.running) proc.write(line + "\n") }
    function setAnc(mode) { send("anc " + mode) }
    function setEq(preset) { send("eq " + preset) }
    function setBass(on, lvl) { send("bass " + (on ? "on" : "off") + " " + lvl) }
    function setInEar(on) { send("inear " + (on ? "on" : "off")) }
    function setLowLatency(on) { send("latency " + (on ? "on" : "off")) }
    function setSpatial(on) { send("spatial " + (on ? "on" : "off")) }
    function setGesture(side, kind, action) { send(["gesture", side, kind, action].join(" ")) }
    function find(on) { send("find " + (on ? "on" : "off")); if (on) findStop.restart(); else findStop.stop() }
    function refresh() { send("refresh") }

    Process {
        id: proc
        running: true
        command: ["cmf-buds"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try { root.state = JSON.parse(data) } catch (e) { console.log("cmf-buds:", e, data) }
            }
        }
        onExited: { root.state = root.empty; restart.start() }
    }
    Timer { id: restart; interval: 5000; onTriggered: proc.running = true }
    Timer { id: findStop; interval: 30000; onTriggered: root.find(false) }
}
