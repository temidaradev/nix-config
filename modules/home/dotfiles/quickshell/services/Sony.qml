pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var empty: ({ connected: false, name: "", firmware: "", codec: null, battery: null, anc: null, focusVoice: false, ambientLevel: 0, eq: null, speakToChat: null, stcSensitivity: null, stcTimeout: null, pauseOnRemove: null, autoOff: null, voiceGuide: null, quick: null, dsee: null, soundQuality: null, ncButton: null, assistant: null, touchPanel: null, multipoint: null, pairing: false, peers: [], localAddress: "" })
    property var state: empty

    readonly property bool connected: state.connected
    readonly property int level: state.battery ? state.battery.level : -1
    readonly property bool charging: state.battery?.charging ?? false

    function send(line) { if (proc.running) proc.write(line + "\n") }
    function setAnc(mode) { send("anc " + mode) }
    function setAmbient(lvl) { send("ambient " + lvl) }
    function setFocusVoice(on) { send("focus " + (on ? "on" : "off")) }
    function setEq(preset) { send("eq " + preset) }
    function setBands(bass, bands) { send(["bands", bass].concat(bands).join(" ")) }
    function setSpeakToChat(on) { send("stc " + (on ? "on" : "off")) }
    function setStcConfig(sensitivity, timeout) { send(["stcconfig", sensitivity, timeout].join(" ")) }
    function setPauseOnRemove(on) { send("pause " + (on ? "on" : "off")) }
    function setAutoOff(mode) { send("autooff " + mode) }
    function setVoiceGuide(on) { send("guide " + (on ? "on" : "off")) }
    function setQuick(double, triple) { send(["quick", double, triple].join(" ")) }
    function setDsee(on) { send("dsee " + (on ? "on" : "off")) }
    function setSoundQuality(on) { send("quality " + (on ? "on" : "off")) }
    function setTouchPanel(on) { send("touch " + (on ? "on" : "off")) }
    function setNcButton(mode) { send("ncbutton " + mode) }
    function setAssistant(mode) { send("assistant " + mode) }
    function setMultipoint(on) { send("multipoint " + (on ? "on" : "off")) }
    function setPairing(on) { send("pairing " + (on ? "on" : "off")) }
    function connectPeer(address, on) { send(["peer", on ? "connect" : "disconnect", address].join(" ")) }
    function powerOff() { send("poweroff") }
    function refresh() { send("refresh") }

    Process {
        id: proc
        running: true
        command: ["sony-xm5"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try { root.state = JSON.parse(data) } catch (e) { console.log("sony-xm5:", e, data) }
            }
        }
        onExited: { root.state = root.empty; restart.start() }
    }
    Timer { id: restart; interval: 5000; onTriggered: proc.running = true }
}
