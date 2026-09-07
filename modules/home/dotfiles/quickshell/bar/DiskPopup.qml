import QtQuick
import qs
import qs.services

BarPopup {
    visible: Launcher.diskOpen
    panelWidth: 340
    anchorX: Launcher.diskAnchorX
    onDismissed: Launcher.diskOpen = false

    Text { text: "Storage"; color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize }
    Repeater {
        model: SysStats.disks
        DiskRow { required property var modelData; disk: modelData; width: parent.width }
    }
    Text {
        text: "NVMe " + Math.round(SysStats.nvmeTemp) + " °C"
        visible: SysStats.nvmeTemp > 0
        color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1; topPadding: 4
    }
}
