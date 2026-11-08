import QtQuick
import qs
import qs.services

Column {
    width: parent.width; spacing: 8
    SHeading { text: "Your processes" }
    Repeater {
        model: Workbench.system.processes || []
        SCard {
            required property var modelData
            property bool confirming: false
            SLabel { text: modelData.name + " · PID " + modelData.pid }
            SHint { text: modelData.cpu + "% CPU · " + SysStats.fmtBytes(modelData.memory) }
            SAction { text: confirming ? "Confirm terminate" : "Terminate"; onClicked: { if (confirming) Workbench.act({ op: "process-stop", pid: modelData.pid }); else { confirming = true; reset.start() } } }
            Timer { id: reset; interval: 4000; onTriggered: confirming = false }
        }
    }
    SHeading { text: "Failed services" }
    SHint { visible: !(Workbench.system.failed || []).length; text: "No failed units." }
    Repeater {
        model: Workbench.system.failed || []
        SCard {
            required property var modelData
            SLabel { text: modelData.name + (modelData.user ? " · user" : " · system"); color: Theme.yellow }
            SHint { text: modelData.description }
            Flow { width: parent.width; spacing: 6
                SAction { text: "Restart"; onClicked: Workbench.act({ op: "service-restart", name: modelData.name, user: modelData.user }) }
                SAction { text: "Logs"; onClicked: Apps.spawn(["ghostty", "-e", "journalctl"].concat(modelData.user ? ["--user"] : []).concat(["-b", "-u", modelData.name])) }
            }
        }
    }
    SHeading { text: "Recent errors" }
    SCard {
        SHint { text: Workbench.system.errors || "No recent errors."; maximumLineCount: 25; elide: Text.ElideRight }
        SAction { text: "Open boot error log"; onClicked: Apps.spawn(["ghostty", "-e", "journalctl", "-b", "-p", "err"]) }
    }
    SCard {
        SHint { text: "Generation: " + (Workbench.system.generation || "—") }
        Flow { width: parent.width; spacing: 6
            SAction { text: "Copy diagnostics"; onClicked: Workbench.act({ op: "diagnostics" }) }
            SAction { text: "Open system monitor"; onClicked: Apps.spawn(["ghostty", "-e", "btop"]) }
        }
        SHint { text: "Diagnostics include device names, application names and recent system errors." }
    }
}
