import QtQuick
import Quickshell
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "cpu"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""

    PopupTitle {
        glyph: "󰻠"; text: SysInfo.cpu || "CPU"; sub: SysInfo.cpuDetail
        Text { text: Math.round(SysStats.cpu) + "%"; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize + 6 }
    }
    Sparkline { anchors.verticalCenter: undefined; width: parent.width; height: 48; values: SysStats.cpuHist }
    Column {
        width: parent.width; spacing: 3
        PopupKV { visible: SysStats.temp > 0; k: "Temperature"; v: Math.round(SysStats.temp) + " °C" }
        PopupKV { k: "Load average"; v: SysStats.load || "…" }
        PopupKV { k: "Threads"; v: String(SysInfo.threads) }
        PopupKV { k: "Uptime"; v: SysStats.uptime }
    }
    PopupSection { text: "Top processes" }
    TopProcs { by: "cpu" }
    Row {
        spacing: 6; topPadding: 4
        PopupButton { label: "󰍛  System monitor"; onClicked: { Launcher.menu = ""; Apps.spawn(["ghostty", "--title=btop", "-e", "btop"]) } }
        PopupButton { label: "Details"; onClicked: Launcher.openSidebar("system") }
    }
}
