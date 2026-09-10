import QtQml 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.0
import org.kde.plasma.components as PlasmaComponents
import "../components" as Components
import "components/Custom" as LayoutComponents 
import org.kde.plasma.plasmoid

Item {
    id: customLayout

    anchors.fill: parent 

    implicitHeight: mainGrid.implicitHeight + editLayoutBtn.height

    property var customLayoutModel: Plasmoid.configuration.customLayoutModel

    property var widgetsModel: masterWidgetsModel.widgetsModel

    property real totalWidgetsHeight: 0

    Component.onCompleted: {        

        /* If user has used 'Custom' layout it retrieves last configration
        from plasmoid config and sets it to masterWidgetsModel in order to
        be able to manipulate the data */

        if(customLayoutModel !== "null"){ 
            var datamodel = JSON.parse(customLayoutModel);
            masterWidgetsModel.widgetsModel = datamodel;
        }
    }


    LayoutComponents.Model {
        id: masterWidgetsModel
        defaultCellHeight: mainGrid.cellHeight
    }

    readonly property var initialDraggedItemCoords: []

    Connections {
        target: masterWidgetsModel
        function onModelUpdated () {
            customLayout.totalWidgetsHeight = 0;
            repeater.model = widgetsModel;
        }
    }

    Connections {
        target: root
        
        function onEditingLayoutChanged() {
            repeater.model = null;
            repeater.model = widgetsModel;
        }
    }

    GridLayout {
        id: mainGrid

        anchors.fill: parent
        anchors.bottomMargin: editLayoutBtn.height

        columns: 4
        rows: customLayout.totalWidgetsHeight / (cellWidth*4)
        columnSpacing: root.editingLayout ? 5 : 0
        rowSpacing: root.editingLayout ? 5 : 0

        property var cellWidth: root.editingLayout ? ((root.fullRepWidth-columnSpacing*columns) / columns) : root.fullRepWidth / columns
        property var cellHeight: (root.sectionHeight*1.3) / 3

        Repeater {

            id: repeater

            model: widgetsModel

            delegate: Loader {
                id: loader

                required property var model
                required property var index

                property int itemIndex: index
                property var name: model.name
                property var modelProps: model.props

                asynchronous: true
                source: model.componentUrl

                width: model.width ? model.width : mainGrid.cellWidth * model.colSpan
                height: model.height ? model.height : mainGrid.cellHeight

                Layout.columnSpan: model.colSpan

                Layout.rowSpan: model.rowSpan ? model.rowSpan : 1

                z: Drag.active ? 4 : 1

                Drag.active: mouseArea.drag.active // Activate drag when mouse is pressed
                Drag.source: loader // Reference to the item being dragged

                onLoaded: {

                    // Sets properties from model to loaded item
                    if (loader.item && loader.modelProps) {
                        for (const prop in loader.modelProps){
                           loader.item[prop] = loader.modelProps[prop];
                        }
                    }

                    // Recalculate totalWidgetsHeight to calculate number of rows
                    customLayout.totalWidgetsHeight += loader.width
                }
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    drag.target: loader
                    enabled: root.editingLayout
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.DragMoveCursor//Qt.PointingHandCursor

                    onClicked: mouse => {
       
                        if ((mouse.button == Qt.RightButton) && model.actions ) {
                            contextMenu.popup(mouse.x, mouse.y);
                        } 

                    }
                    
                    onPressed: {
                        customLayout.initialDraggedItemCoords[0] = loader.x;
                        customLayout.initialDraggedItemCoords[1] = loader.y;
                    }

                    onReleased: {
                        // Ensure the drag operation is completed by calling drop()
                        loader.Drag.drop();
                    }
                }

                LayoutComponents.ActionMenu {
                    id: contextMenu
                    model: loader.model.actions
                }

                Button {
                    id: removeItemButton
                    anchors.top: parent.top
                    anchors.right: parent.right
                    visible: root.editingLayout
                    Text {
                        text: "x"
                        anchors.centerIn: parent
                        color: "#ffffff"
                        font.pointSize: 11
                    }
                    z: 10
                    width: 20
                    height: 20
                    background: Rectangle {
                        color: root.redColor
                        radius: height / 2
                    }

                    onClicked: {
                        masterWidgetsModel.remove(itemIndex);
                    }
                }
            }
        }
    }


    LayoutComponents.Footer {
        id: editLayoutBtn
        height: 40
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom            
    }

    DropArea {
        id: dropArea

        anchors.fill: parent // or define specific anchors

        onDropped: drag => {

            var above = mainGrid.childAt(drag.x, drag.y);

            if (above && above !== drag.source) {

                masterWidgetsModel.move(drag.source.itemIndex, above.itemIndex);
            } else {
                let item = drag.source;
                if(isFreeSpace(item.x, item.y, item)){
                    let prevItem = findClosestItem(item.x, item.y, item);

                    if(prevItem){

                        masterWidgetsModel.insert(item.itemIndex, prevItem.itemIndex+1);
                    } 
                }
                drag.source.x = customLayout.initialDraggedItemCoords[0];
                drag.source.y = customLayout.initialDraggedItemCoords[1];
            }
        }

        function findClosestItem(initXPoint, initYpoint, item){

             let foundedItem = null
             let itemYcenter = initYpoint + item.height/2
             let itemWidth = item.width

            for (let i = initXPoint-10; i > 0; i-=itemWidth ) {

                foundedItem = mainGrid.childAt(i, itemYcenter);
                if(foundedItem) {
                    return foundedItem;
                    break;
                }
            }

            return foundedItem;
        }

        function isFreeSpace(initXPoint, initYpoint, item) {
            let finalXpoint = initXPoint + item.width;
            let isFree = true;
            let foundedItem = mainGrid.childAt(finalXpoint, initYpoint);

            if((finalXpoint > mainGrid.width) || foundedItem) {

                isFree = false;
                return isFree;
            }

            return isFree;
        }
    }
}
