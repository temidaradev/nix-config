import QtQuick
import QtQuick.Controls
import qs
import qs.services

Column {
    id: root
    width: parent.width; spacing: 8
    property bool showCompleted: false
    SHeading { text: "Tasks & reminders" }
    SCard {
        SField { id: task; placeholderText: "What needs doing?"; onAccepted: addTask.clicked() }
        SField { id: due; placeholderText: "Optional reminder: YYYY-MM-DD HH:MM" }
        SAction { id: addTask; text: "Add task"; enabled: task.text.trim() !== "" && !Workbench.busy; onClicked: Workbench.act({ op: "task-add", text: task.text, due: due.text }) }
        Connections {
            target: Workbench
            function onActionFinished(payload, success) {
                if (success && payload.op === "task-add" && payload.text === task.text && payload.due === due.text) { task.clear(); due.clear() }
            }
        }
        SToggle { text: "Show completed"; checked: root.showCompleted; onToggled: root.showCompleted = checked }
    }
    Repeater {
        model: (Workbench.local.tasks || []).filter(t => root.showCompleted || !t.done).slice().sort((a, b) => (a.done - b.done) || ((a.due || Infinity) - (b.due || Infinity)))
        SCard {
            required property var modelData
            SLabel { text: modelData.text; font.strikeout: modelData.done; color: modelData.due && modelData.due * 1000 < Date.now() && !modelData.done ? Theme.yellow : Theme.fg }
            SHint { visible: !!modelData.due; text: modelData.due ? Qt.formatDateTime(new Date(modelData.due * 1000), "ddd d MMM · HH:mm") : "" }
            Row { spacing: 6
                SAction { text: modelData.done ? "Undo" : "Complete"; onClicked: Workbench.act({ op: "task-toggle", id: modelData.id }) }
                SAction { text: "Delete"; onClicked: Workbench.act({ op: "task-delete", id: modelData.id }) }
            }
        }
    }
    SHeading { text: "Focus timer" }
    SCard {
        SLabel { text: Workbench.focusUntil > 0 ? "Focus · " + Media.fmtTime(Math.max(0, (Workbench.focusUntil - Workbench.now) / 1000)) : "Start a session with Do Not Disturb" }
        Flow { width: parent.width; spacing: 6
            Repeater { model: [15, 25, 45, 60]; SAction { required property int modelData; text: modelData + " min"; onClicked: Workbench.focus(modelData) } }
            SAction { visible: Workbench.focusUntil > 0; text: "End session"; onClicked: Workbench.focus(0) }
        }
    }
    SHeading { text: "Scratchpad" }
    SCard {
        TextArea {
            id: notes
            width: parent.width; height: 160; wrapMode: TextEdit.Wrap
            color: Theme.fg; placeholderText: "Notes saved on this machine…"; placeholderTextColor: Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize; selectByMouse: true
            Component.onCompleted: text = Workbench.local.notes || ""
            Connections { target: Workbench; function onLocalChanged() { if (!notes.activeFocus) notes.text = Workbench.local.notes || "" } }
            onTextChanged: if (activeFocus) saveNotes.restart()
            background: Rectangle { color: "#16000000"; radius: Theme.radius }
        }
        Timer { id: saveNotes; interval: 800; onTriggered: Workbench.preference("notes", notes.text) }
        Component.onDestruction: if (saveNotes.running) Workbench.preference("notes", notes.text)
    }
}
