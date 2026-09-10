import QtQuick
import QtQuick.Layouts

Loader {
    id: loader
    anchors.fill: parent
    asynchronous: true
    //So that representations can also handle this property
    property int pos: 0
    property int curr_page: 0
    property bool hasWindows: false
    property bool needsAttention: false
    property bool active: curr_page == pos
    property real op: calcOp()

    source: {
        switch(cfg.highlightType) {
            case 1: return "../highlights/LineHighlight.qml"
            case 2: return "../highlights/SquareHighlight.qml"
            case 3: return "../highlights/FullHighlight.qml"
            case 4: return "../highlights/FullHighlightWithLine.qml"
            default: return null
        }
    }
    Timer {
        id: blinkTimer
        interval: 700
        repeat: curr_page == pos
        running: needsAttention && cfg.blinkOnAttentionRequired
        onTriggered: op = op == 1 ? 0 : 1
    }
    Binding {
        target: loader.item
        property: "op"
        value: op
        when: loader.status == Loader.Ready
    }
    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            op = hovered ? 0.4 : calcOp()
        }
    }
    Connections{
        target: root
        onCurr_pageChanged: op = hoverHandler.hovered ? 0.4 : calcOp()
    }
    function calcOp() {
        if(curr_page==pos) return 1
        else if(hasWindows && cfg.slightlyHighlight) return (cfg.highlightOpacityFull && !cfg.plasmaSemiColors)?1:0.6
        else return 0
    }
}
