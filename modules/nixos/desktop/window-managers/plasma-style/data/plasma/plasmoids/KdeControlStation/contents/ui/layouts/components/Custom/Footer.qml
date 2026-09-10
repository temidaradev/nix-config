import QtQuick 
import QtQuick.Controls
import org.kde.plasma.components as PlasmaComponents
import QtQuick.Layouts
import org.kde.plasma.plasmoid

RowLayout {

    property alias newWidgetIndex: widgetsMenu.currentIndex
    property var availableWidgetsModel: masterWidgetsModel.availableWidgetsModel

    property bool addingNewWidget: false

    PlasmaComponents.Button {
        text: "Add new item"
        visible: root.editingLayout
        font.pointSize: 10
        onClicked: {
            addingNewWidget = true;
        }
    }

    PlasmaComponents.ComboBox {
        id: widgetsMenu
        model: availableWidgetsModel
        textRole: "displayName"
        visible: root.editingLayout && addingNewWidget
        font.pointSize: 10
    }

    PlasmaComponents.Button {
        id: addWidgetBtn
        text: "Add"
        visible: root.editingLayout && addingNewWidget
        font.pointSize: 10
        onClicked: {
            let newWidget = JSON.parse(JSON.stringify(availableWidgetsModel[newWidgetIndex]));
            masterWidgetsModel.add(newWidget);
        }
    }

    Item { Layout.fillWidth: true }

    PlasmaComponents.Button {
        id: editLayoutBtn
        
        Layout.fillWidth: root.editingLayout ? true : false
        
        width: 100
        text: root.editingLayout ? "Save" : "Edit controls"
        font.pointSize: 10

        property string datastore: ""        

        onClicked: {
            if(root.editingLayout) {              
                datastore = JSON.stringify(widgetsModel);
                Plasmoid.configuration.customLayoutModel = datastore;
                root.editingLayout = false;
                addingNewWidget = false;
            } else {
                root.editingLayout = true;
            }
        }
    }

    Item { Layout.fillWidth: true }

}