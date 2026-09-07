pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lock state; the surface lives in bar/LockScreen.qml. `qs ipc call lock lock`.
Singleton {
    id: root
    property bool locked: false
    function lock() { locked = true }
    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function toggle(): void { root.locked = !root.locked }
    }
}
