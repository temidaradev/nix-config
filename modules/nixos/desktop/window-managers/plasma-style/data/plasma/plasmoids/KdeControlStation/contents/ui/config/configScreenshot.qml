import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.kcmutils as KCM
import org.kde.kirigami 2.3 as Kirigami

KCM.SimpleKCM {

    property alias cfg_hideWidgetOnScreenshot: hideWidgetOnScreenshot.checked
    property alias cfg_screenshotCommand: screenshotCommand.text

    Kirigami.FormLayout {
        CheckBox {
            id: hideWidgetOnScreenshot
            Kirigami.FormData.label: i18n("Hide widget before screenshotting:")
        }

        TextField {
            id: screenshotCommand
            Kirigami.FormData.label: i18n("Screenshot Command (default is 'spectacle'):")
        }
    }
}