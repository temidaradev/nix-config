pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Three layers: built-in defaults < ~/.config/quickshell/settings.json (from
// Nix, via hjem) < ~/.local/state/quickshell/settings.json (the Settings window).
Singleton {
    id: root
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string statePath: stateDir + "/settings.json"

    readonly property var builtin: ({
        appearance: { accent: "#3daee9", panelOpacity: 0.95, barHeight: 36, radius: 4, font: "JetBrainsMono Nerd Font", fontSize: 10 },
        bar: { tray: true, layout: true, volume: true, bluetooth: true, battery: true, cpu: true, memory: true, temps: true, disk: true, network: true,
               notifications: true, control: true, sidebar: true, nowPlaying: true, marqueeWidth: 220, clockFormat: "HH:mm", dateFormat: "ddd d MMM" },
        pinned: ["org.kde.dolphin", "zen-beta", "code", "dev.zed.Zed", "discord", "moe.kopuz.kopuz", "com.mitchellh.ghostty", "steam", "thunderbird", "org.jellyfin.JellyfinDesktop"],
        weather: { city: "Istanbul" },
        osd: { timeoutMs: 1500, bottomMargin: 90 },
        notifications: { timeoutMs: 6000, maxPopups: 5 },
        wallpaper: ""
    })
    property var nix: ({})
    property var overrides: ({})
    readonly property var s: merge(merge(builtin, nix), overrides)
    readonly property bool hasOverrides: Object.keys(overrides).length > 0

    function merge(a, b) {
        const out = {}
        for (const k in a) out[k] = a[k]
        for (const k in b) {
            const v = b[k]
            out[k] = (v && typeof v === "object" && !Array.isArray(v) && a[k] && typeof a[k] === "object" && !Array.isArray(a[k])) ? merge(a[k], v) : v
        }
        return out
    }

    FileView {
        path: Quickshell.shellDir + "/settings.json"
        onLoaded: { try { root.nix = JSON.parse(text()) } catch (e) { console.log("settings.json:", e) } }
    }
    FileView {
        id: state
        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.overrides = JSON.parse(text()) } catch (e) { root.overrides = {} } }
        onLoadFailed: root.overrides = {}
    }
    Process { command: ["mkdir", "-p", root.stateDir]; running: true }

    // set("bar.cpu", false) / set("appearance.accent", "#ff0000")
    function set(path, value) {
        const keys = path.split(".")
        const o = JSON.parse(JSON.stringify(overrides))
        let cur = o
        for (let i = 0; i < keys.length - 1; i++) { if (!cur[keys[i]] || typeof cur[keys[i]] !== "object") cur[keys[i]] = {}; cur = cur[keys[i]] }
        cur[keys[keys.length - 1]] = value
        overrides = o
        state.setText(JSON.stringify(o, null, 2))
    }
    function get(path) { return path.split(".").reduce((o, k) => (o === undefined || o === null) ? undefined : o[k], s) }
    function reset() { overrides = {}; state.setText("{}") }

    // Nix snippet of the effective settings, for quickshell-settings.nix
    function toNix(v, indent) {
        const pad = "  ".repeat(indent)
        if (Array.isArray(v)) return "[ " + v.map(x => toNix(x, indent)).join(" ") + " ]"
        if (v && typeof v === "object") return "{\n" + Object.keys(v).map(k => pad + "  " + k + " = " + toNix(v[k], indent + 1) + ";").join("\n") + "\n" + pad + "}"
        if (typeof v === "string") return "\"" + v.replace(/"/g, "\\\"") + "\""
        return String(v)
    }
    function exportNix() {
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(toNix(s, 0)).replace(/'/g, "'\\''") + " | wl-copy && notify-send -a Settings 'Copied Nix snippet' 'Paste into modules/home/dotfiles/quickshell-settings.nix'"])
    }
}
