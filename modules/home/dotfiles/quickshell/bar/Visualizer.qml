import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// cava bars; only runs while `active` so it costs nothing when hidden.
Item {
    id: viz
    property bool active: false
    property color color: Theme.accent
    property var bars: []
    implicitHeight: 40

    Process {
        id: cava
        running: viz.active
        command: ["cava", "-p", Quickshell.shellDir + "/scripts/cava.conf"]
        stdout: SplitParser {
            onRead: line => { const v = line.split(";").filter(s => s !== "").map(Number); if (v.length > 4) viz.bars = v }
        }
        onRunningChanged: if (!running) viz.bars = []
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 2
        readonly property int n: Math.max(1, viz.bars.length)
        Repeater {
            model: viz.bars
            Rectangle {
                required property int modelData
                required property int index
                width: Math.max(1, (viz.width - row.spacing * (row.n - 1)) / row.n)
                height: Math.max(2, viz.height * modelData / 100)
                anchors.bottom: parent.bottom
                radius: 1
                color: viz.color
                opacity: 0.35 + 0.65 * modelData / 100
                Behavior on height { enabled: !Settings.s.appearance.reducedMotion; NumberAnimation { duration: 40 } }
            }
        }
    }
}
