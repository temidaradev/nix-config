import QtQuick
import qs.services
import ".."

Column {
    width: parent.width; spacing: 8
    SHeading { text: "Battery health & charging"; visible: Battery.present }
    Repeater {
        model: Workbench.power.batteries || []
        SCard {
            required property var modelData
            SLabel { text: modelData.name + " · " + modelData.status; font.bold: true }
            SHint { text: modelData.watts + " W · " + (modelData.health ? modelData.health + "% health" : "Health unavailable") + " · " + modelData.cycles + " cycles" }
            SHint { visible: modelData.end !== ""; text: "Actual charge thresholds: " + modelData.start + "–" + modelData.end + "%" }
            Flow { visible: Workbench.power.chargeControl || false; width: parent.width; spacing: 6
                SAction { text: "Charge to 100%"; onClicked: Workbench.act({ op: "charge", mode: "full" }) }
                SAction { text: "Limit to 80%"; onClicked: Workbench.act({ op: "charge", mode: "limit" }) }
            }
        }
    }
    SCard {
        visible: Battery.present
        SHint { text: "Power draw while this page is open · watts" }
        Sparkline { width: parent.width; height: 60; anchors.verticalCenter: undefined; values: Workbench.wattHistory; max: Math.max(5, ...Workbench.wattHistory) }
    }
    SHeading { text: "Current power policy" }
    SCard {
        SHint { text: "Governor: " + (Workbench.power.governor || "—") + "\nEnergy preference: " + (Workbench.power.epp || "—") + "\nPlatform: " + (Workbench.power.profile || "—") }
        SSelect { label: "Keep awake temporarily"; options: ["Disabled", "15 minutes", "30 minutes", "1 hour", "2 hours"]; values: [0, 15, 30, 60, 120]; current: Workbench.awakeMinutes; onChosen: value => Workbench.awake(value) }
        SHint { visible: Workbench.awakeUntil > 0; text: "Ends in " + Media.fmtTime(Math.max(0, (Workbench.awakeUntil - Workbench.now) / 1000)) }
    }
}
