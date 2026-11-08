import QtQuick
import QtQuick.Controls
import qs.services

Column {
    id: root
    width: parent.width; spacing: 8
    property bool confirmClear: false
    SHeading { text: "Clipboard" }
    SField { id: query; placeholderText: "Search history and pinned snippets…" }
    SCard {
        SToggle { text: "Pause clipboard history"; checked: Workbench.clipboard.paused || false; onToggled: Workbench.act({ op: "clipboard-pause", paused: checked }) }
        SAction { text: root.confirmClear ? "Confirm clear history" : "Clear history"; onClicked: { if (root.confirmClear) { Workbench.act({ op: "clipboard-wipe" }); root.confirmClear = false } else { root.confirmClear = true; clearTimeout.restart() } } }
        SHint { text: "Pinned copies are kept separately. Pausing prevents new entries from being stored." }
    }
    Timer { id: clearTimeout; interval: 5000; onTriggered: root.confirmClear = false }
    SHeading { text: "Pinned" }
    Repeater {
        model: (Workbench.local.pins || []).filter(p => p.text.toLowerCase().includes(query.text.toLowerCase()))
        SCard {
            required property var modelData
            Image { visible: modelData.image; width: parent.width; height: visible ? 110 : 0; source: modelData.image ? "file://" + modelData.path : ""; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.width: 420 }
            SLabel { text: modelData.image ? "Pinned image" : modelData.text; maximumLineCount: 4; elide: Text.ElideRight }
            Row { spacing: 6
                SAction { text: "Copy"; onClicked: Workbench.act({ op: "pin-copy", id: modelData.id }) }
                SAction { text: "Unpin"; onClicked: Workbench.act({ op: "pin-delete", id: modelData.id }) }
            }
        }
    }
    SHeading { text: "Recent" }
    Repeater {
        model: (Workbench.clipboard.items || []).filter(p => p.text.toLowerCase().includes(query.text.toLowerCase()))
        SCard {
            required property var modelData
            Image { visible: modelData.image && modelData.preview !== ""; width: parent.width; height: visible ? 110 : 0; source: visible ? "file://" + modelData.preview : ""; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.width: 420 }
            SLabel { text: modelData.text; maximumLineCount: 4; elide: Text.ElideRight }
            Flow { width: parent.width; spacing: 6
                SAction { text: "Copy"; onClicked: Workbench.act({ op: "clipboard-copy", id: modelData.id }) }
                SAction { text: "Pin"; onClicked: Workbench.act({ op: "clipboard-pin", id: modelData.id, text: modelData.text, image: modelData.image }) }
                SAction { text: "Delete"; onClicked: Workbench.act({ op: "clipboard-delete", id: modelData.id }) }
            }
        }
    }
    SHint { visible: !(Workbench.clipboard.items || []).length; text: "No clipboard history yet." }
}
