import QtQuick
import qs.services

Column {
    width: parent.width; spacing: 8
    SHeading { text: "Upcoming · next 30 days" }
    SCard {
        SField { id: calendarPath; placeholderText: "Local calendar file: /path/to/calendar.ics"; text: Workbench.calendar.file || "" }
        SAction { text: "Load calendar"; onClicked: Workbench.act({ op: "calendar-file", path: calendarPath.text }) }
        SHint { text: "Reads local .ics calendars, including recurring events. Keep the file synced with your calendar application." }
    }
    Repeater {
        model: Workbench.calendar.events || []
        SCard {
            required property var modelData
            SLabel { text: modelData.title; font.bold: true }
            SHint { text: modelData.when + (modelData.location ? "\n" + modelData.location : "") }
        }
    }
    SHint { visible: !(Workbench.calendar.events || []).length; text: "No upcoming events loaded. Tasks and reminders are available in the Tasks tab." }
}
