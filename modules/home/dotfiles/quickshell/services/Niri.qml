pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Mirrors niri's state from `niri msg -j event-stream`.
Singleton {
    id: root

    property var windows: []          // [{id, title, app_id, workspace_id, is_focused}]
    property var workspaces: []       // [{id, idx, name, output, is_active, is_focused}]
    property int focusedWindow: -1
    property var layoutNames: []
    property int layoutIdx: 0
    readonly property string layout: layoutNames.length > layoutIdx ? shortLayout(layoutNames[layoutIdx]) : ""

    property var _win: ({})
    property string hostname: "nixos"
    Process { running: true; command: ["hostname"]; stdout: StdioCollector { onStreamFinished: root.hostname = text.trim() } }

    function shortLayout(name) {
        const map = { "English (US)": "us", "Turkish": "tr", "German": "de", "French": "fr" }
        if (map[name]) return map[name]
        return name.slice(0, 2).toLowerCase()
    }

    function _publish() {
        const arr = Object.values(_win)
        arr.sort((a, b) => a.id - b.id)
        windows = arr
    }

    function action(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args])
    }
    function focusWindow(id) { action("focus-window", "--id", String(id)) }
    function closeWindow(id) { action("close-window", "--id", String(id)) }
    function nextLayout() { action("switch-layout", "next") }
    function focusWorkspace(idx) { action("focus-workspace", String(idx)) }

    function _handle(ev) {
        if (ev.WorkspacesChanged) {
            const ws = ev.WorkspacesChanged.workspaces.slice()
            ws.sort((a, b) => a.idx - b.idx)
            workspaces = ws
        } else if (ev.WorkspaceActivated) {
            const {id, focused} = ev.WorkspaceActivated
            const out = workspaces.find(w => w.id === id)?.output
            workspaces = workspaces.map(w => {
                const o = Object.assign({}, w)
                if (w.output === out) o.is_active = (w.id === id)
                if (focused) o.is_focused = (w.id === id)
                return o
            })
        } else if (ev.WindowsChanged) {
            const m = {}
            for (const w of ev.WindowsChanged.windows) { m[w.id] = w; if (w.is_focused) focusedWindow = w.id }
            _win = m; _publish()
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window
            _win[w.id] = w
            if (w.is_focused) focusedWindow = w.id
            _publish()
        } else if (ev.WindowClosed) {
            delete _win[ev.WindowClosed.id]
            if (focusedWindow === ev.WindowClosed.id) focusedWindow = -1
            _publish()
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id
            focusedWindow = id === null ? -1 : id
            for (const k in _win) _win[k].is_focused = (_win[k].id === id)
            _publish()
        } else if (ev.KeyboardLayoutsChanged) {
            layoutNames = ev.KeyboardLayoutsChanged.keyboard_layouts.names
            layoutIdx = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx
        } else if (ev.KeyboardLayoutSwitched) {
            layoutIdx = ev.KeyboardLayoutSwitched.idx
        }
    }

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                try { root._handle(JSON.parse(data)) } catch (e) { console.log("niri event parse:", e, data) }
            }
        }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 2000; onTriggered: stream.running = true }
}
