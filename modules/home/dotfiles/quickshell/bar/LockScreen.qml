import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs
import qs.services

// Session lock drawn by the shell: blurred wallpaper, clock, password.
WlSessionLock {
    id: lock
    locked: Lock.locked

    WlSessionLockSurface {
        id: surface
        color: "#1b1e20"

        property string password: ""
        property string error: ""
        property bool busy: false

        SystemClock { id: clock; precision: SystemClock.Minutes }

        PamContext {
            id: pam
            config: "login"
            user: Quickshell.env("USER")
            onPamMessage: { if (responseRequired) respond(surface.password) }
            onCompleted: result => {
                surface.busy = false
                if (result === PamResult.Success) { surface.password = ""; surface.error = ""; Lock.locked = false }
                else { surface.error = "Wrong password"; surface.password = ""; shake.restart() }
            }
        }
        function submit() {
            if (busy || password === "") return
            busy = true; error = ""
            pam.start()
        }

        Image {
            id: wall
            anchors.fill: parent
            source: "file://" + Wallpaper.current
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            blurEnabled: true; blur: 0.9; blurMax: 64
            brightness: -0.3; saturation: -0.1
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -60
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.fg; font.family: Theme.font; font.pointSize: 72; font.bold: true
                style: Text.Outline; styleColor: "#40000000"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.fontSize + 4
            }
        }

        Rectangle {
            id: box
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 110
            width: 340; height: 44
            radius: 22
            color: Theme.panelBg
            border.color: surface.error !== "" ? Theme.red : (input.activeFocus ? Theme.accent : Theme.cardBorder); border.width: 1

            SequentialAnimation {
                id: shake
                NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -10; duration: 40 }
                NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 10; duration: 60 }
                NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -6; duration: 50 }
                NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
            }

            Row {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: "󰌾"; color: Theme.fgDim; font.family: Theme.font; font.pointSize: 13 }
                TextInput {
                    id: input
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.fontSize + 1
                    focus: true
                    enabled: !surface.busy
                    text: surface.password
                    onTextChanged: surface.password = text
                    onAccepted: surface.submit()
                    Text { visible: input.text === ""; anchors.verticalCenter: parent.verticalCenter; text: surface.busy ? "Checking…" : "Password"; color: "#66ffffff"; font.family: Theme.font; font.pointSize: Theme.fontSize }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰁔"; color: surface.password !== "" ? Theme.accent : "#44ffffff"; font.family: Theme.font; font.pointSize: 14
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: surface.submit() }
                }
            }
            Component.onCompleted: input.forceActiveFocus()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: box.bottom; anchors.topMargin: 12
            text: surface.error !== "" ? surface.error : Quickshell.env("USER") + "@" + Niri.hostname
            color: surface.error !== "" ? Theme.red : Theme.fgDim
            font.family: Theme.font; font.pointSize: Theme.smallSize
        }

        Row {   // bottom-right: battery + now playing, when relevant
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 24
            spacing: 18
            Text { visible: Media.player !== null && Media.playing; text: "󰝚  " + Media.title; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize }
            Text { visible: Battery.present; text: Battery.glyph + "  " + Battery.pct + "%"; color: Battery.low ? Theme.red : Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize }
        }
    }
}
