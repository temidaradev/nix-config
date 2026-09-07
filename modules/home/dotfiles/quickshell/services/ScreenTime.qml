pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Foreground app usage per day, from niri's focused window. Persisted to
// ~/.local/state/quickshell/screentime.json, pruned to the last 14 days.
Singleton {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string file: dir + "/screentime.json"
    property var data: ({})            // { "yyyy-MM-dd": { app_id: seconds } }
    property bool dirty: false
    property int version: 0            // bump to refresh bindings cheaply

    function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }

    FileView {
        id: fv
        path: root.file
        onLoaded: { try { root.data = JSON.parse(text()) } catch (e) { root.data = {} }; root.version++ }
        onLoadFailed: root.data = {}
    }
    Process { command: ["mkdir", "-p", root.dir]; running: true }

    Timer {
        interval: 1000; running: !Lock.locked; repeat: true
        onTriggered: {
            const w = Niri.windows.find(w => w.id === Niri.focusedWindow)
            if (!w) return
            const app = w.app_id || "unknown"
            const d = root.today()
            if (!root.data[d]) root.data[d] = {}
            root.data[d][app] = (root.data[d][app] || 0) + 1
            root.dirty = true
        }
    }
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: root.flush()
    }
    function flush() {
        if (!dirty) return
        const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 14)
        for (const d in data) if (new Date(d + "T00:00:00") < cutoff) delete data[d]
        fv.setText(JSON.stringify(data))
        dirty = false
        version++
    }

    // [{app, seconds}] for the last `days` days, largest first
    function usage(days) {
        version
        const out = {}
        for (let i = 0; i < days; i++) {
            const dt = new Date(); dt.setDate(dt.getDate() - i)
            const day = data[Qt.formatDate(dt, "yyyy-MM-dd")]
            if (!day) continue
            for (const app in day) out[app] = (out[app] || 0) + day[app]
        }
        return Object.keys(out).map(app => ({ app, seconds: out[app] })).sort((a, b) => b.seconds - a.seconds)
    }
    // per-day totals for the last `days` days, oldest first: [{date, seconds}]
    function daily(days) {
        version
        const out = []
        for (let i = days - 1; i >= 0; i--) {
            const dt = new Date(); dt.setDate(dt.getDate() - i)
            const key = Qt.formatDate(dt, "yyyy-MM-dd")
            const day = data[key] || {}
            let s = 0; for (const app in day) s += day[app]
            out.push({ date: key, label: Qt.formatDate(dt, "ddd"), seconds: s })
        }
        return out
    }
    function fmt(s) {
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }
    function reset() { data = {}; dirty = true; flush() }
}
