pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower

// Batteries of peripherals: UPower (Logitech via hidpp, headsets…) + BlueZ.
Singleton {
    id: root

    function glyphFor(type, name) {
        const n = (name || "").toLowerCase()
        if (type === UPowerDeviceType.Mouse || n.includes("mouse")) return "󰍽"
        if (type === UPowerDeviceType.Keyboard || n.includes("keyboard")) return "󰌌"
        if (type === UPowerDeviceType.Headset || type === UPowerDeviceType.Headphones || n.includes("head") || n.includes("buds")) return "󰋋"
        if (type === UPowerDeviceType.GamingInput || n.includes("controller")) return "󰊴"
        if (type === UPowerDeviceType.Phone) return "󰄜"
        return "󰂯"
    }

    readonly property var upower: UPower.devices.values
        .filter(d => d.isPresent && !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.percentage > 0)
        .map(d => ({ key: "up:" + d.nativePath, name: d.model || d.nativePath, pct: Math.round(d.percentage * 100), glyph: glyphFor(d.type, d.model), charging: d.state === UPowerDeviceState.Charging }))
    readonly property var bluetooth: Bluetooth.devices.values
        .filter(d => d.connected && d.batteryAvailable)
        .map(d => ({ key: "bt:" + d.address, name: d.name, pct: Math.round(d.battery * 100), glyph: glyphFor(null, d.name), charging: false }))

    // BlueZ and UPower can both report the same headset; prefer UPower's entry.
    readonly property var all: {
        const names = {}
        const out = upower.slice()
        for (const d of out) names[d.name.toLowerCase()] = true
        for (const d of bluetooth) if (!names[d.name.toLowerCase()]) out.push(d)
        return out
    }
}
