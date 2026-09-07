pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The laptop's own battery (UPower display device). `present` is false on the desktop.
Singleton {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.isLaptopBattery && dev.isPresent
    readonly property int pct: present ? Math.round(dev.percentage * 100) : 0
    readonly property bool charging: present && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: present && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool onAc: charging || full || (present && UPower.onBattery === false)
    readonly property real timeLeft: present ? (charging ? dev.timeToFull : dev.timeToEmpty) : 0   // seconds
    readonly property bool low: present && !onAc && pct <= 15

    readonly property string glyph: {
        if (!present) return ""
        if (charging) return "󰂄"
        if (full) return "󰁹"
        const g = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        return g[Math.min(10, Math.floor(pct / 10))]
    }
    readonly property string timeText: {
        if (!present || timeLeft <= 0) return full ? "Full" : ""
        const h = Math.floor(timeLeft / 3600), m = Math.floor(timeLeft % 3600 / 60)
        return (h > 0 ? h + "h " : "") + m + "m " + (charging ? "to full" : "left")
    }

    property bool warned: false
    onLowChanged: {
        if (low && !warned) { warned = true; Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Battery", "Battery low", pct + "% remaining"]) }
        if (!low) warned = false
    }
}
