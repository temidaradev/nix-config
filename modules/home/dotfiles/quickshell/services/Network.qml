pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager state via nmcli. Polls only while `active` (a panel is open).
Singleton {
    id: root
    property bool active: false
    property var devices: []      // [{name, type, state, connection, ip4}]
    property var wifi: []         // [{inUse, ssid, signal, freq, band, secure}]
    readonly property bool hasWifi: devices.some(d => d.type === "wifi")
    readonly property var primary: devices.find(d => d.state === "connected" && d.type !== "loopback" && !d.name.startsWith("wg") && !d.name.startsWith("docker") && !d.name.startsWith("br-") && !d.name.startsWith("vmnet")) || null
    readonly property var vpn: devices.find(d => d.state === "connected" && (d.type === "wireguard" || d.type === "tun" || d.name.startsWith("wg"))) || null
    readonly property var current: wifi.find(w => w.inUse) || null

    Process {
        id: dev
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status; echo ==; nmcli -t -f GENERAL.DEVICE,IP4.ADDRESS device show 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [a, b] = text.split("==\n")
                const ip = {}
                let cur = ""
                for (const l of (b || "").split("\n")) {
                    if (l.startsWith("GENERAL.DEVICE:")) cur = l.slice(15)
                    else if (l.startsWith("IP4.ADDRESS") && cur && !ip[cur]) ip[cur] = l.slice(l.indexOf(":") + 1)
                }
                root.devices = (a || "").trim().split("\n").filter(l => l !== "").map(l => {
                    const p = l.split(":")
                    return { name: p[0], type: p[1], state: p[2], connection: p.slice(3).join(":"), ip4: ip[p[0]] || "" }
                }).filter(d => d.type !== "loopback")
            }
        }
    }
    Process {
        id: scan
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,FREQ,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                root.wifi = text.trim().split("\n").filter(l => l !== "").map(l => {
                    const p = l.split(":")
                    const freq = parseInt(p[3]) || 0
                    return { inUse: p[0] === "*", ssid: p[1], signal: parseInt(p[2]) || 0, freq,
                             band: freq > 5900 ? "6 GHz" : freq > 4900 ? "5 GHz" : "2.4 GHz", secure: (p[4] || "") !== "" }
                }).filter(w => w.ssid !== "" && !seen[w.ssid] && (seen[w.ssid] = true)).sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
            }
        }
    }
    Timer {
        interval: 5000; repeat: true; running: root.active; triggeredOnStart: true
        onTriggered: { dev.running = true; if (root.hasWifi) scan.running = true }
    }
    function refresh() { dev.running = true; if (hasWifi) scan.running = true }
    function connect(ssid) { Quickshell.execDetached(["sh", "-c", "nmcli device wifi connect '" + ssid.replace(/'/g, "'\\''") + "' || nm-connection-editor"]) }
    function disconnect(name) { Quickshell.execDetached(["nmcli", "connection", "down", name]) }
    function toggleWifi(on) { Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]) }
}
