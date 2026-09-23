import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

Column {
    id: tp
    property string by: "cpu"
    property int count: 5
    property var rows: []
    width: parent.width; spacing: 2

    function clean(n) { return n.replace(/^\./, "").replace(/-wra(p(p(ed?)?)?)?$/, "") }

    Process {
        id: proc
        command: tp.by === "cpu"
            ? ["sh", "-c", "top -b -n 2 -d 0.7 -w 512 | awk '/^top -/{i++} i==2 && $1 ~ /^[0-9]+$/ && $12 != \"top\" {c[$12]+=$9} END{for(k in c) if (c[k] > 0) printf \"%.1f\\t%s\\n\", c[k], k}' | sort -rn | head -" + tp.count]
            : ["sh", "-c", "ps -eo rss=,comm= | awk '{a[$2]+=$1} END{for(k in a) print a[k]\"\\t\"k}' | sort -rn | head -" + tp.count]
        stdout: StdioCollector {
            onStreamFinished: tp.rows = text.trim().split("\n").filter(l => l.includes("\t")).map(l => {
                const [v, name] = l.split("\t")
                return { name: tp.clean(name), value: parseFloat(v) || 0 }
            })
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }

    Text { visible: tp.rows.length === 0; text: "…"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
    Repeater {
        model: tp.rows
        Item {
            required property var modelData
            readonly property real pct: tp.by === "cpu" ? modelData.value / Math.max(1, SysInfo.threads) : modelData.value * 1024 / Math.max(1, SysStats.memTotal) * 100
            width: tp.width; height: 22
            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; height: 2; radius: 1; width: parent.width * Math.min(1, parent.pct / 100); color: tp.by === "cpu" ? Theme.accent : Theme.green; opacity: 0.6 }
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 90; elide: Text.ElideRight; text: modelData.name; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: tp.by === "cpu" ? parent.pct.toFixed(1) + "%" : SysStats.fmtBytes(modelData.value * 1024, 0)
                color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
            }
        }
    }
}
