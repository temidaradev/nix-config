import QtQuick
import qs

Rectangle {
    property real pct: 0
    property color accent: pct > 90 ? Theme.red : pct > 75 ? Theme.yellow : Theme.accent
    width: parent.width; height: 6; radius: 3; color: Theme.bg3
    Rectangle { width: parent.width * Math.max(0, Math.min(1, parent.pct / 100)); height: parent.height; radius: 3; color: parent.accent }
}
