import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components 1.0 as KirigamiComponents
import org.kde.kcmutils as KCM
import org.kde.coreaddons 1.0 as KCoreAddons
import "../lib" as Lib

Lib.CardButton {
    id: useraAvatar

    Layout.fillWidth: true
    Layout.preferredHeight: root.sectionHeight/3.3

    visible: root.showAvatar

    property bool singleLineWidget: false

    KCoreAddons.KUser {
      id: kuser
    }

    heading: kuser.fullName
    title: i18n("%1@%2", kuser.loginName, kuser.host)

    KirigamiComponents.AvatarButton {
        source: kuser.faceIconUrl
        anchors {
            fill: parent
        }
    }

    onClicked: {
        KCM.KCMLauncher.openSystemSettings("kcm_users")
        root.toggle()
    }
}



