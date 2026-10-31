pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Batteries of mice UPower can't see: LXDDZ 2.4G receivers and Razer mice
// (see pkgs/mouse-battery). `mice` lists the ones currently reporting.
Singleton {
    id: root

    property var all: []
    readonly property var mice: all.filter(m => m.connected && m.level >= 0)
    readonly property bool connected: mice.length > 0

    Process {
        id: proc
        running: true
        command: ["mouse-battery"]
        stdout: SplitParser {
            onRead: data => {
                try { root.all = JSON.parse(data).mice ?? [] } catch (e) { console.log("mouse-battery:", e, data) }
            }
        }
        onExited: { root.all = []; restart.start() }
    }
    Timer { id: restart; interval: 5000; onTriggered: proc.running = true }
}
