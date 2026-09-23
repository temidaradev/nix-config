import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "volume"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => !n.isStream && n.isSink)
    readonly property var sources: nodes.filter(n => !n.isStream && !n.isSink)
    readonly property var streams: nodes.filter(n => n.isStream && n.isSink)
    PwObjectTracker { objects: pop.nodes }
    function name(n) { return n ? (n.nickname || n.description || n.name) : "none" }
    function appName(n) { const p = n.properties || {}; return (p["application.name"] || p["node.name"] || n.name) + (p["media.name"] ? "  ·  " + p["media.name"] : "") }
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    PopupTitle {
        glyph: pop.muted ? "󰖁" : pop.volume < 0.01 ? "󰕿" : pop.volume < 0.5 ? "󰖀" : "󰕾"
        text: "Sound"; sub: pop.name(pop.sink)
        PopupButton { label: pop.muted ? "Unmute" : "Mute"; on: pop.muted; onClicked: if (pop.sink?.audio) pop.sink.audio.muted = !pop.muted }
    }
    PopupSlider {
        glyph: pop.muted ? "󰖁" : "󰕾"; muted: pop.muted; target: pop.volume
        onMoved: if (pop.sink?.audio) pop.sink.audio.volume = value
        onToggleMute: if (pop.sink?.audio) pop.sink.audio.muted = !pop.muted
    }
    PopupSlider {
        readonly property bool m: pop.source?.audio?.muted ?? false
        glyph: m ? "󰍭" : "󰍬"; muted: m; target: pop.source?.audio?.volume ?? 0
        onMoved: if (pop.source?.audio) pop.source.audio.volume = value
        onToggleMute: if (pop.source?.audio) pop.source.audio.muted = !m
    }

    PopupSection { text: "Output" }
    Column {
        width: parent.width; spacing: 1
        Repeater {
            model: pop.sinks
            PopupRow { required property var modelData; glyph: modelData === pop.sink ? "󰄬" : "󰓃"; label: pop.name(modelData); active: modelData === pop.sink; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
        }
    }
    PopupSection { text: "Input"; visible: pop.sources.length > 1 }
    Column {
        visible: pop.sources.length > 1
        width: parent.width; spacing: 1
        Repeater {
            model: pop.sources
            PopupRow { required property var modelData; glyph: modelData === pop.source ? "󰄬" : "󰍬"; label: pop.name(modelData); active: modelData === pop.source; onClicked: Pipewire.preferredDefaultAudioSource = modelData }
        }
    }

    PopupSection { text: "Applications"; visible: pop.streams.length > 0 }
    Repeater {
        model: pop.streams
        Column {
            required property var modelData
            width: parent.width; spacing: 0
            Text { width: parent.width; elide: Text.ElideRight; text: pop.appName(modelData); color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
            PopupSlider {
                readonly property bool m: modelData.audio?.muted ?? false
                glyph: m ? "󰖁" : "󰕾"; muted: m; target: modelData.audio?.volume ?? 0
                onMoved: if (modelData.audio) modelData.audio.volume = value
                onToggleMute: if (modelData.audio) modelData.audio.muted = !m
            }
        }
    }

    Row {
        spacing: 6; topPadding: 4
        PopupButton { label: "󰕾  Audio settings"; onClicked: Launcher.openSidebar("audio") }
        PopupButton { label: "Mixer"; onClicked: { Launcher.menu = ""; Apps.spawn(["pavucontrol"]) } }
    }
}
