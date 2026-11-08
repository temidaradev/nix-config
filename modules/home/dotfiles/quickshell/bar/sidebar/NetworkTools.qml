import QtQuick
import QtQuick.Controls
import qs.services
import ".."

Column {
    width: parent.width; spacing: 8
    SHeading { text: "Traffic" }
    SCard {
        SHint { text: "Download " + SysStats.fmtRate(SysStats.rx) + " · Upload " + SysStats.fmtRate(SysStats.tx) }
        Sparkline { width: parent.width; height: 45; anchors.verticalCenter: undefined; values: SysStats.rxHist; max: Math.max(1, ...SysStats.rxHist) }
        Repeater {
            model: Workbench.network.interfaces || []
            SHint { required property var modelData; text: modelData.name + " · ↓ " + SysStats.fmtBytes(modelData.rx) + " · ↑ " + SysStats.fmtBytes(modelData.tx) + " since boot" }
        }
        SAction { text: "Copy connection details"; onClicked: Workbench.copy(JSON.stringify({ connection: Network.primary, dns: Workbench.network.dns, tailscale: Workbench.network.tailIP }, null, 2)) }
        SHint { text: "DNS: " + (Workbench.network.dns || "—") }
    }
    SHeading { text: "Tailscale" }
    SCard {
        visible: Workbench.network.tailscale || false
        SLabel { text: Workbench.network.tailState + (Workbench.network.tailIP ? " · " + Workbench.network.tailIP : "") }
        Row { spacing: 6
            SAction { text: Workbench.network.tailState === "Running" ? "Disconnect" : "Connect"; onClicked: Workbench.act({ op: "vpn", provider: "tailscale", on: Workbench.network.tailState !== "Running" }) }
            SAction { text: "Admin console"; onClicked: Apps.spawn(["xdg-open", "https://login.tailscale.com/admin/machines"]) }
        }
        Repeater {
            model: Workbench.network.peers || []
            Column {
                required property var modelData
                width: parent.width; spacing: 4
                SHint { text: (modelData.online ? "● " : "○ ") + modelData.name + " · " + modelData.ip + " · " + modelData.os }
                SAction { text: "Copy IP"; onClicked: Workbench.copy(modelData.ip) }
            }
        }
    }
    SCard {
        visible: Workbench.network.hasMullvad || false
        SLabel { text: "Mullvad · " + (Workbench.network.mullvad || "Unavailable") }
        Row { spacing: 6
            SAction { text: "Connect"; onClicked: Workbench.act({ op: "vpn", provider: "mullvad", on: true }) }
            SAction { text: "Disconnect"; onClicked: Workbench.act({ op: "vpn", provider: "mullvad", on: false }) }
        }
    }
    SHeading { text: "Connection test" }
    SCard {
        SAction { visible: Network.hasWifi; text: "Rescan Wi-Fi"; onClicked: { Network._rescan = true; Network.scanWifi() } }
        SField { id: host; placeholderText: "Hostname or IP"; text: "1.1.1.1" }
        SAction { text: "Measure latency · 3 pings"; enabled: !Workbench.busy; onClicked: Workbench.act({ op: "ping", host: host.text }) }
    }
    SHeading { visible: Network.hasWifi; text: "Wi-Fi hotspot" }
    SCard {
        visible: Network.hasWifi
        SField { id: ssid; placeholderText: "Hotspot name"; text: "ThinkPad" }
        SField { id: password; placeholderText: "Password · at least 8 characters"; echoMode: TextInput.Password }
        SHint { text: "Starting a hotspot may disconnect this adapter from Wi-Fi. Stop it from the Interfaces section." }
        SAction { text: "Start hotspot"; enabled: password.text.length >= 8 && ssid.text.length > 0; onClicked: { Workbench.act({ op: "hotspot", ssid: ssid.text, password: password.text }); password.clear() } }
    }
}
