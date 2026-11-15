import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs
import qs.desktop
import qs.services

// Session lock drawn by the shell: blurred wallpaper, clock, password.
WlSessionLock {
    id: lock
    locked: Lock.locked

    WlSessionLockSurface {
        id: surface
        color: Theme.bg0

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
            anchors.fill: parent
            visible: !Wallpaper.isScene && Wallpaper.blurred !== ""
            source: visible ? "file://" + Wallpaper.blurred : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
        Image {
            anchors.fill: parent
            visible: !Wallpaper.isScene && Wallpaper.blurred === ""
            source: visible ? "file://" + Wallpaper.current : ""
            sourceSize: Qt.size(Math.max(1, surface.width / 10), Math.max(1, surface.height / 10))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
        Loader {
            anchors.fill: parent
            active: Theme.steins && Wallpaper.isScene
            sourceComponent: SteinsScene { showMeter: false; showText: false; interactive: false }
        }
        Rectangle { anchors.fill: parent; color: "#40000000" }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Theme.steins ? -110 : -60
            spacing: Theme.steins ? 14 : 6
            Text {
                visible: !Theme.steins
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.fg; font.family: Theme.font; font.pointSize: 72; font.bold: true
                style: Text.Outline; styleColor: "#40000000"
            }
            Loader {   // nixie clock
                active: Theme.steins
                visible: active
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: NixieMeter {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    tubeWidth: Math.round(Math.min(64, surface.width / 22))
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Theme.steins ? Qt.formatDateTime(clock.date, "dddd, d MMMM").toUpperCase() : Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.fontSize + 4
                font.letterSpacing: Theme.steins ? 4 : 0
            }
            Text {
                visible: Theme.steins
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DIVERGENCE  " + Worldline.value + "   ·   " + Worldline.worldName
                color: Theme.accent; font.family: Theme.font; font.pointSize: Theme.fontSize; font.letterSpacing: 2
            }
        }

        Plate {
            id: box
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 110
            width: 340; height: 44
            radius: Theme.r(22)
            color: Theme.panelBg
            stroke: surface.error !== "" ? Theme.red : (input.activeFocus ? Theme.accent : Theme.cardBorder); strokeWidth: 1

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
                    Text { visible: input.text === ""; anchors.verticalCenter: parent.verticalCenter; text: surface.busy ? (Theme.steins ? "Leaping…" : "Checking…") : (Theme.steins ? "Password, Lab Mem" : "Password"); color: Theme.ink(0x66); font.family: Theme.font; font.pointSize: Theme.fontSize }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰁔"; color: surface.password !== "" ? Theme.accent : Theme.ink(0x44); font.family: Theme.font; font.pointSize: 14
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: surface.submit() }
                }
            }
            Component.onCompleted: input.forceActiveFocus()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: box.bottom; anchors.topMargin: 12
            text: surface.error !== "" ? surface.error : (Theme.steins ? "El Psy Kongroo." : Quickshell.env("USER") + "@" + Niri.hostname)
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
