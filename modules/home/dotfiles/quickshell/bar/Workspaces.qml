import QtQuick
import qs
import qs.services

// niri workspaces for this output; the active one gets the accent pill.
Row {
    id: root
    property string screenName: ""
    spacing: 2
    height: Theme.barHeight

    readonly property var list: Niri.workspaces.filter(w => root.screenName === "" || w.output === root.screenName)

    Repeater {
        model: root.list
        BarButton {
            required property var modelData
            readonly property bool active: modelData.is_active
            readonly property bool occupied: modelData.active_window_id !== null && modelData.active_window_id !== undefined
            padding: 8
            color: active ? Theme.accent : (hovered ? "#2affffff" : "transparent")
            BarText {
                text: modelData.name || String(modelData.idx)
                font.bold: active
                color: active ? "#1b1e20" : (occupied ? Theme.fg : Theme.fgDim)
            }
            onClicked: Niri.focusWorkspace(modelData.idx)
            onWheel: e => Niri.action(e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
        }
    }
}
