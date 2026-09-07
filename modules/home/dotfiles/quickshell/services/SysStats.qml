pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0          // percent
    property int cores: 0
    property real temp: 0         // CPU °C
    property real gpuTemp: 0
    property real nvmeTemp: 0
    property real memTotal: 0     // bytes
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real gpu: 0          // percent (0 on Intel xe: not exposed)
    property real gpuUsed: 0
    property real gpuTotal: 0
    property real rx: 0           // bytes/s
    property real tx: 0
    property var cpuHist: []      // last 60 s, percent
    property var memHist: []
    property var disks: []        // [{mount, size, used, pct}]
    property string uptime: ""

    function fmtBytes(b, digits) {
        const d = digits === undefined ? 1 : digits
        if (b >= 1024 * 1024 * 1024) return (b / (1024 * 1024 * 1024)).toFixed(d) + " GiB"
        if (b >= 1024 * 1024) return (b / (1024 * 1024)).toFixed(d) + " MiB"
        if (b >= 1024) return (b / 1024).toFixed(d) + " KiB"
        return Math.round(b) + " B"
    }
    function fmtRate(b) { return fmtBytes(b, 1) + "/s" }
    function pct(v) { return v.toFixed(1).replace(".", ",") + "%" }
    function push(arr, v) { const a = arr.slice(-59); a.push(v); return a }

    Process {
        running: true
        command: [Quickshell.shellDir + "/scripts/sysstats.sh"]
        stdout: SplitParser {
            onRead: data => {
                let s
                try { s = JSON.parse(data) } catch (e) { return }
                root.cpu = s.cpu / 10
                root.cores = s.cores
                root.temp = s.temp / 1000
                root.gpuTemp = s.gpuTemp / 1000
                root.nvmeTemp = s.nvmeTemp / 1000
                root.memTotal = s.memTotal
                root.memUsed = s.memUsed
                root.swapTotal = s.swapTotal
                root.swapUsed = s.swapUsed
                root.gpu = s.gpu
                root.gpuUsed = s.gpuUsed
                root.gpuTotal = s.gpuTotal
                root.rx = s.rx
                root.tx = s.tx
                root.cpuHist = root.push(root.cpuHist, root.cpu)
                root.memHist = root.push(root.memHist, s.memTotal > 0 ? s.memUsed / s.memTotal * 100 : 0)
            }
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=target,size,used,pcent", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "fuse.portal"]
        stdout: StdioCollector {
            onStreamFinished: root.disks = text.trim().split("\n").slice(1).map(l => {
                const p = l.trim().split(/\s+/)
                const pct = parseInt(p[p.length - 1])
                const used = parseFloat(p[p.length - 2]), size = parseFloat(p[p.length - 3])
                return { mount: p.slice(0, p.length - 3).join(" "), size, used, pct }
            }).filter(d => d.mount !== "/boot" && !d.mount.startsWith("/nix/store"))
        }
    }
    Process {
        id: up
        command: ["uptime", "-p"]
        stdout: StdioCollector { onStreamFinished: root.uptime = text.trim().replace(/^up /, "") }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { df.running = true; up.running = true } }
}
