pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root
    property var audio: ({})
    property var displays: ({})
    property var power: ({})
    property var wattHistory: []
    onPowerChanged: if (power.batteries?.length) wattHistory = wattHistory.slice(-59).concat([power.batteries[0].watts])
    property var network: ({})
    property var system: ({})
    property var clipboard: ({})
    property var capture: ({})
    property var calendar: ({})
    property var local: ({ tasks: [], pins: [], favorites: [], notes: "" })
    property var scroll: ({})
    property string message: ""
    property bool failed: false
    onMessageChanged: if (message !== "" && message !== "Working…") clearMessage.restart()
    Timer { id: clearMessage; interval: root.failed ? 10000 : 3000; onTriggered: root.message = "" }
    property bool staleLocal: false
    readonly property bool localPending: actions.some(x => x.payload.op === "local") || (action.running && current.payload?.op === "local")
    property var requests: []
    property var actions: []
    property string reading: ""
    property bool initialized: false
    signal actionFinished(var payload, bool success)
    readonly property bool busy: action.running
    readonly property bool open: Launcher.sidebarOpen && !Lock.locked && !Idle.screensOff
    readonly property string section: ({ audio: "audio", displays: "displays", power: "power", network: "network", system: "system", clipboard: "clipboard", capture: "capture", calendar: "calendar" })[Launcher.sidebarTab] || ""

    function refresh(section) {
        if (!section || requests.indexOf(section) >= 0) return
        requests = requests.concat([section]); pump()
    }
    function pump() {
        if (fetch.running || requests.length === 0) return
        reading = requests[0]; requests = requests.slice(1)
        fetch.command = ["shell-sidebar-backend", "snapshot", reading]
        fetch.running = true
    }
    function act(payload, quiet) {
        actions = actions.concat([{ payload, quiet: quiet || false }]); runAction()
    }
    property var current: ({})
    function runAction() {
        if (action.running || actions.length === 0) return
        current = actions[0]; actions = actions.slice(1)
        if (!current.quiet) { message = "Working…"; failed = false }
        action.command = ["shell-sidebar-backend", "action", JSON.stringify(current.payload)]
        action.running = true
    }
    function preference(key, value) {
        const next = Object.assign({}, local); next[key] = value; local = next
        const payload = { op: "local" }; payload[key] = value
        act(payload, true)
    }
    function favorite(id) {
        const list = local.favorites || []
        preference("favorites", list.indexOf(id) >= 0 ? list.filter(x => x !== id) : list.concat([id]))
    }
    function copy(text) { act({ op: "copy", text }) }
    function notify(text) { Quickshell.execDetached(["notify-send", "-a", "Sidebar", "--", text]) }

    Process {
        id: fetch
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("Sidebar snapshot:", text.trim()) }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (result.ok) {
                        if (result.section === "local" && root.localPending) { root.staleLocal = true; return }
                        root[result.section] = result.data
                        if (result.section === "local" && !root.initialized) {
                            root.initialized = true
                            if (!Launcher.sidebarOpen) Launcher.sidebarTab = result.data.lastTab || "home"
                        }
                    } else { root.failed = true; root.message = result.message }
                } catch (e) { root.message = "Could not read " + root.reading; root.failed = true }
            }
        }
        onExited: Qt.callLater(root.pump)
    }
    Process {
        id: action
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("Sidebar action:", text.trim()) }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (!root.current.quiet || !result.ok) {
                        root.message = result.message || "Done"; root.failed = !result.ok
                    }
                    root.actionFinished(root.current.payload, !!result.ok)
                } catch (e) { root.message = "Action failed"; root.failed = true }
            }
        }
        onExited: {
            const op = root.current.payload?.op || ""
            if (op.startsWith("task-") || op.startsWith("pin-") || op === "clipboard-pin") root.refresh("local")
            if (op === "local" && root.staleLocal && !root.localPending) { root.staleLocal = false; root.refresh("local") }
            if (root.open && !root.current.quiet) root.refresh(root.section)
            Qt.callLater(root.runAction)
        }
    }
    // Static pages refresh on entry/actions. Only live pages poll, at a lower
    // rate on battery. Audio listens to server events instead of polling.
    Timer {
        interval: Battery.saving ? 15000 : 5000
        repeat: true; running: root.open && ["power", "network", "system"].includes(root.section)
        onTriggered: root.refresh(root.section)
    }
    Process {
        running: root.open && root.section === "audio"
        command: ["shell-sidebar-backend", "watch-audio"]
        stdout: SplitParser {
            onRead: line => {
                if (/on (card|server|sink-input|source-output)/.test(line) && !audioRefresh.running) audioRefresh.start()
            }
        }
    }
    Timer { id: audioRefresh; interval: 750; onTriggered: if (root.open && root.section === "audio") root.refresh("audio") }
    readonly property real nextReminder: (local.tasks || []).filter(t => !t.done && t.due && !t.notified).reduce((soon, t) => Math.min(soon, t.due * 1000), Infinity)
    function scheduleReminder() {
        reminder.stop()
        if (Number.isFinite(nextReminder)) {
            // A failed notification retries after a minute, without busy polling.
            reminder.interval = Math.min(2147483647, nextReminder <= Date.now() ? 60000 : Math.max(1000, nextReminder - Date.now()))
            reminder.start()
        }
    }
    onLocalChanged: Qt.callLater(root.scheduleReminder)
    Timer {
        id: reminder
        onTriggered: root.refresh("local")
    }
    Connections { target: Quickshell; function onScreensChanged() { if (root.open && root.section === "displays") root.refresh("displays") } }
    onSectionChanged: if (open) refresh(section)
    onOpenChanged: {
        if (open) { refresh(section); refresh("local") }
        else {
            measuring = false
            if (initialized && local.lastTab !== Launcher.sidebarTab) preference("lastTab", Launcher.sidebarTab)
        }
    }
    Component.onCompleted: refresh("local")

    // Microphone capture is explicitly opt-in, and stops when leaving Audio.
    property bool measuring: false
    property real peak: 0
    Process {
        id: meter
        running: root.measuring && root.open && Launcher.sidebarTab === "audio"
        command: ["shell-sidebar-backend", "meter"]
        stdout: SplitParser { onRead: line => { try { root.peak = JSON.parse(line).peak } catch (e) {} } }
        onExited: root.peak = 0
    }
    property bool testing: false
    readonly property string testFile: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-mic-test.wav"
    function testMicrophone() { testing = true; micTest.running = true; testStop.restart() }
    Process {
        id: micTest
        command: ["pw-record", "--rate", "48000", root.testFile]
        onExited: code => { root.testing = false; if (code === 0) Quickshell.execDetached(["pw-play", root.testFile]) }
    }
    Timer { id: testStop; interval: 5000; onTriggered: if (micTest.running) micTest.signal(2) }

    property real sleepUntil: 0
    property real focusUntil: 0
    property real now: Date.now()
    property real awakeUntil: 0
    property int awakeMinutes: 0
    property bool inhibitBefore: false
    function awake(minutes) {
        if (awakeUntil === 0 && minutes > 0) inhibitBefore = Idle.inhibit
        awakeMinutes = minutes
        awakeUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0
        Idle.inhibit = minutes > 0 ? true : inhibitBefore
    }
    property bool dndBeforeFocus: false
    function sleep(minutes) { sleepUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0 }
    function focus(minutes) {
        if (focusUntil > 0) Notifs.dnd = dndBeforeFocus
        focusUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0
        if (minutes > 0) { dndBeforeFocus = Notifs.dnd; Notifs.dnd = true }
    }
    Timer {
        interval: 1000; repeat: true; running: root.sleepUntil > 0 || root.focusUntil > 0 || root.awakeUntil > 0
        onTriggered: {
            root.now = Date.now()
            if (root.awakeUntil > 0 && root.now >= root.awakeUntil) root.awake(0)
            if (root.sleepUntil > 0 && root.now >= root.sleepUntil) {
                for (const p of Media.players) if (p.canPause) p.pause()
                root.sleepUntil = 0; root.notify("Media sleep timer finished")
            }
            if (root.focusUntil > 0 && root.now >= root.focusUntil) {
                root.focus(0); root.notify("Focus session finished")
            }
        }
    }
}
