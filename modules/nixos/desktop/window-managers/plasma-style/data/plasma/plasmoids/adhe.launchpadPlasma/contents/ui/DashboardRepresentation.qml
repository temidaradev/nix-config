/*
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import Qt5Compat.GraphicalEffects
// Deliberately imported after QtQuick to avoid missing restoreMode property in Binding. Fix in Qt 6.
import QtQml 2.15

import org.kde.kquickcontrolsaddons 2.0
import org.kde.kwindowsystem 1.0
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.private.shell 2.0
import org.kde.kirigami 2.20 as Kirigami
import QtQuick.Layouts 1.1

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.private.kicker 0.1 as Kicker

import QtQuick.Controls
import QtQuick
import Qt5Compat.GraphicalEffects


import "code/tools.js" as Tools


Kicker.DashboardWindow {
    id: root

    property bool smallScreen: ((Math.floor(width / Kirigami.Units.iconSizes.huge) <= 22) || (Math.floor(height / Kirigami.Units.iconSizes.huge) <= 14))

    property int iconSize:{ switch(Plasmoid.configuration.appsIconSize){
        case 0: return Kirigami.Units.iconSizes.smallMedium;
        case 1: return Kirigami.Units.iconSizes.medium;
        case 2: return Kirigami.Units.iconSizes.large;
        case 3: return Kirigami.Units.iconSizes.huge;
        case 4: return Kirigami.Units.iconSizes.large *  2;
        case 5: return Kirigami.Units.iconSizes.enormous;
        default: return 64
        }
    }

    property int favsIconSize:{ switch(Plasmoid.configuration.favsIconSize){
        case 0: return Kirigami.Units.iconSizes.smallMedium;
        case 1: return Kirigami.Units.iconSizes.medium;
        case 2: return Kirigami.Units.iconSizes.large;
        case 3: return Kirigami.Units.iconSizes.huge;
        case 4: return Kirigami.Units.iconSizes.enormous;
        default: return 64
        }
    }

    property int systemIconSize:{ switch(Plasmoid.configuration.systemIconSize){
        case 0: return Kirigami.Units.iconSizes.smallMedium;
        case 1: return Kirigami.Units.iconSizes.medium;
        case 2: return Kirigami.Units.iconSizes.large;
        case 3: return Kirigami.Units.iconSizes.huge;
        case 4: return Kirigami.Units.iconSizes.enormous;
        default: return 64
        }
    }

    property int cellSize: iconSize + (2 * Kirigami.Units.iconSizes.sizeForLabels)
                           + (2 * Kirigami.Units.largeSpacing)
                           + (2 * Math.max(highlightItemSvg.margins.top + highlightItemSvg.margins.bottom,
                                           highlightItemSvg.margins.left + highlightItemSvg.margins.right))
    //property int columns: Math.floor(width*0.7/root.cellSize)//  Math.floor(((smallScreen ? 85 : 80)/100) * Math.ceil(width / cellSize))
    property int columns: Math.floor(((smallScreen ? 85 : 80)/100) * Math.ceil(width / cellSize))
    property bool searching: searchField.text !== ""

    property int favoritesRows:  Math.floor(height*0.4/cellSize)

    //keyEventProxy: searchField
    backgroundColor:  "transparent"


    onKeyEscapePressed: {
        if (searching) {
            searchField.clear();
        } else {
            root.toggle();
        }
    }

    onVisibleChanged: {
        if(visible){
            animatorMainColumn.start()
        }else{
            rootItem.opacity = 0
        }
        reset();
    }

    onSearchingChanged: {
        if (!searching) {
            //mainView.currentIndex = 1
            mainView.pop()
            reset();
        } else {
            mainView.push(runnerComponent)
            //mainView.currentIndex = 0
        }
    }

    function colorWithAlpha(color: color, alpha: real): color {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }



    function reset() {
        allAppsGrid.model = rootModel.modelForRow(2)
        globalFavoritesGrid.model = globalFavorites

        allAppsGrid.currentIndex = -1
        globalFavoritesGrid.currentIndex = -1;
        systemFavoritesGrid.currentIndex = -1;

        allAppsGrid.forceLayout()

        searchField.clear();
        searchField.focus = true

    }

    mainItem: MouseArea {
        id: rootItem

        anchors.fill: parent

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        Rectangle{
            anchors.fill: parent
            color: Kirigami.Theme.backgroundColor
            opacity: 0.4
        }


        Connections {
            target: kicker

            function onReset() {
                if (!root.searching) {
                    //filterList.applyFilter();
                    //funnelModel.reset();
                }
            }

            function onDragSourceChanged() {
                if (!kicker.dragSource) {
                    // FIXME TODO HACK: Reset all views post-DND to work around
                    // mouse grab bug despite QQuickWindow::mouseGrabberItem==0x0.
                    // Needs a more involved hunt through Qt Quick sources later since
                    // it's not happening with near-identical code in the menu repr.
                    rootModel.refresh();
                }
            }
        }

        Connections {
            target: Plasmoid
            function onUserConfiguringChanged() {
                if (Plasmoid.userConfiguring) {
                    root.hide()
                }
            }
        }

        PlasmaExtras.Menu {
            id: contextMenu

            PlasmaExtras.MenuItem {
                action: Plasmoid.internalAction("configure")
            }
        }

        Kirigami.Heading {
            id: dummyHeading

            visible: false

            width: 0

            level: 1
        }

        TextMetrics {
            id: headingMetrics

            font: dummyHeading.font
        }

        Kicker.FunnelModel {
            id: funnelModel

            onSourceModelChanged: {
                if (mainColumn.visible) {
                    mainGrid.currentIndex = -1;
                    mainGrid.forceLayout();
                }
            }
        }

        Kicker.ContainmentInterface {
            id: containmentInterface
        }

        TextField{
            id: searchField
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: mainView.top
            anchors.bottomMargin: Kirigami.Units.largeSpacing * 6
            //focus: true
            width: Kirigami.Units.gridUnit * 13
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing
            placeholderText: i18nc("@info:placeholder as in, 'start typing to initiate a search'", "Search")
            horizontalAlignment: TextInput.AlignHCenter
            wrapMode: Text.NoWrap
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 0.5

            onTextChanged: {
                runnerModel.query = searchField.text;
            }

            function clear() {
                text = "";
            }

            background: Rectangle {
                color: colorWithAlpha(Kirigami.Theme.backgroundColor,0.7)
                radius: 100
                border.width: 1
                border.color: colorWithAlpha(Kirigami.Theme.textColor,0.05)
            }

            function appendText(newText) {
                if (!root.visible) {
                    return;
                }
                focus = true;
                text = text + newText;
            }

            function backspace() {
                if (!root.visible) {
                    return;
                }
                focus = true;
                text = text.slice(0, -1);
            }

            function updateSelection() {
                if (!searchField.selectedText) {
                    return;
                }

                var delta = text.lastIndexOf(searchField.text, text.length - 2);
                searchHeading.select(searchField.selectionStart + delta, searchField.selectionEnd + delta);
            }
            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    event.accepted = true;
                                    if(root.searching){
                                        mainView.currentItem.tryActivate(0,0)
                                        mainView.currentItem.forceActiveFocus()
                                    }
                                    else{
                                        allAppsGrid.tryActivate(0,0)
                                        allAppsGrid.forceActiveFocus()
                                    }
                                }
                            }
        }


        OpacityAnimator{ id: animatorMainColumn ;from: 0; to: 1 ; target: rootItem;}

        StackView {
            id: mainView
            width: (root.columns * root.cellSize) + Kirigami.Units.gridUnit
            height: Math.ceil(root.height*0.7/root.cellSize) * root.cellSize
            anchors{
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }

            initialItem:           Column {
                id: allAppsColumn
                clip: true
                spacing: Kirigami.Units.largeSpacing * 2

                ItemGridView {
                    id: allAppsGrid
                    width: parent.width
                    height: Math.ceil(root.height*0.7/cellHeight) * cellHeight
                    cellWidth: root.cellSize
                    cellHeight: root.cellSize
                    iconSize: root.iconSize
                    dropEnabled: false

                    onKeyNavDown: {
                        allAppsGrid.focus = false
                        globalFavoritesGrid.tryActivate(0,0)
                        globalFavoritesGrid.forceActiveFocus()
                    }
                    onKeyNavUp: {
                        allAppsGrid.focus = false
                        searchField.focus = true
                    }
                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Tab) {
                                            event.accepted = true;
                                            allAppsGrid.focus = false
                                            globalFavoritesGrid.tryActivate(0,0)
                                            globalFavoritesGrid.forceActiveFocus()
                                        }
                                    }
                }
            }

            pushEnter: Transition {
                PropertyAnimation {
                    property: "opacity"
                    from: 0
                    to:1
                    duration: 200
                }
            }
            pushExit: Transition {
                PropertyAnimation {
                    property: "opacity"
                    from: 1
                    to:0
                    duration: 200
                }
            }
            popEnter: Transition {
                PropertyAnimation {
                    property: "opacity"
                    from: 0
                    to:1
                    duration: 200
                }
            }
            popExit: Transition {
                PropertyAnimation {
                    property: "opacity"
                    from: 1
                    to:0
                    duration: 200
                }
            }

        }

        Component {
            id: runnerComponent

            ItemGridView {
                id: runnerGrid
                anchors.horizontalCenter: mainView.horizontalCenter
                width: mainView.width/2
                clip: true
                height: mainView.height
                grabFocus: true
                cellWidth: root.cellSize
                cellHeight: root.cellSize
                iconSize: root.iconSize
                model: runnerModel.count > 0 ? runnerModel.modelForRow(0) : undefined
                onKeyNavDown: {
                    runnerGrid.focus = false
                    globalFavoritesGrid.tryActivate(0,0)
                    globalFavoritesGrid.forceActiveFocus()
                }
                onKeyNavUp: {
                    runnerGrid.focus = false
                    searchField.focus = true
                }
                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Tab) {
                                        event.accepted = true;
                                        runnerGrid.focus = false
                                        globalFavoritesGrid.tryActivate(0,0)
                                        globalFavoritesGrid.forceActiveFocus()
                                    }
                                }
            }

        }

        Rectangle{
            anchors.centerIn: globalFavoritesGrid
            height: globalFavoritesGrid.height + Kirigami.Units.largeSpacing
            width: globalFavoritesGrid.width + Kirigami.Units.largeSpacing
            color: Kirigami.Theme.backgroundColor
            radius: 10
            opacity: 0.6
            z:1
        }

        ItemGridView {
            id: globalFavoritesGrid
            width: globalFavoritesGrid.model ? Math.min(Math.floor((root.width*0.85)/cellWidth)*cellWidth,globalFavoritesGrid.model.count*cellWidth) : 0

            iconSize: root.favsIconSize
            cellHeight: iconSize + Kirigami.Units.largeSpacing
            cellWidth: cellHeight + Kirigami.Units.largeSpacing
            clip: true
            z:2
            verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff
            height: cellHeight

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.largeSpacing
            anchors.horizontalCenter: parent.horizontalCenter
            showLabels: false
            dropEnabled: true
            dragEnabled: true

            onKeyNavUp: {
                if(root.searching){
                    globalFavoritesGrid.focus = false
                    //runnerGrid.tryActivate(0,0)
                    //runnerGrid.forceActiveFocus()
                    mainView.currentItem.tryActivate(0,0)
                    mainView.currentItem.forceActiveFocus()
                }
                else{
                    globalFavoritesGrid.focus = false
                    allAppsGrid.tryActivate(0,0)
                    allAppsGrid.forceActiveFocus()
                }
            }
            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Tab) {
                                    event.accepted = true;
                                    globalFavoritesGrid.focus = false
                                    systemFavoritesGrid.tryActivate(0,0)
                                    systemFavoritesGrid.forceActiveFocus()
                                }
                            }
        }


        ItemGridView {
            id: systemFavoritesGrid
            anchors.top: parent.top
            anchors.right: parent.right
            clip: true
            width: cellWidth
            height: systemFavoritesGrid.model ? systemFavoritesGrid.model.count * cellHeight : 0
            cellWidth:  iconSize + Kirigami.Units.largeSpacing * 2
            cellHeight: cellWidth
            iconSize: root.systemIconSize
            z:5
            showLabels: false
            model: systemFavorites
            dragEnabled: false
            dropEnabled: false
            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Tab) {
                                    event.accepted = true;
                                    systemFavoritesGrid.focus = false
                                    searchField.focus = true
                                }
                            }
        }

        onPressed: mouse => {
                       if (mouse.button === Qt.RightButton) {
                           contextMenu.open(mouse.x, mouse.y);
                       }
                   }

        onClicked: mouse => {
                       if (mouse.button === Qt.LeftButton) {
                           root.toggle();
                       }
                   }
        Keys.onPressed: (event)=> {
                            if(event.modifiers & Qt.ControlModifier ||event.modifiers & Qt.ShiftModifier){
                                searchField.focus = true;
                                return
                            }
                            if (event.key === Qt.Key_Escape) {
                                event.accepted = true;
                                if (root.searching) {
                                    reset();
                                } else {
                                    root.visible = false;
                                }
                                return;
                            }
                            if (searchField.focus) {
                                return;
                            }
                            if (event.key === Qt.Key_Backspace) {
                                event.accepted = true;
                                searchField.backspace();
                            }  else if (event.text !== "") {
                                event.accepted = true;
                                searchField.appendText(event.text);
                            }
                            //searchField.focus = true
                        }
    }

    Component.onCompleted: {
        rootModel.refresh();
        searchField.forceActiveFocus()
    }
}
