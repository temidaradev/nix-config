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
    property var data: ({})
    property bool dirty: false
    property int version: 0

    readonly property bool counting: !Lock.locked && !Idle.away && !Idle.screensOff
    readonly property string focusedApp: {
        const w = Niri.windows.find(w => w.id === Niri.focusedWindow)
        return w ? (w.app_id || "unknown") : ""
    }
    property string app: ""
    property real since: 0

    function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }

    function add(app, from, to) {
        while (from < to) {
            const d = new Date(from)
            const midnight = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime()
            const end = Math.min(to, midnight)
            const key = Qt.formatDate(d, "yyyy-MM-dd")
            if (!data[key]) data[key] = {}
            data[key][app] = (data[key][app] || 0) + Math.round((end - from) / 1000)
            from = end
        }
        dirty = true
    }

    function settle(until) {
        const now = until ?? Date.now()
        if (app !== "" && since > 0 && now > since) add(app, since, now)
        app = counting ? focusedApp : ""
        since = Date.now()
    }
    onFocusedAppChanged: settle()
    onCountingChanged: settle(Idle.away ? Math.max(since, Date.now() - Idle.awaySec * 1000) : undefined)

    FileView {
        id: fv
        path: root.file
        onLoaded: { try { root.data = JSON.parse(text()) } catch (e) { root.data = {} }; root.version++ }
        onLoadFailed: root.data = {}
    }
    Process { command: ["mkdir", "-p", root.dir]; running: true }

    Timer {
        interval: 300000; running: true; repeat: true
        onTriggered: root.flush()
    }
    function flush() {
        settle()
        if (!dirty) return
        const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 14)
        for (const d in data) if (new Date(d + "T00:00:00") < cutoff) delete data[d]
        fv.setText(JSON.stringify(data))
        dirty = false
        version++
    }
    Connections {
        target: Lock
        function onLockedChanged() { if (Lock.locked) root.flush() }
    }
    Component.onDestruction: flush()

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
    function reset() { data = {}; app = ""; since = 0; dirty = true; flush() }
}
