pragma Singleton
import QtQuick
import Quickshell

// Desktop-entry lookup shared by the bar, sidebar, launcher and switcher.
Singleton {
    readonly property var all: DesktopEntries.applications.values

    function entry(id) {
        if (!id) return null
        const l = id.toLowerCase()
        return all.find(e => e.id.toLowerCase() === l)
            || all.find(e => e.id.toLowerCase().endsWith("." + l) || l.endsWith("." + e.id.toLowerCase()))
            || all.find(e => e.name.toLowerCase() === l)
            || null
    }
    function icon(id) {
        const e = entry(id)
        return Quickshell.iconPath(e ? e.icon : (id || ""), "application-x-executable")
    }
}
