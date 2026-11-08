import QtQuick
import qs.services

Column {
    id: root
    property var tabs: []
    function moveFavorite(id, delta) {
        const list = (Workbench.local.favorites || []).slice()
        const at = list.indexOf(id), next = at + delta
        if (at < 0 || next < 0 || next >= list.length) return
        list.splice(at, 1); list.splice(next, 0, id); Workbench.preference("favorites", list)
    }
    width: parent.width; spacing: 8
    SHeading { text: "Pinned controls" }
    SCard {
        Flow { width: parent.width; spacing: 6
            Repeater {
                model: (Workbench.local.favorites || []).map(id => root.tabs.find(t => t.id === id)).filter(t => t)
                SAction { required property var modelData; text: modelData.glyph + " " + modelData.label; onClicked: Launcher.sidebarTab = modelData.id }
            }
        }
        SToggle { id: customize; text: "Customize pinned controls" }
        Flow { visible: customize.checked; width: parent.width; spacing: 6
            Repeater { model: root.tabs.filter(t => t.id !== "home"); SAction { required property var modelData; text: modelData.label; selected: (Workbench.local.favorites || []).indexOf(modelData.id) >= 0; onClicked: Workbench.favorite(modelData.id) } }
        }
        Repeater {
            model: customize.checked ? (Workbench.local.favorites || []) : []
            Row { required property string modelData; spacing: 6
                SAction { text: "↑"; onClicked: root.moveFavorite(modelData, -1) }
                SAction { text: "↓"; onClicked: root.moveFavorite(modelData, 1) }
                SHint { width: 200; text: root.tabs.find(t => t.id === modelData)?.label || modelData }
            }
        }
    }
    SHeading { text: "Quick launch" }
    SCard {
        Flow { width: parent.width; spacing: 6
            Repeater { model: Settings.s.pinned.map(id => Apps.all.find(e => e.id.toLowerCase() === id.toLowerCase())).filter(e => e); SAction { required property var modelData; text: modelData.name; onClicked: { Apps.launch(modelData); Launcher.sidebarOpen = false } } }
        }
    }
    SCard {
        visible: Capture.recording || Capture.remaining > 0
        SLabel { text: Capture.recording ? "Recording · " + Media.fmtTime(Capture.recSeconds) : "Recording starts in " + Capture.remaining + "…" }
        SAction { text: "Recording controls"; onClicked: Launcher.sidebarTab = "capture" }
    }
    SCard {
        visible: (Workbench.local.tasks || []).some(t => !t.done)
        SLabel { text: (Workbench.local.tasks || []).filter(t => !t.done).length + " tasks remaining" }
        Repeater { model: (Workbench.local.tasks || []).filter(t => !t.done).slice(0, 3); SHint { required property var modelData; text: "• " + modelData.text } }
        SAction { text: "Tasks & reminders"; onClicked: Launcher.sidebarTab = "tasks" }
    }
}
