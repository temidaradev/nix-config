import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

Item {

    /*/
    Loader {
        id: helperSsidLoader
        source: "../code/HelperSsid.qml"
    }/*/

    property bool activeConnection: netStatusText.connectivity === 4
    property var appletProxyModel: appletProxyModel
    property string textConnetion: activeConnection ? i18n("Connect") : i18n("Disconnect")
    property var activeConnectionIcon: activeConnectionIcon.connectionIcon
    property var enabledConnections: enabledConnections
    property var availableDevices: availableDevices
    property var handler: handler

    property var netStatusText: PlasmaNM.NetworkStatus {}

    //property string ssidName: helperSsidLoader.item.ssidName

    PlasmaNM.ConnectionIcon {
        id: activeConnectionIcon
        connectivity: netStatus.connectivity
    }
    PlasmaNM.Handler {
        id: handler
    }

    PlasmaNM.NetworkStatus {
        id: netStatus
    }
    PlasmaNM.AppletProxyModel {
        id: appletProxyModel
        sourceModel: PlasmaNM.NetworkModel{}
    }
    PlasmaNM.EnabledConnections {
        id: enabledConnections
    }
    PlasmaNM.AvailableDevices {
        id: availableDevices
    }


}
