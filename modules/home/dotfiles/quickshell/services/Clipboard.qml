pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history via cliphist (wl-paste --watch cliphist store runs from niri).
Singleton {
    id: root
    property var items: []          // [{id, text, image}]

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.items = text.split("\n").filter(l => l !== "").slice(0, 60).map(l => {
                const i = l.indexOf("\t")
                const id = l.slice(0, i), body = l.slice(i + 1)
                return { id, text: body.replace(/\s+/g, " ").trim(), image: /^\[\[ binary data .* (png|jpg|jpeg|gif|webp|bmp) \]\]$/i.test(body) }
            })
        }
    }
    function refresh() { list.running = true }
    function copy(item) { Quickshell.execDetached(["sh", "-c", "cliphist decode " + item.id + " | wl-copy"]) }
    function remove(item) { Quickshell.execDetached(["sh", "-c", "printf '%s\\t' '" + item.id + "' | cliphist delete"]); items = items.filter(i => i.id !== item.id) }
    function wipe() { Quickshell.execDetached(["cliphist", "wipe"]); items = [] }
}
