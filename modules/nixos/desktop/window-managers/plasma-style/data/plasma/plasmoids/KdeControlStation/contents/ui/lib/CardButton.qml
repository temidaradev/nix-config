import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents

Card {
    id: cardButton
    default property alias content: icon.data
    property alias title: title.text
    property alias heading: heading.text
    property bool isLongButton: false // Used in ControlCenter layout
    property bool shouldStickIconSize: false // This property avoids disproportional icon size when not using Lib.Icon
    property bool fullSizeIcon: grid.small && !showTitle && !shouldStickIconSize // Used in 'Tahoe' and 'Custom Layout' 
    property bool showTitle: true
    
    GridLayout {
        id: grid
        anchors.fill: parent
        property bool small: width < root.fullRepWidth/3
        anchors.margins: fullSizeIcon ? 0 : small ? root.smallSpacing : isLongButton ? root.mediumSpacing : root.largeSpacing
        rows: small ? 2 : 2
        columns: small ? 1 : 2
        columnSpacing: small ? 0 : 10*root.scale
        rowSpacing: 0

        Item {
            id: icon
            Layout.preferredHeight: (parent.small && plasmoid.configuration.layout == 1) ? parent.height/1.8 
                                    : fullSizeIcon ? parent.height - root.largeSpacing
                                    : parent.small ? parent.height/1.5 
                                    : isLongButton ? parent.height 
                                    : parent.height - root.largeSpacing
            Layout.preferredWidth: Layout.preferredHeight
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Layout.rowSpan: 2
        }
        PlasmaComponents.Label {
            id: heading
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            font.pixelSize: root.mediumFontSize
            font.weight: Font.Bold
            elide: Text.ElideRight
            visible: !parent.small && text
            Layout.rowSpan: (isLongButton && !showTitle) ? 2 : 1
            horizontalAlignment: Qt.AlignLeft
            verticalAlignment: showTitle ? Qt.AlignBottom : Qt.AlignVCenter
        }
        PlasmaComponents.Label {
            id: title
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.margins:  (parent.small || !heading.visible) ? root.smallSpacing : 1
            Layout.rowSpan: heading.visible ? 1 : 2
            font.pixelSize: (parent.small || heading.visible) ? root.smallFontSize+0.5 : root.mediumFontSize
            font.weight: (parent.small || !heading.visible) ? Font.Bold : Font.Normal
            horizontalAlignment: parent.small ? Qt.AlignHCenter : Qt.AlignLeft
            verticalAlignment: !heading.visible ? Qt.AlignVCenter : Qt.AlignTop
            wrapMode: Text.WordWrap
            elide: (plasmoid.configuration.layout == 1 && !isLongButton) ? Text.ElideNone : Text.ElideRight
            visible: text && showTitle
        }
    }
}
