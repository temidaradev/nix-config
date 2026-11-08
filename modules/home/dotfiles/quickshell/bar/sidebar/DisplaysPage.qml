import QtQuick
import QtQuick.Controls
import qs.services

Column {
    width: parent.width; spacing: 8
    SHeading { text: "Displays" }
    SCard {
        visible: !!Workbench.displays.pending?.token
        SLabel { text: "Keep this display configuration?"; font.bold: true }
        SHint { text: "The previous settings return automatically after 18 seconds." }
        Row { spacing: 6
            SAction { text: "Keep changes"; onClicked: Workbench.act({ op: "display-keep" }) }
            SAction { text: "Revert now"; onClicked: Workbench.act({ op: "display-revert" }) }
        }
    }
    Repeater {
        model: Workbench.displays.outputs || []
        SCard {
            id: display
            required property var modelData
            readonly property var modes: modelData.modes || []
            function change(kind, value) { Workbench.act({ op: "display", name: modelData.name, kind, value }) }
            SLabel { text: display.modelData.name + " · " + display.modelData.model; font.bold: true }
            SToggle { text: "Enabled"; checked: display.modelData.logical !== null; onToggled: display.change(checked ? "on" : "off", "") }
            SSelect {
                label: "Resolution & refresh rate"
                options: display.modes.map(m => m.width + " × " + m.height + " · " + (m.refresh_rate / 1000).toFixed(2) + " Hz" + (m.is_preferred ? " · preferred" : ""))
                values: display.modes.map(m => m.width + "x" + m.height + "@" + m.refresh_rate / 1000)
                current: values[display.modelData.current_mode] || ""
                onChosen: value => display.change("mode", value)
            }
            SSelect { label: "Scale"; options: ["100%", "125%", "150%", "175%", "200%", "250%", "300%"]; values: [1, 1.25, 1.5, 1.75, 2, 2.5, 3]; current: display.modelData.logical?.scale || 1; onChosen: value => display.change("scale", value) }
            SSelect { label: "Rotation"; options: ["Normal", "90°", "180°", "270°", "Mirrored"]; values: ["normal", "90", "180", "270", "flipped"]; current: String(display.modelData.logical?.transform || "Normal").toLowerCase(); onChosen: value => display.change("transform", value) }
            SToggle { visible: display.modelData.vrr_supported; text: "Variable refresh rate"; checked: display.modelData.vrr_enabled; onToggled: display.change("vrr", checked ? "on" : "off") }
            Row { width: parent.width; spacing: 6
                SField { id: xpos; width: (parent.width - 12) / 3; placeholderText: "X"; text: String(display.modelData.logical?.x || 0); validator: IntValidator { bottom: -32768; top: 32768 } }
                SField { id: ypos; width: xpos.width; placeholderText: "Y"; text: String(display.modelData.logical?.y || 0); validator: IntValidator { bottom: -32768; top: 32768 } }
                SAction { text: "Position"; width: xpos.width; onClicked: Workbench.act({ op: "display", name: display.modelData.name, kind: "position", value: "", x: Number(xpos.text), y: Number(ypos.text) }) }
            }
        }
    }
    SHeading { text: "Night light" }
    SCard {
        SSelect { label: "Colour temperature"; options: ["Off · 6500 K", "5500 K", "4500 K", "3500 K", "2500 K"]; values: [6500, 5500, 4500, 3500, 2500]; current: Workbench.displays.temperature || 6500; onChosen: value => Workbench.act({ op: "night", value }) }
    }
    SHeading { text: "Saved layouts" }
    SCard {
        SField { id: layout; placeholderText: "Layout name, e.g. Docked" }
        SAction { text: "Save current layout"; onClicked: { Workbench.act({ op: "layout-save", name: layout.text }); layout.clear() } }
        Flow { width: parent.width; spacing: 6
            Repeater { model: Workbench.displays.layouts || []; SAction { required property string modelData; text: modelData; onClicked: Workbench.act({ op: "layout-apply", name: modelData }) } }
        }
        SHint { text: "Layouts and adjustments are local. Nix remains the source of the startup display configuration." }
    }
}
