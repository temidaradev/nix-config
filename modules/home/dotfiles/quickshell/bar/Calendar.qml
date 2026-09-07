import QtQuick
import qs
import qs.services

BarPopup {
    id: cal
    visible: Launcher.calendarOpen
    panelWidth: 300
    onDismissed: Launcher.calendarOpen = false

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    onVisibleChanged: if (visible) { today = new Date(); year = today.getFullYear(); month = today.getMonth() }

    function shift(d) { const m = new Date(year, month + d, 1); year = m.getFullYear(); month = m.getMonth() }
    readonly property var cells: {
        const first = new Date(year, month, 1)
        const start = (first.getDay() + 6) % 7            // Monday first
        const days = new Date(year, month + 1, 0).getDate()
        const prevDays = new Date(year, month, 0).getDate()
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = i - start + 1
            if (d < 1) out.push({ d: prevDays + d, cur: false })
            else if (d > days) out.push({ d: d - days, cur: false })
            else out.push({ d, cur: true })
        }
        return out
    }

    Item {   // header
        width: parent.width; height: 28
        BarButton { anchors.left: parent.left; implicitHeight: 28; padding: 8; onClicked: cal.shift(-1)
            BarText { text: "󰅁" } }
        Text {
            anchors.centerIn: parent
            text: Qt.formatDate(new Date(cal.year, cal.month, 1), "MMMM yyyy")
            color: Theme.fg; font.bold: true; font.family: Theme.font; font.pointSize: Theme.fontSize
            MouseArea { anchors.fill: parent; onClicked: { cal.today = new Date(); cal.year = cal.today.getFullYear(); cal.month = cal.today.getMonth() } }
        }
        BarButton { anchors.right: parent.right; implicitHeight: 28; padding: 8; onClicked: cal.shift(1)
            BarText { text: "󰅂" } }
    }

    Grid {
        columns: 7; width: parent.width
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text {
                required property string modelData
                width: parent.width / 7; height: 22
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: modelData; color: Theme.fgDim
                font.family: Theme.font; font.pointSize: Theme.smallSize - 1
            }
        }
    }

    Grid {
        columns: 7; width: parent.width
        Repeater {
            model: cal.cells
            Rectangle {
                required property var modelData
                readonly property bool isToday: modelData.cur && cal.year === cal.today.getFullYear() && cal.month === cal.today.getMonth() && modelData.d === cal.today.getDate()
                width: parent.width / 7; height: 30
                radius: Theme.radius
                color: isToday ? Theme.accent : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: modelData.d
                    color: isToday ? "#1b1e20" : (modelData.cur ? Theme.fg : "#55ffffff")
                    font.bold: isToday
                    font.family: Theme.font; font.pointSize: Theme.smallSize
                }
            }
        }
    }

    Text {
        width: parent.width; horizontalAlignment: Text.AlignHCenter
        text: Qt.formatDate(cal.today, "dddd, d MMMM yyyy")
        color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1
        topPadding: 4
    }
}
