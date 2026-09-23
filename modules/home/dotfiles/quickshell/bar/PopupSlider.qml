import QtQuick
import QtQuick.Controls
import qs

Slider {
    id: s
    property string glyph
    property bool muted: false
    property real target: 0
    signal toggleMute
    width: parent.width; height: 26
    from: 0; to: 1
    leftPadding: 30; rightPadding: 44
    onTargetChanged: if (!pressed) value = target
    Component.onCompleted: value = target
    Text {
        x: 2; anchors.verticalCenter: parent.verticalCenter
        text: s.glyph; color: s.muted ? Theme.fgDim : Theme.fg
        font.family: Theme.font; font.pointSize: 13
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: s.toggleMute() }
    }
    Text {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: Math.round(s.value * 100) + "%"; color: Theme.fgDim
        font.family: Theme.font; font.pointSize: Theme.smallSize
    }
    background: Rectangle {
        x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - 2
        width: s.availableWidth; height: 4; radius: 2; color: Theme.bg3
        Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: s.muted ? Theme.fgDim : Theme.accent }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 14; height: 14; radius: 7; color: Theme.fg
    }
}
