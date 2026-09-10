import QtQuick
import org.kde.coreaddons 1.0 as KCoreAddons

Item {

    property string codeleng: ((Qt.locale().name)[0]+(Qt.locale().name)[1])

    KCoreAddons.KUser {
        id: kuser
    }

    function capitalizeFirstLetter(string) {
        if (!string || string.length === 0) {
            return "";
        }
        return string.charAt(0).toUpperCase() + string.slice(1);
    }


    property string name: i18n("Hi") + " " + capitalizeFirstLetter(kuser.fullName)
    property url urlAvatar: kuser.faceIconUrl

}
