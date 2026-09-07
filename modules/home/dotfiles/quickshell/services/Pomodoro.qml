pragma Singleton
import QtQuick
import Quickshell

// Simple countdown; notifies through the shell's own notification daemon.
Singleton {
    id: root
    property int total: 25 * 60
    property int left: total
    property bool running: false
    readonly property string display: Math.floor(left / 60) + ":" + (left % 60 < 10 ? "0" : "") + left % 60

    function set(minutes) { running = false; total = minutes * 60; left = total }
    function toggle() { if (left === 0) left = total; running = !running }
    function reset() { running = false; left = total }

    Timer {
        interval: 1000; repeat: true; running: root.running
        onTriggered: {
            if (root.left > 0) root.left--
            if (root.left === 0) {
                root.running = false
                Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Timer", "Time's up", Math.round(root.total / 60) + " minutes are over"])
            }
        }
    }
}
