pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

Singleton {
    id: root
    readonly property var s: Settings.s.idle
    readonly property var cur: Battery.saving ? s.battery : s.ac
    property bool inhibit: false
    property bool screensOff: false
    property bool dimmed: false
    readonly property bool away: awayMon.isIdle
    readonly property int awaySec: 120

    function fmt(sec) { return sec <= 0 ? "never" : sec < 60 ? sec + " s" : Math.round(sec / 60) + " min" }

    function dim() {
        if (dimmed || !Brightness.present) return
        dimmed = true
        Quickshell.execDetached(["sh", "-c", "brightnessctl -q -c backlight -s && brightnessctl -q -c backlight set \"$(brightnessctl -c backlight -m | awk -F, '{v=int($4*0.3); print (v<1?1:v)\"%\"}')\""])
    }
    function undim() {
        if (!dimmed) return
        dimmed = false
        restore.running = true
    }
    Process { id: restore; command: ["brightnessctl", "-q", "-c", "backlight", "-r"]; onExited: Brightness.refresh() }
    function powerOff() {
        screensOff = true
        Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
    }

    component Monitor: IdleMonitor {
        property real sec: 0
        property bool when: true
        enabled: sec > 0 && when
        timeout: Math.max(1, sec)
        respectInhibitors: true
    }

    Monitor { id: awayMon; sec: root.awaySec }
    Monitor {
        sec: root.cur.dim; when: !root.inhibit && Brightness.present
        onIsIdleChanged: isIdle ? root.dim() : root.undim()
    }
    Monitor {
        sec: root.cur.lock; when: !root.inhibit && !Lock.locked
        onIsIdleChanged: if (isIdle) Lock.lock()
    }
    Monitor {
        sec: root.cur.screenOff; when: !root.inhibit
        onIsIdleChanged: isIdle ? root.powerOff() : root.screensOff = false
    }
    Monitor {
        sec: root.s.lockedScreenOff; when: Lock.locked
        onIsIdleChanged: isIdle ? root.powerOff() : root.screensOff = false
    }
    Monitor {
        sec: root.cur.suspend; when: !root.inhibit
        onIsIdleChanged: if (isIdle) { Lock.lock(); Quickshell.execDetached(["systemctl", "suspend"]) }
    }
    Connections {
        target: Lock
        function onLockedChanged() { if (!Lock.locked) root.undim() }
    }

    Process {
        running: true
        command: ["swayidle", "-w", "before-sleep", "echo lock; sleep 0.5", "lock", "echo lock"]
        stdout: SplitParser { onRead: line => { if (line.trim() === "lock") Lock.lock() } }
    }

    IpcHandler {
        target: "idle"
        function toggleInhibit(): void { root.inhibit = !root.inhibit }
        function inhibit(on: bool): void { root.inhibit = on }
    }
}
