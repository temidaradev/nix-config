pragma Singleton
import QtQuick
import Quickshell

// Desktop-entry lookup shared by the bar, sidebar, launcher and switcher.
Singleton {
    id: root
    readonly property var all: DesktopEntries.applications.values
    property var _entries: ({})
    property var _icons: ({})
    property int version: 0
    onAllChanged: { _entries = {}; _icons = {} }

    function entry(id) {
        version
        if (!id) return null
        const l = id.toLowerCase()
        const cache = _entries
        if (l in cache) return cache[l]
        const found = all.find(e => e.id.toLowerCase() === l)
            || all.find(e => (e.startupClass || "").toLowerCase() === l)
            || all.find(e => e.id.toLowerCase().endsWith("." + l) || l.endsWith("." + e.id.toLowerCase()))
            || all.find(e => e.name.toLowerCase() === l)
            || null
        cache[l] = found || guess(l)
        return cache[l]
    }

    readonly property var stopwords: ["org", "com", "net", "io", "dev", "app", "desktop", "the", "bin", "exe", "wrapped"]
    function tokens(s) { return (s || "").toLowerCase().split(/[^a-z0-9]+/).filter(t => t.length >= 2 && stopwords.indexOf(t) < 0) }

    function guess(l) {
        const want = tokens(l)
        if (want.length === 0) return null
        const shortlist = all.filter(e => !e.noDisplay).map(e => {
            const hay = [e.id, e.name, e.startupClass, e.execString, e.icon].join(" ").toLowerCase()
            return { e, s: want.filter(t => hay.includes(t)).length }
        }).filter(x => x.s > 0).sort((a, b) => b.s - a.s).slice(0, 40).map(x => x.e)
        if (shortlist.length === 0) return null
        const key = "app:v1:" + l + ":" + shortlist.map(e => e.id).join(",")
        const pick = answers => {
            const a = answers && answers.entry
            if (!a || a.choice === "none" || (a.probabilities[a.choice] ?? 0) < 0.5) return null
            return shortlist.find(e => e.id === a.choice) || null
        }
        const hit = Jev.peek(key)
        if (hit) return pick(hit)
        const criteria = { none: "None of these installed applications opened the window" }
        for (const e of shortlist)
            criteria[e.id] = [e.name, e.genericName, e.startupClass ? "window class " + e.startupClass : "", "runs " + e.execString].filter(s => s).join("; ")
        Jev.ask(key, { app_id: l }, {
            entry: {
                type: "choice",
                instructions: "A Wayland window reports the app_id in `app_id`. Which installed desktop entry is the application that owns this window?",
                criteria
            }
        }, answers => {
            const e = pick(answers)
            if (!e) return
            _entries[l] = e
            _icons = {}
            version++
        })
        return null
    }

    function spawn(cmd, dir) {
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", "--slice=app.slice", "--", "env", "-C", dir || Quickshell.env("HOME")].concat(Array.from(cmd)))
    }
    function launch(e) {
        spawn(e.runInTerminal ? ["ghostty", "-e"].concat(Array.from(e.command)) : Array.from(e.command), e.workingDirectory)
    }
    function icon(id) {
        version
        const k = id || ""
        const cache = _icons
        if (k in cache) return cache[k]
        const e = entry(id)
        return cache[k] = Quickshell.iconPath(e ? e.icon : k, "application-x-executable")
    }
}
