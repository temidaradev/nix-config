pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string keyFile: Quickshell.env("HOME") + "/.config/typesafe/api-key"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string script: "[ -r \"$1\" ] || exit 1; printf 'header = \"Authorization: Bearer %s\"\\n' \"$(cat \"$1\")\" | curl -sf --max-time 20 -K - -H 'Content-Type: application/json' --data-binary \"$2\" https://api.typesafe.ai/v1/systemone"

    property var cache: ({})
    property bool loaded: false
    property var waiting: ({})
    property var queue: []

    function peek(key) { return loaded ? cache[key] : undefined }

    function ask(key, state, questions, cb) {
        queue.push({ key, cb, body: JSON.stringify({ model: "jev-latest", state, questions }) })
        Qt.callLater(drain)
    }

    function drain() {
        if (!loaded) return
        const q = queue
        queue = []
        for (const r of q) {
            if (r.key in cache) { r.cb(cache[r.key]); continue }
            if (waiting[r.key]) { waiting[r.key].push(r.cb); continue }
            waiting[r.key] = [r.cb]
            requestComp.createObject(root, { key: r.key, body: r.body })
        }
    }

    function finish(key, text) {
        let answers = null
        try { answers = JSON.parse(text).answers || null } catch (e) { console.log("jev:", key, e) }
        if (answers) { cache[key] = answers; fv.setText(JSON.stringify(cache)) }
        const cbs = waiting[key] || []
        delete waiting[key]
        for (const cb of cbs) cb(answers)
    }

    Component {
        id: requestComp
        Process {
            id: proc
            property string key
            property string body
            running: true
            command: ["sh", "-c", root.script, "jev", root.keyFile, body]
            stdout: StdioCollector { onStreamFinished: { root.finish(proc.key, text); proc.destroy() } }
        }
    }

    Process { command: ["mkdir", "-p", root.stateDir]; running: true }
    FileView {
        id: fv
        path: root.stateDir + "/jev.json"
        onLoaded: { if (root.loaded) return; try { root.cache = JSON.parse(text()) } catch (e) { root.cache = {} }; root.loaded = true; root.drain() }
        onLoadFailed: { if (root.loaded) return; root.loaded = true; root.drain() }
    }
}
