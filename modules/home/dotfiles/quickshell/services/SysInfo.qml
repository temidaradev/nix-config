pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Static hardware/software facts for the System tab; read once.
Singleton {
    id: root
    property string os: ""
    property string kernel: ""
    property string cpu: ""
    property string gpu: ""
    property string host: ""
    property string shell: "quickshell"

    Process {
        running: true
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; printf 'os=%s\\n' \"$PRETTY_NAME\"; printf 'kernel=%s\\n' \"$(uname -r)\"; printf 'cpu=%s\\n' \"$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')\"; printf 'gpu=%s\\n' \"$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //; s/ (rev.*//')\"; printf 'host=%s\\n' \"$(cat /sys/devices/virtual/dmi/id/product_version 2>/dev/null || cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)\"; printf 'shell=%s\\n' \"quickshell $(qs --version 2>/dev/null | head -1 | sed 's/[^0-9.]*//')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const i = l.indexOf("="); if (i < 0) continue
                    const k = l.slice(0, i), v = l.slice(i + 1).trim()
                    if (k === "os") root.os = v
                    else if (k === "kernel") root.kernel = v
                    else if (k === "cpu") root.cpu = v
                    else if (k === "gpu") root.gpu = v
                    else if (k === "host") root.host = v
                    else if (k === "shell") root.shell = v
                }
            }
        }
    }
}
