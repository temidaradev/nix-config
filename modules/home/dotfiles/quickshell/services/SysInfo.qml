pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Static hardware/software facts for the System tab; read once at start.
Singleton {
    id: root
    property string os: ""
    property string kernel: ""
    property string cpu: ""
    property string gpu: ""
    property string gpuDriver: ""
    property string host: ""
    property string board: ""
    property string bios: ""
    property string shell: "quickshell"
    property string wm: ""
    property string memory: ""
    property string rootDisk: ""
    property string locale: ""
    property string session: ""
    property string user: ""
    property string display: ""
    property int packages: 0

    Process {
        running: true
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            echo "os=$PRETTY_NAME"
            echo "kernel=$(uname -r)"
            echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//; s/ *[0-9]*-Core Processor//; s/(R)//g; s/(TM)//g')"
            gpu=""
            if command -v lspci >/dev/null; then gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //; s/ (rev.*//; s/Corporation //')
            else for c in /sys/class/drm/card?; do v=$(cat $c/device/vendor 2>/dev/null); d=$(cat $c/device/device 2>/dev/null); [ -n "$v" ] && gpu="pci $v:$d"; done; fi
            echo "gpu=$gpu"
            for c in /sys/class/drm/card?; do drv=$(basename "$(readlink $c/device/driver 2>/dev/null)"); [ -n "$drv" ] && echo "gpuDriver=$drv"; done
            echo "host=$(cat /sys/devices/virtual/dmi/id/product_version 2>/dev/null || cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
            echo "board=$(cat /sys/devices/virtual/dmi/id/board_vendor 2>/dev/null) $(cat /sys/devices/virtual/dmi/id/board_name 2>/dev/null)"
            echo "bios=$(cat /sys/devices/virtual/dmi/id/bios_version 2>/dev/null) ($(cat /sys/devices/virtual/dmi/id/bios_date 2>/dev/null))"
            echo "shell=quickshell $(qs --version 2>/dev/null | head -1 | grep -oE '[0-9]+(\\.[0-9]+)+' | head -1)"
            echo "wm=$(niri --version 2>/dev/null | sed 's/ (.*//')"
            echo "memory=$(awk '/^MemTotal/{printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
            echo "rootDisk=$(df -h / 2>/dev/null | awk 'NR==2{print $3" / "$2" ("$5")"}')"
            echo "locale=$LANG"
            echo "session=$XDG_SESSION_TYPE / $XDG_CURRENT_DESKTOP"
            echo "user=$USER@$(hostname)"
            echo "packages=$(nix-store --query --requisites /run/current-system 2>/dev/null | wc -l)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const i = l.indexOf("="); if (i < 0) continue
                    const k = l.slice(0, i), v = l.slice(i + 1).trim()
                    if (k === "packages") root.packages = parseInt(v) || 0
                    else if (root.hasOwnProperty(k)) root[k] = v
                }
            }
        }
    }

    // Display: model and the current mode, from niri.
    Process {
        running: true
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outs = JSON.parse(text)
                    root.display = Object.values(outs).map(o => {
                        const m = o.current_mode !== null && o.current_mode !== undefined ? o.modes[o.current_mode] : null
                        const mode = m ? m.width + "x" + m.height + " @ " + Math.round(m.refresh_rate / 1000) + " Hz" : "off"
                        const scale = o.logical && o.logical.scale !== 1 ? "  ×" + o.logical.scale : ""
                        return (o.model || o.name) + "  " + mode + scale
                    }).join("\n")
                } catch (e) { root.display = "" }
            }
        }
    }
}
