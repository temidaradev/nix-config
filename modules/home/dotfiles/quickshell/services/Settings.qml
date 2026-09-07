pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Built-in defaults, overridden by ~/.config/quickshell/settings.json which
// hjem generates from modules/home/dotfiles/quickshell-settings.nix.
Singleton {
    id: root

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
    readonly property var s: merge(builtin, nix)

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
}
