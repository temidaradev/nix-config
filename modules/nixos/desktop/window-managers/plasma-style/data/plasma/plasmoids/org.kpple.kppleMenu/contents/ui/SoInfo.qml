import QtQuick
import QtQuick.Controls
import QtQuick.Layouts 1.1
import org.kde.kcmutils // KCMLauncher
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmaCore.Dialog {
    id: dialog
    visible: true
    width: 280
    height: 400
    //parent: root
    //visible: false
    location: PlasmaCore.Types.Floating

    property var screen: root.screenGeometry;
    hideOnWindowDeactivate: true

    x: (screen.width - width)/2
    y: (screen.height - height)/2

    MainModel {
        id: mainModel
    }

    FocusScope {
        id: rootItem
        Layout.minimumWidth:  280
        Layout.maximumWidth:  280
        Layout.minimumHeight: 450
        Layout.maximumHeight: 450
        focus: true

        Kirigami.Icon{
            id: logo
            source: "computer"
            width: parent.width/2
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin:  Kirigami.Units.gridUnit
        }
        Text {
            id: hei
            text: "prueba"
            font.pixelSize: Kirigami.Theme.defaultFontSize
            visible: false
        }
        ListView {
            id: list
            model: mainModel.infoModel
            width: 250
            height: (hei.implicitHeight + Kirigami.Units.gridUnit/3) * (mainModel.infoModel.count + 1 )
            anchors.top: logo.bottom
            anchors.topMargin: Kirigami.Units.gridUnit
            delegate: Item {
                id: item
                width: parent.width
                height: valueModel.implicitHeight + Kirigami.Units.gridUnit/3
                Row {
                    id: texts
                    anchors.fill: parent
                    Text {
                        width: parent.width/2
                        text: model.name + ": "
                        color: Kirigami.Theme.textColor
                        font.pixelSize: Kirigami.Theme.defaultFontSize
                        horizontalAlignment: Text.AlignRight
                    }
                    Text {
                        id: valueModel
                        width: parent.width/2
                        text: model.value
                        font.pixelSize: Kirigami.Theme.defaultFontSize
                        color: Kirigami.Theme.textColor
                        wrapMode: Text.Wrap // Permite el salto de línea automático
                        elide: Text.ElideNone
                    }
                }

            }
        }

        Button {
            anchors.top: list.bottom
            anchors.topMargin: Kirigami.Units.gridUnit*1.5
            anchors.horizontalCenter: parent.horizontalCenter
            text: i18n("More info...")
            onClicked:  KCMLauncher.openSystemSettings("kcm_about-distro")
        }


    }

}
