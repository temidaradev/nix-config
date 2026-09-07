pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Todo list persisted as JSON in ~/.local/state/quickshell/todo.json.
Singleton {
    id: root
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    property var items: []          // [{text, done}]
    readonly property int open: items.filter(i => !i.done).length

    FileView {
        id: file
        path: root.stateDir + "/todo.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.items = JSON.parse(text()) } catch (e) { root.items = [] } }
        onLoadFailed: root.items = []
    }
    Process { id: mkdir; command: ["mkdir", "-p", root.stateDir]; running: true }

    function save() { file.setText(JSON.stringify(items)) }
    function add(text) { text = text.trim(); if (text === "") return; items = items.concat([{ text, done: false }]); save() }
    function toggle(i) { const a = items.slice(); a[i] = { text: a[i].text, done: !a[i].done }; items = a; save() }
    function remove(i) { items = items.filter((_, k) => k !== i); save() }
    function clearDone() { items = items.filter(i => !i.done); save() }
}
