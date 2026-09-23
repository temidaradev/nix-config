pragma Singleton
import QtQuick
import Quickshell

// Desktop-entry lookup shared by the bar, sidebar, launcher and switcher.
Singleton {
    id: root
    readonly property var all: DesktopEntries.applications.values
    property var _entries: ({})
    property var _icons: ({})
    onAllChanged: { _entries = {}; _icons = {} }

    function entry(id) {
        if (!id) return null
        const l = id.toLowerCase()
        const cache = _entries
        if (l in cache) return cache[l]
        return cache[l] = all.find(e => e.id.toLowerCase() === l)
            || all.find(e => e.id.toLowerCase().endsWith("." + l) || l.endsWith("." + e.id.toLowerCase()))
            || all.find(e => e.name.toLowerCase() === l)
            || null
    }
    function spawn(cmd, dir) {
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", "--slice=app.slice", "--", "env", "-C", dir || Quickshell.env("HOME")].concat(Array.from(cmd)))
    }
    function launch(e) {
        spawn(e.runInTerminal ? ["ghostty", "-e"].concat(Array.from(e.command)) : Array.from(e.command), e.workingDirectory)
    }
    function icon(id) {
        const k = id || ""
        const cache = _icons
        if (k in cache) return cache[k]
        const e = entry(id)
        return cache[k] = Quickshell.iconPath(e ? e.icon : k, "application-x-executable")
    }
}
