import QtQuick
import Quickshell
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "memory"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""

    readonly property real pct: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal * 100 : 0
    readonly property real swapPct: SysStats.swapTotal > 0 ? SysStats.swapUsed / SysStats.swapTotal * 100 : 0

    PopupTitle {
        glyph: "󰍛"; glyphColor: Theme.green
        text: "Memory"; sub: SysStats.fmtBytes(SysStats.memUsed) + " of " + SysStats.fmtBytes(SysStats.memTotal) + " in use"
        Text { text: Math.round(pop.pct) + "%"; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize + 6 }
    }
    Sparkline { anchors.verticalCenter: undefined; width: parent.width; height: 48; values: SysStats.memHist; color: Theme.green }
    PopupMeter { pct: pop.pct; accent: pop.pct > 90 ? Theme.red : Theme.green }
    Column {
        width: parent.width; spacing: 3; topPadding: 2
        PopupKV { k: "Available"; v: SysStats.fmtBytes(SysStats.memAvail) }
        PopupKV { k: "Cache & buffers"; v: SysStats.fmtBytes(SysStats.memCached) }
        PopupKV { visible: SysStats.swapTotal > 0; k: "Swap"; v: SysStats.fmtBytes(SysStats.swapUsed) + " / " + SysStats.fmtBytes(SysStats.swapTotal, 0) + "  (" + Math.round(pop.swapPct) + "%)" }
    }
    PopupSection { text: "Top processes" }
    TopProcs { by: "mem" }
    Row {
        spacing: 6; topPadding: 4
        PopupButton { label: "󰍛  System monitor"; onClicked: { Launcher.menu = ""; Apps.spawn(["ghostty", "--title=btop", "-e", "btop"]) } }
        PopupButton { label: "Details"; onClicked: Launcher.openSidebar("system") }
    }
}
