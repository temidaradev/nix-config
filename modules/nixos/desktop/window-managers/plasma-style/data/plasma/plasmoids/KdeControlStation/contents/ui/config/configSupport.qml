import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
   
    ColumnLayout {
        anchors.fill: parent
        Label {
            text: i18n("I'd be very thankful if you like to support the development of this applet by donating or by simply spreading the word, TIA! :)")
            
            Layout.fillWidth: true
            Layout.maximumWidth: 500
            wrapMode: Text.WordWrap
        }
        Row {
            spacing: 10
            height: Kirigami.Units.gridUnit * 2.5
            Layout.topMargin: 50
            Image {
                height: parent.height
                source: "../../assets/Paypal.png"
                fillMode: Image.PreserveAspectFit
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Qt.openUrlExternally("https://www.paypal.me/EliverLara/")
                    }
                }
            }
            Image {
                height: parent.height
                source: "../../assets/Ko-Fi.png"
                fillMode: Image.PreserveAspectFit
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Qt.openUrlExternally("https://ko-fi.com/eliverlara")
                    }
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
