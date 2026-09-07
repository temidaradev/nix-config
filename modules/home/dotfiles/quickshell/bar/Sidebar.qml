import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Right-edge system panel: gauges, temps, storage, peripherals, network.
PanelWindow {
    id: win
    visible: Launcher.sidebarOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-sidebar"


    MouseArea { anchors.fill: parent; onClicked: Launcher.sidebarOpen = false }

    Rectangle {
        id: panel
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.topMargin: Theme.barHeight
        width: 380
        color: Theme.panelBg
        border.color: Theme.cardBorder; border.width: 1
        MouseArea { anchors.fill: parent }

        Flickable {
            anchors.fill: parent; anchors.margins: 14
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: 10

                component Section: Text {
                    color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
                    font.capitalization: Font.AllUppercase; topPadding: 8
                }
                component Card: Rectangle {
                    width: parent.width
                    radius: Theme.radius; color: Theme.bg2
                    default property alias content: inner.data
                    implicitHeight: inner.implicitHeight + 20
                    Column { id: inner; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; spacing: 6 }
                }
                component KV: Row {
                    property string k; property string v
                    width: parent.width
                    Text { width: parent.width / 2; text: k; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize }
                    Text { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: v; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize }
                }

                Row {
                    width: parent.width
                    Text { text: Quickshell.env("USER") + "@" + Niri.hostname; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize; width: parent.width - 140 }
                    Text { text: "up " + SysStats.uptime; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; width: 140; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
                }

                Section { text: "System" }
                Card {
                    Row {
                        width: parent.width
                        Gauge { width: parent.width / 3; value: SysStats.cpu; label: "CPU"; center: SysStats.cpu.toFixed(0) + "%" }
                        Gauge { width: parent.width / 3; value: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal * 100 : 0; label: "Memory" }
                        Gauge { width: parent.width / 3; value: SysStats.gpu; label: "GPU"; center: SysStats.gpu > 0 ? SysStats.gpu.toFixed(0) + "%" : "–" }
                    }
                    KV { k: "CPU temperature"; v: Math.round(SysStats.temp) + " °C" }
                    KV { k: "GPU temperature"; v: SysStats.gpuTemp > 0 ? Math.round(SysStats.gpuTemp) + " °C" : "n/a" }
                    KV { k: "Memory"; v: SysStats.fmtBytes(SysStats.memUsed) + " / " + SysStats.fmtBytes(SysStats.memTotal) }
                    KV { k: "Swap"; v: SysStats.fmtBytes(SysStats.swapUsed, 0) + " / " + SysStats.fmtBytes(SysStats.swapTotal, 0) }
                    KV { k: "Cores"; v: String(SysStats.cores) }
                }

                Section { text: "History (60 s)" }
                Card {
                    Row { width: parent.width; spacing: 8
                        Text { text: "CPU"; width: 40; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
                        Sparkline { width: parent.width - 48; height: 36; data: SysStats.cpuHist } }
                    Row { width: parent.width; spacing: 8
                        Text { text: "MEM"; width: 40; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
                        Sparkline { width: parent.width - 48; height: 36; data: SysStats.memHist; color: Theme.green } }
                    KV { k: "Network"; v: "󰁅 " + SysStats.fmtRate(SysStats.rx) + "   󰁝 " + SysStats.fmtRate(SysStats.tx) }
                }

                Section { text: "Storage" }
                Card {
                    Repeater {
                        model: SysStats.disks
                        DiskRow { required property var modelData; disk: modelData; width: parent.width }
                    }
                    KV { visible: SysStats.nvmeTemp > 0; k: "NVMe temperature"; v: Math.round(SysStats.nvmeTemp) + " °C" }
                }

                Section { text: "Peripherals"; visible: Devices.all.length > 0 }
                Card {
                    visible: Devices.all.length > 0
                    Repeater {
                        model: Devices.all
                        Row {
                            required property var modelData
                            width: parent.width; spacing: 8
                            Text { text: modelData.glyph; width: 20; color: Theme.fg; font.family: Theme.font; font.pointSize: 12 }
                            Text { text: modelData.name; width: parent.width - 28 - 120; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: 80; height: 6; radius: 3; color: Theme.bg3; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: parent.width * modelData.pct / 100; height: parent.height; radius: 3; color: modelData.pct < 20 ? Theme.red : Theme.green }
                            }
                            Text { text: modelData.pct + "%" + (modelData.charging ? " 󱐋" : ""); width: 40; horizontalAlignment: Text.AlignRight; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                Section { text: "Now playing"; visible: Media.player !== null }
                Card {
                    visible: Media.player !== null
                    Row {
                        width: parent.width; spacing: 10
                        Rectangle {
                            width: 56; height: 56; radius: 4; color: Theme.bg3; clip: true
                            Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true; sourceSize: Qt.size(112, 112) }
                        }
                        Column {
                            width: parent.width - 66; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { width: parent.width; elide: Text.ElideRight; text: Media.title; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize }
                            Text { width: parent.width; elide: Text.ElideRight; text: Media.artist; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize }
                            Row {
                                spacing: 14; topPadding: 4
                                BarButton { padding: 4; implicitHeight: 24; onClicked: Media.player?.previous()
                                    BarText { text: "󰒮"; font.pointSize: 12 } }
                                BarButton { padding: 4; implicitHeight: 24; onClicked: Media.player?.togglePlaying()
                                    BarText { text: Media.playing ? "󰏤" : "󰐊"; font.pointSize: 12 } }
                                BarButton { padding: 4; implicitHeight: 24; onClicked: Media.player?.next()
                                    BarText { text: "󰒭"; font.pointSize: 12 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
