import QtQuick
import Quickshell.Widgets
import qs
import qs.services

// niri workspaces for this output; the active one gets the accent pill,
// each pill shows the apps that live on it.
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
            readonly property var apps: Niri.wsApps[modelData.id] ?? []
            padding: 8
            color: active ? Theme.accent : (hovered ? "#2affffff" : "transparent")
            BarText {
                text: modelData.name || String(modelData.idx)
                font.bold: active
                color: active ? "#1b1e20" : (apps.length > 0 ? Theme.fg : Theme.fgDim)
            }
            Repeater {
                model: Settings.s.bar.workspaceIcons ? apps : []
                IconImage {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 15
                    asynchronous: true
                    source: Apps.icon(modelData)
                }
            }
            onClicked: Niri.focusWorkspace(modelData.idx)
            onWheel: e => Niri.action(e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
        }
    }
}
