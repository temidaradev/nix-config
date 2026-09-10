import QtQuick 2.0
import "../code"
import networknameplugin 1.0

Item {
    id: helperSsid

    property var ssidName: net.currentNetworkName

    NetworkNameProvider {
        id: net
    }
}
