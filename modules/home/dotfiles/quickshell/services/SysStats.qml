pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0          // percent
    property int cores: 0
    property real temp: 0         // °C
    property real memTotal: 0     // bytes
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real gpu: 0          // percent
    property real gpuUsed: 0
    property real gpuTotal: 0
    property real rx: 0           // bytes/s
    property real tx: 0

    function fmtBytes(b, digits) {
        const d = digits === undefined ? 1 : digits
        if (b >= 1024 * 1024 * 1024) return (b / (1024 * 1024 * 1024)).toFixed(d) + " GiB"
        if (b >= 1024 * 1024) return (b / (1024 * 1024)).toFixed(d) + " MiB"
        if (b >= 1024) return (b / 1024).toFixed(d) + " KiB"
        return Math.round(b) + " B"
    }
    function fmtRate(b) { return fmtBytes(b, 1) + "/s" }
    function pct(v) { return v.toFixed(1).replace(".", ",") + "%" }

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
                root.memTotal = s.memTotal
                root.memUsed = s.memUsed
                root.swapTotal = s.swapTotal
                root.swapUsed = s.swapUsed
                root.gpu = s.gpu
                root.gpuUsed = s.gpuUsed
                root.gpuTotal = s.gpuTotal
                root.rx = s.rx
                root.tx = s.tx
            }
        }
    }
}
