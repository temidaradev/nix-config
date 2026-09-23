pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property real cpu: 0          // percent
    property real temp: 0         // CPU °C
    property real gpuTemp: 0
    property real nvmeTemp: 0
    property real memTotal: 0     // bytes
    property real memUsed: 0
    property real memAvail: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real gpu: 0          // busy percent, 0 where the driver doesn't expose it
    property real gpuUsed: 0
    property real gpuTotal: 0
    property real rx: 0           // bytes/s
    property real tx: 0
    property var cpuHist: []      // last 60 samples, percent
    property var memHist: []
    property var rxHist: []
    property var txHist: []
    property string load: ""
    property var disks: []        // [{mount, size, used, pct}]
    property string uptime: ""

    readonly property bool watched: Launcher.dashOpen || Launcher.sidebarOpen || Launcher.tempOpen || Launcher.diskOpen || ["cpu", "memory", "network"].indexOf(Launcher.menu) >= 0
    readonly property bool sampling: !Lock.locked && !Idle.screensOff
    readonly property int interval: watched || !Battery.saving ? 1000 : 10000

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

    property var sensors: ({})
    Process {
        running: true
        command: ["sh", "-c", `
            for d in /sys/class/hwmon/hwmon*; do
                case "$(cat "$d/name" 2>/dev/null)" in
                    k10temp|coretemp|zenpower) echo "temp=$d/temp1_input" ;;
                    nvme) echo "nvme=$d/temp1_input" ;;
                    xe|i915|amdgpu|nouveau)
                        f=""
                        for l in "$d"/temp*_label; do
                            [ -r "$l" ] || continue
                            case "$(cat "$l")" in pkg|edge|junction) f="\${l%_label}_input" ;; esac
                        done
                        [ -z "$f" ] && [ -r "$d/temp1_input" ] && f="$d/temp1_input"
                        [ -n "$f" ] && echo "gpuTemp=$f" ;;
                esac
            done
            for c in /sys/class/drm/card[0-9]*/device; do
                [ -r "$c/gpu_busy_percent" ] && echo "gpuBusy=$c/gpu_busy_percent"
                [ -r "$c/mem_info_vram_used" ] && echo "gpuUsed=$c/mem_info_vram_used"
                [ -r "$c/mem_info_vram_total" ] && echo "gpuTotal=$c/mem_info_vram_total"
                [ -r "$c/tile0/physical_vram_size_bytes" ] && echo "gpuTotal=$c/tile0/physical_vram_size_bytes"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = {}
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=")
                    if (i > 0 && !s[l.slice(0, i)]) s[l.slice(0, i)] = l.slice(i + 1)
                }
                root.sensors = s
            }
        }
    }

    component Reader: FileView { printErrors: false }
    component SensorReader: Reader {
        property string key
        property real scale: 1
        path: root.sensors[key] ?? ""
        onLoaded: root[key] = (parseInt(text()) || 0) / scale
    }

    property real _total: 0
    property real _idle: 0
    Reader {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().slice(0, text().indexOf("\n")).trim().split(/\s+/).slice(1, 9).map(Number)
            const total = f.reduce((a, b) => a + b, 0), idle = f[3] + f[4]
            const dt = total - root._total, di = idle - root._idle
            if (root._total > 0 && dt > 0) {
                root.cpu = (dt - di) / dt * 100
                root.cpuHist = root.push(root.cpuHist, root.cpu)
            }
            root._total = total; root._idle = idle
        }
    }
    Reader {
        id: mem
        path: "/proc/meminfo"
        onLoaded: {
            const m = {}
            for (const l of text().split("\n")) {
                const p = l.split(/:\s+/)
                if (p.length === 2) m[p[0]] = parseInt(p[1]) * 1024
            }
            root.memTotal = m.MemTotal || 0
            root.memUsed = (m.MemTotal || 0) - (m.MemAvailable || 0)
            root.memAvail = m.MemAvailable || 0
            root.memCached = (m.Cached || 0) + (m.Buffers || 0) + (m.SReclaimable || 0)
            root.swapTotal = m.SwapTotal || 0
            root.swapUsed = (m.SwapTotal || 0) - (m.SwapFree || 0)
            root.memHist = root.push(root.memHist, root.memTotal > 0 ? root.memUsed / root.memTotal * 100 : 0)
        }
    }
    property real _rx: -1
    property real _tx: -1
    property real _netAt: 0
    Reader {
        id: net
        path: "/proc/net/dev"
        onLoaded: {
            let r = 0, t = 0
            for (const l of text().split("\n").slice(2)) {
                const i = l.indexOf(":")
                if (i < 0) continue
                const name = l.slice(0, i).trim()
                if (!/^(en|eth|wl|ww|usb)/.test(name)) continue
                const f = l.slice(i + 1).trim().split(/\s+/)
                r += Number(f[0]); t += Number(f[8])
            }
            const now = Date.now()
            if (root._rx >= 0 && now > root._netAt) {
                const s = (now - root._netAt) / 1000
                root.rx = Math.max(0, (r - root._rx) / s)
                root.tx = Math.max(0, (t - root._tx) / s)
                root.rxHist = root.push(root.rxHist, root.rx)
                root.txHist = root.push(root.txHist, root.tx)
            }
            root._rx = r; root._tx = t; root._netAt = now
        }
    }
    SensorReader { id: cpuTemp; key: "temp"; scale: 1000 }
    SensorReader { id: gpuTempR; key: "gpuTemp"; scale: 1000 }
    SensorReader { id: nvmeTempR; key: "nvmeTemp"; scale: 1000; path: root.sensors.nvme ?? "" }
    SensorReader { id: gpuBusy; key: "gpu"; path: root.sensors.gpuBusy ?? "" }
    SensorReader { id: gpuUsedR; key: "gpuUsed" }
    SensorReader { key: "gpuTotal" }

    Timer {
        interval: root.interval; repeat: true; triggeredOnStart: true
        running: root.sampling
        onTriggered: {
            stat.reload(); mem.reload(); net.reload()
            if (root.watched) loadavg.reload()
            for (const r of [cpuTemp, gpuTempR, nvmeTempR, gpuBusy, gpuUsedR]) if (r.path !== "") r.reload()
        }
    }
    onSamplingChanged: if (sampling) { _rx = -1; _total = 0 }

    Reader {
        id: loadavg
        path: "/proc/loadavg"
        onLoaded: root.load = text().split(" ").slice(0, 3).join("  ")
    }
    Reader {
        id: up
        path: "/proc/uptime"
        onLoaded: {
            const s = parseFloat(text()) || 0
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
            root.uptime = (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m"
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
    function refreshSlow() { df.running = true; up.reload() }
    Timer {
        interval: root.watched ? 30000 : Battery.saving ? 300000 : 60000
        running: root.sampling; repeat: true; triggeredOnStart: true
        onTriggered: root.refreshSlow()
    }
    onWatchedChanged: if (watched) refreshSlow()
}
