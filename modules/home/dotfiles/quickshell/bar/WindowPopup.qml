import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "window"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""

    readonly property var w: Niri.windows.find(x => x.id === Niri.focusedWindow) ?? null
    readonly property var ws: w ? Niri.workspaces.find(s => s.id === w.workspace_id) ?? null : null
    readonly property var siblings: ws ? Niri.workspaces.filter(s => s.output === ws.output) : []
    readonly property var others: w ? Niri.windows.filter(x => x.workspace_id === w.workspace_id && x.id !== w.id) : []
    onWChanged: if (!w) Launcher.menu = ""
    function act(...args) { Niri.action(...args) }

    Row {
        width: parent.width; spacing: 12
        IconImage { anchors.verticalCenter: parent.verticalCenter; implicitSize: 36; asynchronous: true; source: pop.w ? Apps.icon(pop.w.app_id) : "" }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 48; spacing: 2
            Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: pop.w ? (pop.w.title || pop.w.app_id) : ""; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: pop.w ? [Apps.entry(pop.w.app_id)?.name ?? pop.w.app_id, pop.ws ? "workspace " + (pop.ws.name || pop.ws.idx) : "", pop.w.is_floating ? "floating" : "tiled"].filter(s => s).join("  ·  ") : ""
                color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
            }
        }
    }

    Flow {
        width: parent.width; spacing: 6
        PopupButton { label: "󰊓  Fullscreen"; onClicked: { pop.act("fullscreen-window", "--id", String(pop.w.id)); Launcher.menu = "" } }
        PopupButton { label: "󰁌  Maximize"; onClicked: { pop.act("maximize-column"); Launcher.menu = "" } }
        PopupButton { label: pop.w?.is_floating ? "󰕰  Tile" : "󰉈  Float"; onClicked: { pop.act("toggle-window-floating", "--id", String(pop.w.id)); Launcher.menu = "" } }
        PopupButton { label: "󰘞  Center"; onClicked: { pop.act("center-column"); Launcher.menu = "" } }
        PopupButton { label: "󰅖  Close"; danger: true; onClicked: { Niri.closeWindow(pop.w.id); Launcher.menu = "" } }
    }

    PopupSection { text: "Move to workspace"; visible: pop.siblings.length > 1 }
    Flow {
        visible: pop.siblings.length > 1
        width: parent.width; spacing: 4
        Repeater {
            model: pop.siblings
            PopupButton {
                required property var modelData
                label: modelData.name || String(modelData.idx)
                on: (modelData?.id ?? -1) === (pop.ws?.id ?? -2)
                onClicked: if (!on && pop.w) { pop.act("move-window-to-workspace", "--window-id", String(pop.w.id), "--focus", "false", String(modelData.idx)); Launcher.menu = "" }
            }
        }
    }

    PopupSection { text: "Also on this workspace"; visible: pop.others.length > 0 }
    Column {
        visible: pop.others.length > 0
        width: parent.width; spacing: 1
        Repeater {
            model: pop.others.slice(0, 6)
            PopupRow {
                required property var modelData
                label: modelData.title || modelData.app_id
                sub: Apps.entry(modelData.app_id)?.name ?? modelData.app_id
                onClicked: { Niri.focusWindow(modelData.id); Launcher.menu = "" }
            }
        }
    }
}
