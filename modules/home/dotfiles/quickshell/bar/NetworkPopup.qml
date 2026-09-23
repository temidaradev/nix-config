import QtQuick
import Quickshell
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "network"
    anchorX: Launcher.menuAnchorX
    panelWidth: 360
    onDismissed: Launcher.menu = ""

    readonly property var p: Network.primary
    readonly property real peak: Math.max(4096, ...SysStats.rxHist, ...SysStats.txHist)
    readonly property bool wifiOn: Network.wifi.length > 0 || Network.current !== null
    function glyphFor(type) { return type === "wifi" ? "󰤨" : type === "ethernet" ? "󰈀" : type === "wireguard" || type === "tun" ? "󰖂" : "󰛳" }

    PopupTitle {
        glyph: pop.p ? pop.glyphFor(pop.p.type) : "󰤮"
        glyphColor: pop.p ? Theme.accent : Theme.fgDim
        text: pop.p ? pop.p.connection : "Disconnected"
        sub: pop.p ? [pop.p.type, pop.p.name, pop.p.ip4].filter(s => s).join("  ·  ") + (Network.current ? "  ·  " + Network.current.signal + "%" : "") : ""
    }
    Row {
        width: parent.width; spacing: 12
        Repeater {
            model: [{ g: "󰁅", label: "Download", v: SysStats.rx, h: SysStats.rxHist, c: Theme.accent }, { g: "󰁝", label: "Upload", v: SysStats.tx, h: SysStats.txHist, c: Theme.green }]
            Column {
                required property var modelData
                width: (parent.width - 12) / 2; spacing: 2
                Text { text: modelData.g + "  " + modelData.label; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 2 }
                Text { text: SysStats.fmtRate(modelData.v); color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize }
                Sparkline { anchors.verticalCenter: undefined; width: parent.width; height: 28; values: modelData.h; max: pop.peak; color: modelData.c }
            }
        }
    }
    PopupKV { visible: Network.vpn !== null; k: "VPN"; v: Network.vpn ? Network.vpn.connection + (Network.vpn.ip4 ? "  " + Network.vpn.ip4 : "") : "" }

    PopupSection { text: "Wi-Fi"; visible: Network.hasWifi }
    PopupToggle { visible: Network.hasWifi; label: "Wi-Fi"; on: pop.wifiOn; onToggled: v => Network.toggleWifi(v) }
    Column {
        visible: Network.hasWifi
        width: parent.width; spacing: 1
        Repeater {
            model: Network.wifi.slice(0, 7)
            PopupRow {
                required property var modelData
                glyph: modelData.signal > 66 ? "󰤨" : modelData.signal > 33 ? "󰤥" : "󰤟"
                label: modelData.ssid
                detail: (modelData.secure ? "󰌾 " : "") + modelData.band
                active: modelData.inUse
                action: modelData.inUse ? "Disconnect" : ""
                onActionClicked: Network.disconnect(pop.p ? pop.p.connection : modelData.ssid)
                onClicked: if (!modelData.inUse) Network.connect(modelData.ssid)
            }
        }
    }
    Row {
        spacing: 6; topPadding: 4
        PopupButton { label: "󰛳  Network settings"; onClicked: Launcher.openSidebar("network") }
        PopupButton { label: "Connections"; onClicked: { Launcher.menu = ""; Apps.spawn(["nm-connection-editor"]) } }
    }
}
