import QtQuick
import Quickshell
import qs
import qs.services

BarPopup {
    id: pop
    visible: Launcher.menu === "battery"
    anchorX: Launcher.menuAnchorX
    panelWidth: 340
    onDismissed: Launcher.menu = ""
    Component.onCompleted: { Power.refresh(); Brightness.refresh() }

    readonly property var bat: Battery.battery ?? Battery.dev
    readonly property color tint: Battery.low ? Theme.red : Battery.charging ? Theme.green : Theme.accent

    PopupTitle {
        glyph: Battery.glyph; glyphColor: pop.tint
        text: Battery.pct + "%"
        sub: (Battery.charging ? "Charging" : Battery.full ? "Fully charged" : Battery.onAc ? "Plugged in, not charging" : "On battery") + (Battery.timeText ? "  ·  " + Battery.timeText : "")
    }
    PopupMeter { pct: Battery.pct; accent: pop.tint }
    Column {
        width: parent.width; spacing: 3; topPadding: 4
        PopupKV { visible: pop.bat && Math.abs(pop.bat.changeRate) > 0.05; k: Battery.charging ? "Charging at" : "Power draw"; v: pop.bat ? Math.abs(pop.bat.changeRate).toFixed(1) + " W" : "" }
        PopupKV { visible: pop.bat && pop.bat.energyCapacity > 0; k: "Energy"; v: pop.bat ? pop.bat.energy.toFixed(1) + " / " + pop.bat.energyCapacity.toFixed(1) + " Wh" : "" }
        PopupKV { visible: pop.bat?.healthSupported ?? false; k: "Health"; v: pop.bat ? Math.round(pop.bat.healthPercentage) + "% of design capacity" : "" }
    }

    PopupSection { text: Power.watt ? "Power policy" : "Power mode" }
    Row {
        visible: !Power.watt
        spacing: 6
        Repeater {
            model: Power.profiles
            PopupButton { required property string modelData; label: modelData.replace("-", " "); on: Power.profile === modelData; onClicked: Power.set(modelData) }
        }
    }
    Text {
        visible: Power.watt
        width: parent.width; wrapMode: Text.Wrap
        text: (Battery.onAc ? "Plugged in: maximum performance" : "On battery: power saving") + ", managed by watt"
        color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
    }

    PopupSection { text: "Brightness"; visible: Brightness.present }
    PopupSlider {
        id: bri
        visible: Brightness.present
        glyph: "󰃠"; target: Brightness.level
        onMoved: Brightness.set(value)
    }

    PopupToggle {
        label: "Stay awake"
        sub: Idle.inhibit ? "Dimming, locking and sleep are paused" : "Dim " + Idle.fmt(Idle.cur.dim) + "  ·  lock " + Idle.fmt(Idle.cur.lock) + "  ·  sleep " + Idle.fmt(Idle.cur.suspend)
        on: Idle.inhibit; onToggled: v => Idle.inhibit = v
    }

    Row {
        spacing: 6; topPadding: 4
        PopupButton { label: "󰁹  Power settings"; onClicked: Launcher.openSidebar("power") }
    }
}
