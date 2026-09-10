import QtQml 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../lib" as Lib
import "../js/funcs.js" as Funcs
import org.kde.notificationmanager as NotificationManager
import org.kde.kirigami as Kirigami

Lib.CardButton {
    visible: root.showDnd
    Layout.fillWidth: true
    Layout.fillHeight: true
    title: i18n("Do Not Disturb")
        
    // NOTIFICATION MANAGER
    property var notificationSettings: notificationSettings
    NotificationManager.Settings {
        id: notificationSettings
    }
    
    // Enables "Do Not Disturb" on click
    onClicked: {
        Funcs.toggleDnd();
    }
    
    Lib.Icon {
        id: dndIcon
        anchors.fill: parent
        customIcon: true
        source: {
            return (Funcs.checkInhibition() ? Qt.resolvedUrl("../icons/feather/notifications-off.svg") : Qt.resolvedUrl("../icons/feather/notifications-on.svg"));
        }
        selected: Funcs.checkInhibition()
    }
}